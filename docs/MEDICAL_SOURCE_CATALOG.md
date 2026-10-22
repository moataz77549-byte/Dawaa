# Medical source catalog

Terms checked 2026-10-22. All ten live jobs succeeded on the isolated development branch; raw counts and timing are in `STAGE_02_LIVE_JOB_EVIDENCE.json`. Limits below are application limits, deliberately lower than provider maxima. The active projection is metadata only, never a blanket content license. No API keys were needed for this sample.

| Source / official endpoint | Projection and function | Access / application quota | License evidence / offline | Smoke |
|---|---|---|---|---|
| [FDA openFDA Drug Label](https://api.fda.gov) | drugs; drug/label; CC0 except identified third-party content; metadata projection only | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://open.fda.gov/terms/); offline disabled | Real hosted ingestion passed |
| [NLM DailyMed SPL](https://dailymed.nlm.nih.gov) | drugs; v2; Metadata and official SPL links; no third-party label/image redistribution inferred | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://dailymed.nlm.nih.gov/dailymed/about-dailymed.cfm); offline disabled | Real hosted ingestion passed |
| [NLM RxNorm](https://rxnav.nlm.nih.gov) | terminology; REST; NLM RxNorm non-proprietary names/identifiers only | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html); offline allowed narrow metadata | Real hosted ingestion passed |
| [NLM RxTerms](https://rxnav.nlm.nih.gov) | terminology; REST/RxTerms; NLM RxTerms identity metadata | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html); offline allowed narrow metadata | Real hosted ingestion passed |
| [NLM RxClass](https://rxnav.nlm.nih.gov) | terminology; REST/rxclass; Classification reuse depends on underlying vocabulary; classes omitted until rights verified | LIVE_PROXY; 1 req/s/host, bounded jobs | [terms](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html); offline disabled | Real hosted ingestion passed; source pointers only |
| [NIH PubChem PUG REST](https://pubchem.ncbi.nlm.nih.gov) | chemistry; PUG REST; Identity/property metadata with per-contributor rights; no source full text or images imported | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest); offline allowed narrow metadata | Real hosted ingestion passed |
| [NCBI PubMed E-utilities](https://eutils.ncbi.nlm.nih.gov) | research; E-utilities; Bibliographic identifiers and metadata only; abstracts/full text excluded | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://www.ncbi.nlm.nih.gov/home/about/policies/); offline allowed narrow metadata | Real hosted ingestion passed |
| [NLM MedlinePlus Health Topics](https://wsearch.nlm.nih.gov) | diseases; Health Topics XML; Topic titles and official links only; no summary copied | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://medlineplus.gov/about/developers/webservices/); offline disabled | Real hosted ingestion passed |
| [Europe PMC](https://www.ebi.ac.uk) | research; REST; Bibliographic metadata; article text requires individual license verification | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://europepmc.org/Copyright); offline allowed narrow metadata | Real hosted ingestion passed |
| [Crossref](https://api.crossref.org) | research; REST; Bibliographic metadata only; abstracts excluded | CACHED_METADATA; 1 req/s/host, bounded jobs | [terms](https://www.crossref.org/documentation/retrieve-metadata/rest-api/); offline allowed narrow metadata | Real hosted ingestion passed |

## Future Source Opportunities

Disabled opportunities are documented candidates, not working API integrations or granted licenses. No URL means no verified import endpoint.

| Source | Official candidate | Requirement before activation |
|---|---|---|
| WHO ICD-11 | https://icd.who.int/icdapi | Credentials and redistribution license required |
| ClinicalTrials.gov v2 | https://clinicaltrials.gov/data-api/api | Protocol/registration metadata; trials are not recommendations |
| ChEMBL | https://www.ebi.ac.uk/chembl/ | Check dataset license; laboratory activity is not a clinical dose |
| Open Targets | https://platform-docs.opentargets.org/data-access/graphql-api | Derived datasets require separate provenance |
| OpenAlex | https://help.openalex.org/api/ | Verify current API key, quota and budget before activation |
| FDA NDC | https://open.fda.gov/apis/drug/ndc/ | US identifiers do not establish Yemeni availability |
| EMA Article 57 | https://www.ema.europa.eu/ | Periodic XLSX, no public REST interface assumed |
| LOINC | https://loinc.org/license | Registration and license review required |
| SNOMED CT | https://www.snomed.org/get-snomed | Territory and mobile redistribution rights required |
| Wikimedia Commons | https://commons.wikimedia.org/wiki/Commons:API | Per-file author/license/deletion evidence required |
| Yemeni regulator data | No verified import endpoint | No verified endpoint or reuse evidence yet; future local-market work only |
| UpToDate | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| Lexicomp | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| BNF | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| AHFS | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| Martindale | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| DrugBank | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| NICE | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| OpenStax | No verified import endpoint | Link only until a specific dataset/edition license is verified |
| Open anatomy / medical images | https://commons.wikimedia.org/ and https://www.openanatomy.org/ | Verify each asset, anatomy quality, author/license and offline rights; no image/model import in Stage 2 |
| Clinical guidelines | https://www.who.int/ and https://www.nice.org.uk/ | Verify specific guideline edition, territory, reuse rights and specialist review; no general public API assumed |
| Toxicology | https://pubchem.ncbi.nlm.nih.gov/ and https://www.poisonhelp.org/ | Verify dataset scope and safety review; not an emergency treatment algorithm |
| Laboratory standards | https://loinc.org/ | Registration/license and terminology review; no interpretation reference ranges fabricated |
| FHIR standards | https://hl7.org/fhir/ | Select standard/version and validate implementation; this is not a patient-data integration |
| Arabic/Yemeni medicines | Official national regulator publication once identified | Verify actual authority, dataset/API and territorial product evidence; no invented availability |
