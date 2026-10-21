# Database schema

Postgres migration 001 creates 18 domain tables plus the migration ledger:
body_systems, organs, anatomy_structures, diseases, active_ingredients,
medicine_products, content_items, content_translations, content_revisions,
sources, citations, media_assets, content_packs, content_pack_files,
content_pack_dependencies, content_pack_items, editorial_reviews, audit_logs.
There are 19 physical tables including schema_migrations.
Clinical-detail tables are intentionally empty. Canonical IDs and relations exist
without fabricated medicines or clinical data. Source records carry type, title,
URL, publisher, source publication date, license, attribution and redistribution
permission. Content stores review status, reviewer and review date separately
from fetch/update dates. Translations have per-locale composite keys.

Publication view requires published status and explicit redistribution. Clinical
publication additionally requires review identity, review date and approved
status, enforced by both CHECK and view. A simple-language full text GIN index
supports bilingual source text; local search normalizes Arabic without changing
stored source text. Foreign keys, pack version keys, scope/status indexes and
positive sizes prevent ambiguous or partial metadata.

Migration 002 creates NOLOGIN `dawa_reader`, grants it to the dedicated owner,
and grants only publication views. Base tables are not available to that role.
Every Function query runs in BEGIN READ ONLY + SET LOCAL ROLE + COMMIT.
Migration files are immutable after application. The runner uses the direct URL;
initial migrations are repeatable and the ledger records applied versions.

Drift schema v1 includes local_content, local_translations, local_index,
downloaded_packs, pack_files, download_jobs, bookmarks, reading_history,
settings and local_asset_links. Seed versions upgrade content without deleting
user bookmarks/settings/history. Initial schema is v1; the first actual schema
change must add an explicit onUpgrade migration and preservation test.
