# Research metadata and retractions

PubMed uses ESearch plus ESummary, Europe PMC the lite metadata search, and Crossref selected bibliographic fields. Titles, authors, journal, source dates and DOI/PMID/PMCID are retained where supplied. Abstracts and article text are excluded. OA flags never stand in for a verified article license. External article links require connectivity and may require publisher access.

`reference_works.retraction_state` is unknown, notice, retracted or corrected. Absence of a retraction signal stays unknown. PubMed publication type `Retracted Publication` marks the actual source example PMID 9500320 as retracted. This record is an integration test of withdrawal handling, not recommended scientific evidence. Crossref explicit update-to retraction/withdrawal relations flag an existing target DOI; a notice itself is not confused with the withdrawn target.

Linked research is scoped to recorded bibliographic mentions. Counts, indexing, chemical studies and molecular properties are not promoted into dosing recommendations. A database trigger invalidates linked clinical publication on changed retraction state while preserving the audit trail. The rollback SQL test proves it; the public citation endpoint exposes actual stored status. This implementation is not a comprehensive retraction surveillance service.
