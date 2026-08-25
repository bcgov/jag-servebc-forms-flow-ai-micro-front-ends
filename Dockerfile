FROM node:22-alpine AS builder

# Set working directory
WORKDIR /app

# Copy VERSION file first
COPY VERSION /app/VERSION

# Clean the VERSION string to remove any hidden characters or line endings
RUN cat /app/VERSION | tr -d '\r\n' > /app/VERSION_CLEAN && \
    mv /app/VERSION_CLEAN /app/VERSION

# Copy individual package files first for better caching
COPY forms-flow-admin/package*.json ./forms-flow-admin/
COPY forms-flow-components/package*.json ./forms-flow-components/
COPY forms-flow-integration/package*.json ./forms-flow-integration/
COPY forms-flow-nav/package*.json ./forms-flow-nav/
COPY forms-flow-review/package*.json ./forms-flow-review/
COPY forms-flow-service/package*.json ./forms-flow-service/
COPY forms-flow-submissions/package*.json ./forms-flow-submissions/
COPY forms-flow-theme/package*.json ./forms-flow-theme/

# Install dependencies for each microfrontend
WORKDIR /app
RUN cd forms-flow-admin && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-components && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-integration && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-nav && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-review && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-service && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-submissions && npm ci --force --legacy-peer-deps && cd /app
RUN cd forms-flow-theme && npm ci --force --legacy-peer-deps && cd /app

# Copy the shared monorepo-root webpack config (forms-flow-nav/review/submissions/components
# each `require("../webpack.formio")`) and shared theme stylesheets (forms-flow-nav also
# `@import`s forms-flow-theme/scss/v8-scss/mixins) -- these resolve automatically here since
# the whole monorepo is the build context, unlike the single-package OpenShift builds used
# for `dev` (see the runbook's Phase 3.11 section for that workaround).
COPY webpack.formio.js /app/webpack.formio.js

# Copy source code for all microfrontends
COPY forms-flow-admin/ /app/forms-flow-admin/
COPY forms-flow-components/ /app/forms-flow-components/
COPY forms-flow-integration/ /app/forms-flow-integration/
COPY forms-flow-nav/ /app/forms-flow-nav/
COPY forms-flow-review/ /app/forms-flow-review/
COPY forms-flow-service/ /app/forms-flow-service/
COPY forms-flow-submissions/ /app/forms-flow-submissions/
COPY forms-flow-theme/ /app/forms-flow-theme/

# Build each microfrontend
RUN cd forms-flow-admin && npm run build:webpack && cd /app
RUN cd forms-flow-components && npm run build:webpack && cd /app
RUN cd forms-flow-integration && npm run build:webpack && cd /app
RUN cd forms-flow-nav && npm run build:webpack && cd /app
RUN cd forms-flow-review && npm run build:webpack && cd /app
RUN cd forms-flow-service && npm run build:webpack && cd /app
RUN cd forms-flow-submissions && npm run build:webpack && cd /app
RUN cd forms-flow-theme && npm run build && cd /app

# Get version and create versioned directories with a clean version string
RUN VERSION=$(cat /app/VERSION | tr -d '[:space:]') && \
    echo "Using version: $VERSION" && \
    for component in forms-flow-admin forms-flow-components forms-flow-integration forms-flow-nav forms-flow-review forms-flow-service forms-flow-submissions forms-flow-theme; do \
      if [ -d "$component/dist" ]; then \
        mkdir -p "/app/versioned/$component@$VERSION" && \
        cp -r "$component/dist/"* "/app/versioned/$component@$VERSION/"; \
      fi; \
    done

# Use Nginx to serve the static files
FROM nginx:alpine

# Copy VERSION file (cleaned)
COPY --from=builder /app/VERSION /usr/share/nginx/html/VERSION

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built files from builder stage
COPY --from=builder /app/versioned/ /usr/share/nginx/html/

# Make the served directory writable by an arbitrary runtime UID (OpenShift's restricted
# SCC assigns a random non-root UID at container start, always in group 0).
RUN chmod -R g+rwX /usr/share/nginx/html && chgrp -R 0 /usr/share/nginx/html

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q --spider http://localhost:8080/ || exit 1

# Expose Nginx port
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
