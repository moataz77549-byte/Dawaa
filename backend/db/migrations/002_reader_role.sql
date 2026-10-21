BEGIN;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='dawa_reader') THEN CREATE ROLE dawa_reader NOLOGIN; END IF; END $$;
GRANT dawa_reader TO dawa_owner;
CREATE OR REPLACE VIEW public_packs AS SELECT p.* FROM content_packs p JOIN sources s ON s.id=p.source_id WHERE p.status='published' AND s.redistribution_allowed;
CREATE OR REPLACE VIEW public_assets AS SELECT a.* FROM media_assets a JOIN sources s ON s.id=a.source_id WHERE a.status='published' AND s.redistribution_allowed;
GRANT USAGE ON SCHEMA public TO dawa_reader;
GRANT SELECT ON public_content,public_packs,public_assets TO dawa_reader;
INSERT INTO schema_migrations(version) VALUES(2) ON CONFLICT DO NOTHING;
COMMIT;
