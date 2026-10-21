# Public API v1

| Method | Path | Behavior |
|---|---|---|
| GET | /health | Real DB probe, schema version |
| GET | /v1/catalog | Published licensed content metadata |
| GET | /v1/content/{id}?lang=ar | One published translation with provenance |
| GET | /v1/packs?scope=circulation | Published packs, latest version per ID |
| GET | /v1/packs/{id}/manifest | Latest trusted manifest |
| GET | /v1/assets/{id}/access | Private object presigned GET, 300 seconds |
| GET | /v1/updates?since=ISO_DATE | Published content revisions since time |

Catalog/pack/update pages accept `limit` (1–100), `cursor` and `lang` (ar/en).
Return `{items, next_cursor}`. IDs match lowercase alphanumeric/hyphen syntax.
Content errors: 400 invalid input, 404 absent/draft/unlicensed, 403 writes closed,
429 saturated, 503 transient backend error. No DB exception or secret is returned.
No admin JWT API exists yet; every mutation is denied regardless of client headers.

Responses have ETags and short public cache control. Asset access responses are
`no-store` and omit cacheable signatures. Conditional GET supports 304. The
isolate limits concurrent work to 16 and uses a 300-request token bucket (5/sec
refill); this is not a globally distributed DDoS control. There is no arbitrary
object-key endpoint, SQL input or direct database access from the client.
