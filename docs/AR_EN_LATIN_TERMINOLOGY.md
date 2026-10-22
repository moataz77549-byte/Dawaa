# Arabic, English and verified Latin terminology

The twenty English ingredient names and RxCUIs were verified through real RxNorm properties responses. Arabic names are independent project drafts with provenance, revision and needs_review records; they are not NLM translations or clinically approved names. `verified_ingredient_metadata.json` makes the exact sample reproducible. No fake reviewer is assigned.

English is not labelled Latin. `latin_name`/`verified_latin_term` remain empty when an independently verified Latin term is unavailable. API `lang=la` can request the field but does not manufacture it or transliterate English into a supposed scientific identifier.

Local/cloud normalization folds Arabic alef variants, diacritics, tatweel, alef maqsura and ta marbuta for search only. Original display text remains intact. Unicode/Arabic search, English names and official identifier schemes are indexed. A matching string does not merge records or establish salt/product equivalence. No unverified ASA/aspirin or salbutamol/albuterol alias is silently introduced.

The existing Arabic RTL/English LTR shell is retained. Source names, official IDs and scientific metadata may remain in their original language. Warnings distinguish independent translation drafts from clinical review. Drift schema 1→2 backfills provenance/search atomically while preserving favorites, history, settings and pack ownership; disk reopen is tested.
