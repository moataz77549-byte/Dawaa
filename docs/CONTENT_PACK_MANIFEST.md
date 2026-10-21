# Pack manifest v1

Reference: backend/storage/manifests/circulation-demo.json. Trusted over HTTPS API.
Manifest includes stable pack ID/version/schema/minimum app, Arabic/English title,
scope/category/language/quality, publisher, license, attribution, source references,
publication time, dependencies, and compressed/uncompressed sizes (identical here).
Each file has object_key, relative_path, MIME, exact size, SHA-256 and asset_id.

Proof package `circulation-demo` v1: 2,225 bytes total. content.json (896 bytes),
diagram.png (533), demo.glb (796). The cloud bytes are not a commercial atlas.
The image/model are original geometric CC0 proofs, not clinical anatomy.
The independent text is CC BY 4.0 and not clinically approved.

The client never builds storage URLs from object_key; it asks the API for access
using asset_id. All metadata is stored in Postgres, bytes in private Object
Storage. Install is all-or-nothing; online preview remains transient memory.
No ZIP is used, so Zip Slip/bomb risks are avoided rather than simulated away.
