# Architecture

One Android Flutter application. Feature UI → Riverpod → a single Drift database
for reads and one PackManager for durable optional content. GoRouter owns navigation.
The UI opens bundled seed without requesting network. Arabic is default; English,
text scaling and dark mode persist locally.

The mobile app calls a versioned HTTPS Neon Function. The Function reuses a bounded
node-postgres pool and switches each read-only transaction to `dawa_reader`.
Only publication views are granted. S3 keys and database credentials stay server-side.
Object Storage stores file bytes; Postgres stores publication, source, asset and pack
metadata. Private assets receive five-minute presigned URLs.

The 3D proof uses a bundled Three.js/GLTFLoader and Android WebView only for its
render surface. A loopback HTTP server serves exactly the viewer and one GLB;
external navigation is rejected. All other screens are Flutter widgets.

No patient data, dosing engine, duplicate Android project, Supabase, or public
administrative write API is included. See the Stage 1 report for unverified gates.
