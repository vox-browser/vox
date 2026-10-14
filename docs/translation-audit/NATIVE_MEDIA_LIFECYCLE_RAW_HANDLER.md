# Native media raw play and pause handlers

Feature `aa6f02469c356b1ee7a6f33d588f62d2df4bd56a` translates lazy `onplay` / `onpause` compilation for owner-local
native HTML audio/video wrappers. The browser remains on JavaScriptCore.

The combined Document compiler keeps its existing Window and wheel support and
admits these two names only for actual supported media elements. A new optional
name-aware DOM availability hook follows the existing environment guard; compilers
without it keep their prior behavior. Media resolution uses the requested raw slot,
parses FunctionBody before materializing wrappers, and rechecks slot/source plus
Runtime, Document, settings, forward/reverse wrapper identity, cached model and live
MediaElementHost ownership. Lookup uses the actual Element, Document and Global
objects, excluding ancestor forms. Anonymous function-property inference supplies
the handler name without a self binding.

The compact bridge records each explicit onplay/onpause content-attribute write,
including equal text, and records removals only when the attribute existed. Replay
is restricted to those names on native HTML audio/video. Existing queueing in
HTMLMediaElement delivers trusted, nonbubbling, noncancelable play/pause events;
callbacks use the actual native Event and EventTarget bindings.

Validation: 47 cases in 14 files
pass in both default and no-GC test modes, including eight new focused cases.
The owner fixtures exercise actual queued play()/pause(), lazy cache identity,
Element/Document/Global scope, one Event argument, replacement before delivery,
reentrant pause, native promise rejection ordering, DOM/paint replay, original
strict exceptions and scripting gates. The fresh default-Boehm production bundle
passes strict signing, headless startup and two pixel-exact public author-dispatch
pages. The 47-case broad unit batches completed before the user requested a
ten-fix broad-suite cadence. Smoke had finished when the remaining SVG continuation
was stopped; the focused production record gives that broad continuation no new
full-batch credit. Its completed smoke log and two completed SVG cases are retained. The two public pages use untrusted
author-created Events; native lifecycle generation is proven by the owner fixtures.
The initial live-page fixture accidentally retained an onwheel self-removal name;
its red screenshot and failed producer remain preserved. Fresh corrected page
artifacts passed before the user stop and their saved pixels were independently
verified against the same signed binary; build/sign/startup were retained successful
stages. No broad checks were restarted. A corrected stop observation records that
smoke had completed and termination occurred during SVG, superseding the stale
initial smoke-stage label without editing the old record. Production no-GC is not claimed. The earlier wheel slice's failed no-GC production
attempt remains preserved in its own evidence.

Evidence: `Build/audit-fixes/native-media-lifecycle-raw-handler-evidence-v1.json` (SHA256 `2925d48e0a0f248c785eb3f7dfa1c5af2ffbedcafcbd719e19a262e5515e7e01`).
Source uses two identical detached feature-commit epochs with the original six exact working
overrides and authenticated regex prerequisites/toolchains. All 72,517 prior
artifact records, current source, executed helpers, failed/interrupted diagnostics,
compiler scratch, signed bundles and scoped Git transactions are retained. The
final closure record is `native-media-lifecycle-raw-handler-final-closure.json` under `Build/audit-fixes`;
its actual terminal receipt is authenticated after completion. The independently
committed verification cadence is recorded in AGENTS.md. Original working-file
prefixes and the full current committed documentation suffix are preserved,
including independent concurrent instruction-optimization policy edits. Zero completed fixes have
accumulated after the aa6f0246 broad unit baseline.

The feature owns three assigned DOM paths and seven excluded browser/root paths.
Independent physical-LF accounting is `Build/audit-fixes/native-media-lifecycle-raw-handler-inventory-scoped-v1.json`
(SHA256 `7d14c9c050b3314215db3864ce01b7a3d9df2e704f13d8f05b8ffa5755e74f62`); it confers no behavior or test credit and does
not replace global inventory tables or historical ledgers.

Boundaries: other raw media handler names remain unsupported. Unavailable,
generic or foreign owners preserve raw slots. Named-property exposure remains
partial; native JSC Function.prototype.toString retains the anonymous literal
source while translated callback metadata records the named source. Weak/foreign
realm ownership, runtime close during active JavaScript, physical OS input and
full interface or LibJS/HTML parity remain outside this slice.
