# Canonical medical data model

Migrations 004–005 extend the existing database. Existing sources, content, translations, packs, assets, editorial review and audit tables are reused. No second content engine or backend is introduced.

| Table group | Purpose |
|---|---|
| source_policies, source_connector_status | Rights projection, registry and real health |
| canonical_concepts, concept_identifiers, concept_aliases | Typed identity, verified source identifiers and normalized search |
| source_records, source_record_versions | Current provenance projection and immutable source-hash versions |
| concept_relations | Explicit source-evidenced relations, never an identity merge |
| source_fetch_jobs, source_conflicts | Bounded cursor jobs, replay, ambiguity quarantine |
| knowledge_facts, article_candidates | Field-level provenance and separate human publication review |
| reference_works, citation_links | DOI/PMID/PMCID bibliography, relation context and retraction state |
| qualified_reviewers, translation_reviews | Verifiable reviewer identity and translation decision |
| content_change_events, content_pack_exports | Staleness audit and export rights snapshots |

Concept kinds distinguish ingredient, precise ingredient, clinical drug, product, chemical compound, research, disease topic, anatomy term and nonpublic source reference. Local UUIDs are opaque deterministic application IDs, not official medical identifiers. Source-native IDs and official schemes are stored separately. A composite FK enforces identifier entity kind = concept kind; scheme checks additionally prevent PubChem CID as ingredient, NDC as compound, or DOI as drug.

Trigram indexes cover normalized concepts and aliases. Composite indexes cover kind/status/ID, updates, source freshness, job source/time, fact version and citation reference. Original text remains unchanged. Reader role has SELECT only on reviewed publication views; no base-table access. Public metadata does not mean clinical approval.

Source payload changes mark prior facts and concepts stale without erasing reviewer decisions. Reference retractions/corrections mark linked concepts stale and move linked clinical content back to needs_review. The rollback-only SQL test proves this behavior and leaves no fictional reviewer in the database.
