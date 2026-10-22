# Stage 1 evidence matrix

| Check | Result | Evidence |
|---|---|---|
| Flutter analyze | Passed | Local Flutter 3.47.7 / Dart 3.13.5 |
| Flutter unit/widget tests | 12 passed | SQLite seed/search/bookmarks, locales, manifests, pack faults |
| Node API unit tests | 6 passed | Input bounds, closed writes, ETag, pagination, no leakage |
| Neon migrations 001/002/003 | Applied in development and root branches | 19 physical tables, 24 translation rows |
| Real DB publication/reader security | Passed | SQL fixtures rolled back; no draft/rights leak, no private table access/write |
| Real Function health/catalog/content | Passed | LIVE_SMOKE_EVIDENCE.json |
| Real Storage three-file download | Passed | Exact sizes + SHA-256 in LIVE_SMOKE_EVIDENCE.json |
| Local files read after transfer | Passed on host | Not an Android airplane-mode claim |
| Mocked transport pack fault injection | Passed | Corrupt update preserves old version, pause/resume, cancel, low storage |
| Dependency audit | npm: 0 vulnerabilities | Current locked backend production dependencies |
| Secret/client-boundary scan | Passed | scripts/security_scan.py |
| Android ARM64 compilation | Passed | GitHub Actions 39693569603, job 119545773867; internal compilation only |
| API 26 and 35 device runtime | First-open offline, real Neon install and offline GLB passed on both API levels | DEVICE_EVIDENCE.json |
| 3D GLB parsing/render/performance | Passed on API 26 and 35 emulators | DEVICE_EVIDENCE.json; actual draw call with network disconnected |
| Network-loss/timeout/process-kill on Android | Unverified | Host fault tests are not device lifecycle proof |
| GitHub branch/PR/CI | Passed and merged | PR #2 merge 9c07f9ab; core 39859365593; devices 39859360374 |
| Production/root Neon deployment | Passed real API/Storage smoke | NEON_MAIN_SMOKE_EVIDENCE.json |

Unit tests use a MockClient for deterministic faults; real Neon evidence is separate.
Linux test host required libsqlite3.so pointing to the installed libsqlite3.so.0;
CI installs libsqlite3-dev instead. Stage 1 technical closure is supported by the completed core and device gates below.

Core CI run 39693569603 passed all four jobs on 864ce692: API/database, live Neon, Flutter and ARM64 compilation. Device run 39693566376 exposed test-harness faults: Flutter uninstalled the application between tests and API 26 shell lacked protected airplane-mode permissions. Commit 3e5c655e retains app data (`--no-uninstall`) and uses rootable AOSP CI images. API 26 subsequently passed the full scenario in 39852848804 after selecting a Google APIs image with an installed WebView. The app detects absent WebView and shows a local image fallback.

Final Stage 1 gates: core run 39859365593 and device run 39859360374 both passed on 47f02b3c. The official integration driver avoids the DDS custom-golden-stream failure. API 26 and 35 each completed all three scenarios; DEVICE_EVIDENCE.json records their actual draw and memory metrics. PR #2 merged as 9c07f9ab.
