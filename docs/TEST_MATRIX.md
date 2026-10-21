# Stage 1 evidence matrix

| Check | Result | Evidence |
|---|---|---|
| Flutter analyze | Passed | Local Flutter 3.47.7 / Dart 3.13.5 |
| Flutter unit/widget tests | 11 passed | SQLite seed/search/bookmarks, locales, manifests, pack faults |
| Node API unit tests | 6 passed | Input bounds, closed writes, ETag, pagination, no leakage |
| Neon migrations 001/002/003 | Applied in development branch | 19 physical tables, 24 translation rows |
| Real DB publication/reader security | Passed | SQL fixtures rolled back; no draft/rights leak, no private table access/write |
| Real Function health/catalog/content | Passed | LIVE_SMOKE_EVIDENCE.json |
| Real Storage three-file download | Passed | Exact sizes + SHA-256 in LIVE_SMOKE_EVIDENCE.json |
| Local files read after transfer | Passed on host | Not an Android airplane-mode claim |
| Mocked transport pack fault injection | Passed | Corrupt update preserves old version, pause/resume, cancel, low storage |
| Dependency audit | npm: 0 vulnerabilities | Current locked backend production dependencies |
| Secret/client-boundary scan | Passed | scripts/security_scan.py |
| Android ARM64 compilation | Not run | No local Android SDK; CI configured, remote repo bootstrap blocked |
| API 26 and newer device runtime | Not run | Emulator CI workflow prepared, not executed |
| 3D GLB parsing/render/performance | Unverified on device | Valid original GLB; renderer code bundled, runtime gate open |
| Network-loss/timeout/process-kill on Android | Unverified | Host fault tests are not device lifecycle proof |
| GitHub branch/PR/CI | Blocked | Empty repository initialization needs authorization; terminal Git lacks auth |
| Production/root Neon deployment | Not performed | Development branch only until review gates |

Unit tests use a MockClient for deterministic faults; real Neon evidence is separate.
Linux test host required libsqlite3.so pointing to the installed libsqlite3.so.0;
CI installs libsqlite3-dev instead. Do not mark Stage 1 complete from these results.
