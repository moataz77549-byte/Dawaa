BEGIN;
CREATE OR REPLACE VIEW public_assets AS SELECT a.* FROM media_assets a JOIN sources s ON s.id=a.source_id WHERE a.status='published' AND s.redistribution_allowed AND (a.content_id IS NULL OR EXISTS(SELECT 1 FROM public_content c WHERE c.canonical_id=a.content_id));
INSERT INTO schema_migrations(version) VALUES(3) ON CONFLICT DO NOTHING;
COMMIT;
