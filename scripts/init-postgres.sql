
-- ──────────────────────────────────────────────────────────────────────────────
-- Script de inicialização do PostgreSQL
-- Mantemos apenas extensões básicas para evitar falhas no bootstrap.
-- O schema real é gerenciado pela aplicação/SQLite; estas extensões são úteis
-- para futuras migrações.
-- ──────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL initialization completed successfully';
END $$;
