# ASCII text-track kind matching

Text-track kind conversion now folds ASCII letters once and matches the existing complete keywords. Unicode dotted capital I no longer turns values such as `captİons` into a recognized kind; those values use the metadata fallback. Empty values retain the subtitles default. Direct conversion, lazy DOM model initialization, and live null-namespace mutations preserve raw attributes, namespace isolation, and track/cue ownership.

Feature commit: `82f3e3307891e98677c9fa5232b4d6f81f4b93d6`, parent `10df818e5de20e940511f0c4aeae33478371d6b1`. The independently committed companion feature shares validated source `ca01db3f364a25f15be83c4f5552c9db6c244282`. Read-only upstream reference: `963d46a829f3e1b79f44dba9d02afb70654300fa`, in `Libraries/LibWeb/HTML/TextTrack.cpp`, `HTMLTrackElement.cpp`, and `HTMLMediaElement.cpp`.

Both GC modes passed the same joint focused run: two selected files and seven cases, using `-old-compiler -enable-globals`, default GC and `-gc none`. This feature receives only its disjoint `html/text_track_kind_ascii_test.v` file and **3 cases per mode**. The companion file receives no credit here; shared prepared/stage identities prevent duplicate run claims. No passing file was rerun.

Scoped inventory covers two HTML paths: **+1 implementation LF**, **+104 test LF**, one new test file, and 3 new cases. DOM and excluded-support deltas are zero. Existing owner metadata is authenticated without a global inventory recount.

Evidence: `Build/audit-fixes/text-track-kind-ascii-evidence-v1.json`, SHA256 `0f83222d16f716232772a99d5c212b3e87679665a1d19a729ba3d039abff2392`. Inventory: `Build/audit-fixes/text-track-kind-ascii-inventory-scoped-v1.json`, SHA256 `63d8903984698c2df384b45b6223954fc2aeae1d48744cdaeea7bb87f208303e`. The records authenticate scoped code journals/proposals, exact owned bytes, actual root, supervisor, stage and test exits, and the private source/SDK/compiler before/after guards.

The separately owned ten-fix checkpoint uses frozen epoch `5493f71172ad1007123caf9990cc7340dcfc25e7`; this feature postdates it. At documentation preparation the active broad baseline is `bcc582e74f7eb0912e8d036f747012376f99a2b7`, with **12** distinct fixes including this feature. Closure and receipt re-read active cadence and preserve post-baseline feature identities across that checkpoint's actual reset. This feature runs no broad suite and performs no reset.

Pass credit applies to frozen source `ca01db3f364a25f15be83c4f5552c9db6c244282`. Unrelated current working source receives no whole-source validation claim. Native JavaScript track interfaces, asynchronous media processing, full media/backend behavior and full LibJS parity remain open; browser JavaScript still uses JavaScriptCore.
