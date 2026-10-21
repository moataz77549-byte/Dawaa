# ADR 001 — Neon with one local read store

Status: accepted for Stage 1, per owner’s brief, 2026-10-22.

Neon is the sole cloud provider for Postgres, Functions and Object Storage. A
separate local SQLite store is necessary for first-open offline reading and
optional durable packs. It is not a second cloud source of truth.

Only small original seed assets ship in the application. Large media must be
versioned in private Neon buckets. File-level resume avoids claiming unsupported
byte-range semantics. Immutable installed directories plus a transactional database
pointer protect the previously working version when updates fail.

Consequences: public content needs explicit publication and redistribution rights;
clinical content needs human review. Public read routes use publication views.
Device behavior and API 26 rendering must be verified before closing Stage 1.
