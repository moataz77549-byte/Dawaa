# Content review and publication

Source-service jobs may publish allowed identity/bibliographic metadata only. Every imported clinical section becomes a needs_review candidate. `publishCandidate` refuses automatic publication. There is no public clinical mutation endpoint and a caller-supplied role header grants no privilege.

A clinical/dosing fact can be published only if its source policy permits clinical-text reuse, an active qualified reviewer exists, reviewer/date/approved decision are recorded and the publication guard passes. Qualified reviewers need named identity, qualification evidence, verification actor/date and active status. No reviewer records are populated as real clinicians in Stage 2. Arabic drafts also retain needs_review and null reviewer/date. SQL QA reviewers exist only inside a transaction ending ROLLBACK.

Operators authenticate with a server-only bearer secret for `/v1/internal/review-queue`, `/v1/internal/source-jobs` and bounded source refresh. These JSON interfaces provide the initial private administrative view. Secret values never belong in Flutter, repository, reports, CI output or public cached responses. Wrong/missing credentials return 403. General user accounts/JWT role management are not introduced merely to display public educational metadata.

Source changes preserve old approvals in audit data, flag staleness and create review work. Retractions move linked clinical articles to needs_review. Before any future medical publication, a human must verify the current source, territory/population applicability, reuse license and translation. Missing clinical reviewers is an explicit scope limitation, not permission to auto-approve.
