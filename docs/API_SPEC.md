# Public and private API v1

Machine-readable contract: `openapi.json`. The existing public catalog/pack interface is retained; Stage 2 adds a sampled metadata index. Cloud search does not call upstream providers per phone request. Empty sampled results never mean no medicine/disease/research exists.

| Method | Path | Access and behavior |
|---|---|---|
| GET/HEAD | /health | Real DB probe, schema version |
| GET/HEAD | /v1/catalog, /v1/content/{id} | Published licensed bilingual educational content |
| GET/HEAD | /v1/packs, /v1/packs/{id}/manifest | Latest published immutable packs |
| GET/HEAD | /v1/assets/{id}/access | Private object signed GET, 300 seconds, no-store |
| GET/HEAD | /v1/updates | Legacy content revisions |
| GET/HEAD | /v1/sources, /v1/sources/{id}/status | Registry, actual health, rights and last success |
| GET/HEAD | /v1/search | Sampled metadata index; q, type, lang, limit, page |
| GET/HEAD | /v1/drugs/lookup | Ingredient/precise ingredient/clinical drug/product only |
| GET/HEAD | /v1/diseases/lookup | Disease-topic metadata and official links |
| GET/HEAD | /v1/research/search | Bibliographic metadata only |
| GET/HEAD | /v1/concepts/{uuid} | Typed IDs and per-source field provenance |
| GET/HEAD | /v1/concepts/{uuid}/references | Explicit linked bibliography with retraction status |
| GET/HEAD | /v1/citations/{uuid} | One reference; unknown/retracted state retained |
| GET/HEAD | /v1/catalog/updates | Metadata revisions since ISO UTC timestamp |
| GET | /v1/internal/review-queue, /v1/internal/source-jobs | Server bearer token, no-store |
| POST | /v1/internal/sources/{id}/refresh | Server bearer token; bounded query/cursor or ≤5 identifiers, idempotency key |
| POST | /v1/internal/source-cron | Genuine Neon schedule delivery only; bearer/forged headers do not substitute |

New metadata pagination: limit 1–50, page 1–100, `{items,next_page}`. Search q length 2–200; typed RxCUI:, CID:, DOI:, PMID:, PMCID:, NDC: lookups bind parameters and entity kinds. Languages ar/en/la; Latin remains absent if unverified. DOI URL prefixes/case normalize; no free-text SQL or arbitrary proxy URL is accepted.

Legacy catalog/pack/updates keep limit 1–100 and cursor pagination. Mutations of public data return 403; validation 400, absent/draft 404, saturated/budget 429, transient provider/database failure 503 (upstream schema errors 502). Error payloads contain sanitized codes only. Private bodies ≤2 KiB; responses no-store. Public metadata uses ETag/304 and max-age 60. API isolate limit: 12 in-flight and 180 tokens replenished at 2/sec, not a global DDoS service. Legacy API has its own bounds.

Refresh body: `{query?,cursor?,identifiers?,limit?,idempotency_key?}`. Key replay requires an identical stored request shape; mismatch returns 409. Clinical publication is deliberately absent. Never embed the service secret or database/storage credentials in a client.
