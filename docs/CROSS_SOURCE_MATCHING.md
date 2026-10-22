# Cross-source matching

Exact `(scheme, value, entity_kind)` agreement is the only automatic identity join. Titles, abbreviations, transliterations, fuzzy text and salt similarity are search hints. Several exact-identifier candidates produce a conflict case and quarantine rather than a guessed merge.

SPL_SET_ID identifies a label/product group. FDA/DailyMed label groups remain distinct even if their metadata mention a common RxCUI or NDC. Those cross references remain in the provenance projection; they do not turn a branded product into its ingredient. RxNorm IN, PIN and clinical-drug types remain distinct. PubChem CID/InChIKey concepts remain chemical compounds. DOIs normalize case and official URL prefixes; numeric PMID and PMCID schemes remain separate.

The sample contains RxCUI 161 ingredient, RxCUI 198440 clinical drug and PubChem CID 1983 compound, all separate UUIDs. The recorded live RxNorm related/IN response explicitly connects 198440 to ingredient 161; `verified_relation.json` records the observed response projection, not an invented raw archive. `verified_relation.sql` inserts that relation only when both verified typed identifiers and the source record exist.

Bibliographic links for acetaminophen are explicitly title mentions. They are labelled `bibliographic_title_mentions_acetaminophen_not_efficacy_or_dosing`, not evidence of treatment benefit. Chemical-name search does not assert ingredient/compound equivalence. No Yemeni availability, interaction clearance, or substitution is inferred.
