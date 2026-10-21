# Neon setup and deployment

Dedicated project: `plain-term-00662915` (`dawa-hayah`), `aws-eu-central-1`.
Production/root branch: `br-noisy-poetry-bats6www` (`main`, reserved).
Development branch: `br-still-mode-balcyppo` (`stage-01-neon-offline-foundation`).
Free organization plan confirmed at provisioning; compute capped at 0.25 CU.
No paid plan was activated. The account rejected a custom suspend interval;
project creation succeeded using the account defaults.

On the development branch: three migrations applied, 12 bilingual introductions,
4 private buckets (`anatomy-models`, `medical-images`, `offline-packs`, `source-media`),
API slug `api`. Only `offline-packs` currently contains the three proof objects.
The root branch has not received the schema or deployment; do not confuse it with
staging. Other user projects were not modified.

Public staging API:
https://br-still-mode-balcyppo-api.compute.c-8.eu-central-1.aws.neon.tech

Local/CI: `npm ci --prefix backend`, then supply a **direct** connection in the
ignored environment as DATABASE_URL_UNPOOLED. Run `node scripts/migrate.mjs`,
`node scripts/seed.mjs`, and the SQL test on an isolated branch. The direct
hostname must not contain `-pooler`. Do not echo credentials or store them in Git.

Authenticated CLI deployment from backend: `neon link`, select this dedicated
project, `neon checkout stage-01-neon-offline-foundation`, `neon config plan`,
then `neon deploy`. `neon.ts` declares the private buckets and function.
The first deployment here used the connected Neon deploy tool with a ZIP of
`index.mjs` produced by `node scripts/bundle.mjs`. Postgres is injected at runtime;
the S3 SDK uses injected AWS-standard variables with path-style addressing.

Uploads used branch-scoped presigned PUT URLs. Reproduce bytes with
`scripts/build_proof_assets.py`, read the checked-in manifest, request an upload
URL for each object key, upload with its MIME, and insert asset/pack metadata.
Do not publish signed URLs in evidence. `scripts/live_smoke.py` verifies actual
remote downloads and hashes without storing any credentials.

Official documentation checked during implementation:
https://neon.com/docs/storage/overview
https://neon.com/docs/storage/buckets
https://neon.com/docs/compute/functions/deploy
https://neon.com/docs/compute/functions/authentication
https://neon.com/docs/introduction/regions
https://neon.com/pricing
