# syntax=docker/dockerfile:1.7
###############################################################################
# Backend — production multi-stage build
#   builder : creates an isolated virtualenv with pinned runtime deps
#   runtime : minimal slim image, non-root, no build tools, no test deps
###############################################################################

########################## Builder stage ##########################
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Build the venv. psycopg2-binary ships wheels, so no compiler toolchain needed.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

########################## Runtime stage ##########################
FROM python:3.12-slim AS runtime

# Build metadata (passed by the build script) -> OCI image labels.
ARG VERSION=dev
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.title="employee-management-backend" \
      org.opencontainers.image.description="FastAPI backend for the Employee Management System" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://example.com/employee-management" \
      org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    LOG_LEVEL=info

# Create an unprivileged system user/group with a fixed UID/GID.
RUN groupadd --system --gid 10001 appgroup \
    && useradd --system --uid 10001 --gid appgroup --home-dir /app --shell /usr/sbin/nologin appuser

WORKDIR /app

# Copy the pre-built virtualenv from the builder (no pip/build cruft).
COPY --from=builder /opt/venv /opt/venv

# Copy only what the app needs, owned by the non-root user.
COPY --chown=appuser:appgroup app ./app
COPY --chown=appuser:appgroup alembic ./alembic
COPY --chown=appuser:appgroup alembic.ini ./

USER appuser

EXPOSE 8000

# Health check uses the stdlib only — no curl/wget in the image (smaller, safer).
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"]

# `exec` under sh so LOG_LEVEL is externalizable while keeping PID 1 = uvicorn
# (correct signal handling / graceful shutdown).
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level ${LOG_LEVEL:-info}"]
