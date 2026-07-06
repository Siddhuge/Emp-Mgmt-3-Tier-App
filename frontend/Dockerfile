# syntax=docker/dockerfile:1.7
###############################################################################
# Frontend — production multi-stage build
#   build : compile the React app to static assets with Node
#   serve : ship only the static files on a non-root nginx (no Node runtime)
###############################################################################

########################## Build stage ##########################
FROM node:20-alpine AS build

WORKDIR /app

# Install deps against the lockfile for reproducible builds.
COPY package.json package-lock.json* ./
RUN npm ci || npm install

COPY . .
RUN npm run build

########################## Serve stage ##########################
# nginx-unprivileged runs as UID 101 (non-root) and listens on 8080 by default.
FROM nginxinc/nginx-unprivileged:1.27-alpine AS serve

ARG VERSION=dev
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.title="employee-management-frontend" \
      org.opencontainers.image.description="React SPA (served by nginx) for the Employee Management System" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://example.com/employee-management" \
      org.opencontainers.image.licenses="MIT"

# Patch OS packages to clear known base-image CVEs, then drop back to non-root.
USER root
RUN apk --no-cache upgrade
USER 101

# Base image already switches to the non-root `nginx` user; copy config + assets.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=5 \
    CMD ["sh", "-c", "wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1"]

# CMD inherited from the base image (nginx -g 'daemon off;').
