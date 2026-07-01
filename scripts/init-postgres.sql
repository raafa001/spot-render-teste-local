-- ──────────────────────────────────────────────────────────────────────────────
-- Script de inicialização do PostgreSQL
-- Cria extensions, roles e schema inicial para o Spot Render
-- ──────────────────────────────────────────────────────────────────────────────

-- ─── Extensions ───────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ─── indexes para performance ────────────────────────────────────────────────

-- Index para buscar jobs por projeto + hash (evita duplicação)
CREATE INDEX IF NOT EXISTS idx_jobs_project_hash
ON renderqueue(project, file_hash);

-- Index para buscar jobs por status
CREATE INDEX IF NOT EXISTS idx_jobs_status
ON renderqueue(status);

-- Index para buscar jobs por artista
CREATE INDEX IF NOT EXISTS idx_jobs_artist
ON renderqueue(artist);

-- Index para buscar jobs por created_at (ordenação)
CREATE INDEX IF NOT EXISTS idx_jobs_created_at
ON renderqueue(created_at DESC);

-- ─── Funções de monitoramento ────────────────────────────────────────────────

-- Função para calcular tamanho do banco
CREATE OR REPLACE FUNCTION renderqueue.get_db_size() RETURNS BIGINT AS $$
SELECT pg_database_size('renderqueue')::BIGINT;
$$ LANGUAGE SQL STABLE;

-- Função para listar jobs com problemas
CREATE OR REPLACE FUNCTION renderqueue.get_stale_jobs(OUT job_id TEXT, OUT project TEXT, OUT status TEXT, OUT created_at TIMESTAMPTZ, OUT minutes_ago BIGINT) AS $$
SELECT
    j.id,
    j.project,
    j.status,
    j.created_at,
    EXTRACT(EPOCH FROM (now() - j.created_at))::BIGINT / 60 AS minutes_ago
FROM renderqueue j
WHERE
    j.status IN ('queued', 'running')
    AND j.created_at < now() - INTERVAL '1 hour'
ORDER BY j.created_at ASC;
$$ LANGUAGE SQL STABLE;

-- ─── Grants ───────────────────────────────────────────────────────────────────

-- Grant para usuário de aplicação
-- CREATE USER render_app WITH PASSWORD 'app_password';
-- GRANT CONNECT ON DATABASE renderqueue TO render_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO render_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO render_app;

-- ─── Vacuum settings ───────────────────────────────────────────────────────────

-- Configurar autovacuum para melhor performance
ALTER DATABASE renderqueue SET vacuum_cost_delay = 10;
ALTER DATABASE renderqueue SET vacuum_cost_page_hit = 1;
ALTER DATABASE renderqueue SET vacuum_cost_page_miss = 10;
ALTER DATABASE renderqueue SET vacuum_cost_page_dirty = 20;

-- ─── Comentários ──────────────────────────────────────────────────────────────

COMMENT ON TABLE renderqueue IS 'Tabela principal de jobs de renderização';
COMMENT ON COLUMN renderqueue.id IS 'UUID único do job';
COMMENT ON COLUMN renderqueue.status IS 'Status: queued, running, finalizing, completed, failed';
COMMENT ON COLUMN renderqueue.file_hash IS 'SHA256 do arquivo para deduplicação';
COMMENT ON COLUMN renderqueue.created_at IS 'Timestamp de criação do job';
COMMENT ON COLUMN renderqueue.updated_at IS 'Timestamp da última atualização';

DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL initialization completed successfully';
END $$;
