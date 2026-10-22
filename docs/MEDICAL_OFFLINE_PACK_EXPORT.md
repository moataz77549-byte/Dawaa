# Medical offline pack export

`medical-identities` version 1 contains 20 terminology cards, a single 40,274-byte JSON file and no images, structures or clinical text. Exact manifest: `backend/storage/manifests/medical-identities.json`. SHA-256: `b6f78572a35d9e0833d3fa248b5d21ccd08d15fc6712f992a51d6cd7c51c4bed`.

It is uploaded to the existing private `offline-packs` bucket at `medical-identities/1/content.json`. Public access remains a short-lived signed GET through the API. Required application 0.2.0, local schema 2; legacy circulation pack remains compatible. App version is internal and is not an APK release.

Run `python scripts/build_medical_pack.py` and `node scripts/knowledge_policy_lint.mjs` to rebuild/validate. `medical_pack_sql.py` emits additive asset/manifest registration; `knowledge_curations_sql.py` emits separate draft names, bibliographic links and policy export evidence. No hidden clinical approval occurs. Cloud content remains source-of-truth metadata; original bundled twelve cards are preserved, plus two lightweight methodology cards with different IDs.

The same pack manager checks file bytes/hash, safe paths, quotas, disk space, version/schema compatibility, provenance/offline permissions, duplicate IDs and existing content ownership before installation. Files stage separately; one SQLite transaction switches the active version. Failure preserves the prior version. Small independent pack updates leave large circulation assets untouched. There is no new binary-delta engine: independent immutable pack replacement is the supported small-update mechanism.

Removal keeps built-in cards, bookmarks/history and settings. Unit tests cover corruption rollback, interrupted file resume, cancellation, low space and metadata-only offline reads. Device gates install from real Neon, force-stop, disable actual emulator network, restart, search RxCUI:161 and open Arabic text/source/license alongside the prior PNG/actual GLB renderer proof. See device evidence for observed results, not a claim of physical-device testing.
