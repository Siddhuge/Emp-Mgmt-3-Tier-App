# syntax=docker/dockerfile:1.7
###############################################################################
# Database image (optional) — PostgreSQL 16 with the init script baked in.
# The official postgres image already runs as the non-root `postgres` user and
# drops privileges via its entrypoint. Files in /docker-entrypoint-initdb.d run
# once, on an empty data directory.
###############################################################################
FROM postgres:16-alpine

ARG VERSION=dev
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.title="employee-management-database-init" \
      org.opencontainers.image.description="PostgreSQL 16 with Employee Management init scripts" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT"

COPY init.sql /docker-entrypoint-initdb.d/10-init.sql

EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=10 \
    CMD ["sh", "-c", "pg_isready -U \"${POSTGRES_USER:-postgres}\" -d \"${POSTGRES_DB:-employee_db}\""]
