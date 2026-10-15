# Fatal media failure load-event delay release

Terminal media failures now release their media-owned document load-event delayer. Decoder and interrupted-download failures release it before dispatching error; unsupported-source failure releases it after the error callback and rejection, only while an error remains installed. Existing early-return guards, independent document delayers, pending-play outcomes and reentrant loads retain their tested ordering.

Feature commit: `ca01db3f364a25f15be83c4f5552c9db6c244282`, parent `82f3e3307891e98677c9fa5232b4d6f81f4b93d6`. The independently committed companion feature shares validated source `ca01db3f364a25f15be83c4f5552c9db6c244282`. Read-only upstream reference: `963d46a829f3e1b79f44dba9d02afb70654300fa`, in `Libraries/LibWeb/HTML/TextTrack.cpp`, `HTMLTrackElement.cpp`, and `HTMLMediaElement.cpp`.

Both GC modes passed the same joint focused run: two selected files and seven cases, using `-old-compiler -enable-globals`, default GC and `-gc none`. This feature receives only its disjoint `html/media_fatal_load_delay_test.v` file and **4 cases per mode**. The companion file receives no credit here; shared prepared/stage identities prevent duplicate run claims. No passing file was rerun.

Scoped inventory covers two HTML paths: **+3 implementation LF**, **+228 test LF**, one new test file, and 4 new cases. DOM and excluded-support deltas are zero. Existing owner metadata is authenticated without a global inventory recount.

Evidence: `Build/audit-fixes/media-fatal-load-delay-evidence-v1.json`, SHA256 `7532593bc574035d4d818220825aa8bff9a11411ded1520d747dc7d11a41df78`. Inventory: `Build/audit-fixes/media-fatal-load-delay-inventory-scoped-v1.json`, SHA256 `a4b214f4a00206cebbbc67e89f93cad1970636eeec471c2a5d5461728e294a94`. The records authenticate scoped code journals/proposals, exact owned bytes, actual root, supervisor, stage and test exits, and the private source/SDK/compiler before/after guards.

The separately owned ten-fix checkpoint uses frozen epoch `5493f71172ad1007123caf9990cc7340dcfc25e7`; this feature postdates it. At documentation preparation the active broad baseline is `bcc582e74f7eb0912e8d036f747012376f99a2b7`, with **13** distinct fixes including this feature. Closure and receipt re-read active cadence and preserve post-baseline feature identities across that checkpoint's actual reset. This feature runs no broad suite and performs no reset.

Pass credit applies to frozen source `ca01db3f364a25f15be83c4f5552c9db6c244282`. Unrelated current working source receives no whole-source validation claim. Native JavaScript track interfaces, asynchronous media processing, full media/backend behavior and full LibJS parity remain open; browser JavaScript still uses JavaScriptCore.
