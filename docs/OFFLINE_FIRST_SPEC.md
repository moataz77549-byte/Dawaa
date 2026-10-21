# Offline-first reading and packages

At startup SQLite opens in app support storage and seeds 12 original bilingual
introductions idempotently. Home/body/disease/medicine/library queries read SQLite,
including Arabic normalization, bookmarks and history. Startup does not require
Neon, authentication or downloaded media.

Online preview fetches text/image/GLB into memory through the API and does not
install a pack. Persistent downloads use the same PackManager for all file types.
Manifest validates schema, current app version, IDs, path traversal, duplicates,
hash syntax, file count, individual and total sizes. Dependencies are rejected
explicitly until a dependency-confirmation UI is implemented; no hidden downloads.

Storage policy: Wi-Fi/ethernet by default; the owner may enable mobile data in
settings. Android StatFs checks at least the package size plus 16 MiB free.
Current safety limits: 64 MiB/file, 128 MiB/pack, 200 files. These bounded Stage 1
limits are intentionally lower than future atlas packages and must be revisited
with device performance tests. No archive extraction is performed.

Files download under staging, with timeout and up to three attempts/backoff.
Each retry renews asset access; no expired URL is persisted. Resume is at file
boundaries, rehashing completed files; partial files restart. No byte-Range claim.
All files must pass exact byte count and SHA-256 before content import. Installation
renames the new immutable version directory, then commits content and its active
pointer in one SQLite transaction. Old files remain until this succeeds.

Pause retains verified files; cancel removes staging. Process interruption marks
active jobs paused on next start. Failed updates retain the last active version.
Removal deletes pack-owned data/files while retaining seed, bookmarks and history.
Orphan directories after a crash are safe but may require disk cleanup; this is
an open acceptance item. No background WorkManager execution is promised.
