-- Database initialization script.
-- Postgres' official image runs everything in /docker-entrypoint-initdb.d
-- against the database named by POSTGRES_DB, so this file only needs to take
-- care of anything beyond database creation.
--
-- Table creation and seed data are handled by the FastAPI backend on startup
-- (SQLAlchemy create_all + seed), with Alembic migrations as the source of
-- truth for schema changes. This script is kept for future extension
-- (extensions, roles, grants, etc.).

-- Example: enable case-insensitive text extension if ever needed.
-- CREATE EXTENSION IF NOT EXISTS citext;

SELECT 'employee-management database initialized' AS status;
