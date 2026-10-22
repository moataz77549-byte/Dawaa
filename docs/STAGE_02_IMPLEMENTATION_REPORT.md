# Stage 2 implementation report

As of 2026-10-22: implementation on `stage-02-medical-knowledge-sources`, based on merged Stage 1 PR #2 (`9c07f9abf9a7255c59821dff9f534bae5a51063f`). Acceptance is still being verified; this report does not declare completion while CI/device gates remain open.

## Delivered implementation

The same Flutter/Drift application, Neon project `plain-term-00662915`, private buckets, API and pack manager are extended. Stage 2 dev branch: `br-broad-recipe-ba4bc7dt`, function `/api` invocation base `https://br-broad-recipe-ba4bc7dt-api.compute.c-8.eu-central-1.aws.neon.tech`. Root production branch remains `br-noisy-poetry-bats6www`; promote only after acceptance checks. No database/storage provider added.

Ten adapters cover all eight required sources plus RxTerms and RxClass. They normalize narrow licensed metadata with typed identifiers and provenance, bounded retry/conditional cache/circuits, database idempotency/lease/budget, cursor staging, quarantine and private operator status. Actual hosted HTTP→Function→Postgres jobs passed for every adapter; evidence is in `STAGE_02_LIVE_JOB_EVIDENCE.json`.

Additive SQL 004/005, reader-only views, source/version/retraction/clinical-review safeguards and trigram search are deployed to dev. Drift schema 2 migration preserves installed data and user state. Fourteen bundled educational cards include the original twelve; the optional 20-card/40,274-byte RxNorm terminology pack is private, SHA verified and metadata-only. It is independent of large image/model packs.

The UI adds explicit cloud search, type filters, concept identifiers, source provenance, bibliography and source-health/license views while keeping local search and Arabic/English shell. No clinical dosage, interaction engine, model generation, market availability or Stage 3 work is introduced.

## Evidence and open gates

- Local Node: 27 tests passed; dependency audit: zero vulnerabilities.
- Flutter: 15 unit/widget tests passed, analyze clean, disk schema upgrade/reopen tested.
- Real dev SQL rollback guards passed; no QA reviewer or clinical fact persisted.
- Real scheduled delivery completed a PubChem job; forged trigger request rejected 403; dev schedule disabled after test.
- Real private optional pack download/hash passed.
- CI code checkpoint `c290c19891caf99437fbf217a881fa661ed673e8`: Flutter, legacy live smokes and internal ARM64 compile passed. Database repeat-migration view issue was found and corrected; a new final run is required.
- API 26 and 35 device gates still running. Final run IDs/outcomes and production smoke will be appended only after observed success.

## Review, license and budget limits

No qualified clinical reviewer was provided. Imported clinical/dosing publication count is zero; Arabic terminology is an independent needs_review draft. The goal of clinician-reviewed cards is not claimed as achieved. Metadata samples and methodology text are usable with visible review warnings. Full labels, abstracts, licensed classifications and unverified Latin names are excluded. Future providers requiring keys/licenses remain explicitly disabled; core sample required no user API keys.

No plan or compute upgrade was purchased. Existing free project and 0.25-CU ceiling retained. Database budget: 32 source attempts/rolling day, 16 upstream requests/4 MiB/90 seconds per job, ≤5 sample items, one database lease. Intended production schedule: one bounded source sample every six hours, 120 jobs/month at most from scheduling, roughly 60-hour full rotation. It is neither exhaustive indexing nor a 24-hour freshness guarantee. Private text pack egress is about 40.3 MB for 1,000 installs before protocol overhead; legacy proof pack adds about 2.2 MB. MAU is a capacity scenario, not measured real users. Account-wide provider egress/billing cannot be inferred from application response counters.

APK distribution, Beta and GitHub Release remain forbidden before Stage 5; internal ARM64 compilation is a check only. Stage 3 handoff is documented without starting it.
