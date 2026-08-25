# base image
FROM node:16.20.1-alpine as build-stage

# set working directory
WORKDIR /forms-flow-nav/app
 

# add `/app/node_modules/.bin` to $PATH
ENV PATH /forms-flow-nav/app/node_modules/.bin:$PATH

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh

# install and cache app dependencies

COPY package-lock.json /forms-flow-nav/app/package-lock.json
COPY package.json /forms-flow-nav/app/package.json

RUN npm install

COPY . /forms-flow-nav/app/

# webpack.config.js requires ../webpack.formio (shared monorepo-root file, not in this
# package's own dir) -- stage it into the build context alongside this Dockerfile before
# building, so it lands one level above the app dir here.
COPY webpack.formio.js /forms-flow-nav/webpack.formio.js

# Sidebar.scss imports ../../../forms-flow-theme/scss/v8-scss/mixins (a sibling package's
# stylesheets) -- stage forms-flow-theme's scss/ dir into the build context (as
# forms-flow-theme-scss/, since forms-flow-nav isn't a real sibling of forms-flow-theme
# inside this isolated build context) and land it at the same relative path Sass expects.
COPY forms-flow-theme-scss/ /forms-flow-nav/forms-flow-theme/scss/

RUN npm run build:webpack


FROM nginx:1.15.2-alpine as production-stage

# set label for image
LABEL Name="formsflow"

RUN mkdir /app
COPY --from=build-stage /forms-flow-nav/app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
WORKDIR /usr/share/nginx/html/config
# COPY .env .
RUN apk add --no-cache bash


CMD ["nginx", "-g", "daemon off;"]
