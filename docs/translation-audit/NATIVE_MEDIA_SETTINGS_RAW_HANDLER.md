# Native media raw ratechange and volumechange handlers

Feature `5d549d512fb9701e3dc05121a73a8f33bffd39fa` adds lazy raw `onratechange` and `onvolumechange`
compilation on actual owner-local HTML audio/video. Focused owner corrections
are `d1a0df474ebfacdb4a6c35d2570f87e7949fbf12` and `89fab31e4062ab239525b090b33b3d62d01be5f0`. The first materializes a conditional
expected-target initializer; the final replaces it with an explicit mutable
pointer and ordinary if block accepted by the old V frontend and C compiler.
Each correction changes only the owner test. The final actual parent is
`d1a0df474ebfacdb4a6c35d2570f87e7949fbf12`. Identified intervening foreign commits, including the independent
main.v paint change, remain in their committed source epochs without root
feature accounting or broad-suite credit.

The native compiler and content-attribute replay admit both names through
existing HTML namespace, media model, Runtime, Document, settings and wrapper
checks. Existing native descriptors and media-setting algorithms provide
delivery and live settings. FunctionBody parsing precedes wrapper resolution;
resolver reentry rechecks slot identity and source. Element -> Document ->
Global scopes omit ancestor forms. Inferred names introduce no local handler
self binding. Equal-text attribute writes replace IDL callbacks, present
removals clear them, and absent removals preserve IDL-only callbacks.

Six focused cases per GC mode pass across three detached committed source
epochs. At the original feature, three binding cases pass in default and no-GC
modes; the combined commands then exit 1 on owner C compilation and execute
zero owner runtime cases. At the first correction, owner-only commands exit 1
at the V frontend and execute zero runtime cases. At the final correction,
owner-only commands run their three cases successfully in both modes with
actual exit 0. Successful evidence combines binding execution in the first
epoch and owner execution in the third; no complete single-epoch combined
pass is claimed. All failed commands, sources, logs, manifests and scratch
remain unchanged and retained.

Binding cases cover parsed, created and lazy audio/video; native settings
scope, caches and prototype shape; malformed wheel/play slots; syntax before
resolution; resolver mutation; missing, generic and mismatched owners; CSP;
foreign adoption; strict original thrown values; scripting gates and close.
These Event probes dispatch directly and give no native task-order credit.

Owner cases exercise source-empty paused parsed video and created audio
through native setters and the actual media task queue. Interleaved default
rate, volume, current rate, muted, default rate and volume writes retain their
queue order; callbacks see final live values. Equal and rejected setters add
no tasks. Replacement before delivery selects the later handler; reentrant
setters append in order. Raw removal suppresses queued callbacks while absent
removal preserves a later IDL callback. Trusted single-Event identity, exact
false cancellation, original exceptions, later listeners, balanced contexts
and retained DOM painting are covered.

Production rebuilds, screenshots, full translation suites and LibJS corpus
comparisons remain deferred under the user's ten-fix cadence. The compound
slice is 4/10 after aa6f0246; fixture corrections and documentation are not
additional translation fixes. Previous signed builds and evidence remain.

Evidence: `Build/audit-fixes/native-media-settings-raw-handler-evidence-v3.json` (SHA256 `872ae8c083c97a7419f3beb8cea2b78cc9f01b7c5cd6918d8bc59282de28d9e4`).
Three detached source epochs retain the original six exact working overrides,
authenticated toolchains and regex prerequisites. All 99,215 prior artifacts,
executed helpers, successful and failed actual execution records, source and
compiler scratch, and scoped Git transactions remain preserved. Final closure
and actual terminal receipt are `native-media-settings-raw-handler-final-closure.json` and
`native-media-settings-raw-handler-final-actual-exit.json` under Build/audit-fixes.

Physical accounting: `Build/audit-fixes/native-media-settings-raw-handler-inventory-scoped-v4.json`
(SHA256 `210c1aa9c3436fe0ae6d48d4fac3e7cfaf5dccf4a89a3e53d7444676bfda1220`). Three root components account the original
five-path feature from `867c57289e8af1bceaeb27f94a75f3be61046a9b` to `5d549d512fb9701e3dc05121a73a8f33bffd39fa`, the first one-path
correction from `df931f855223770292cc34c356001c73b75852b5` to `d1a0df474ebfacdb4a6c35d2570f87e7949fbf12`, and the final one-path
correction from `d1a0df474ebfacdb4a6c35d2570f87e7949fbf12` to `89fab31e4062ab239525b090b33b3d62d01be5f0`. Foreign intervening commit deltas
are excluded. Final current source hashes separately authenticate frozen-v3;
main.v can differ from its original feature through foreign committed work.
All owned browser/root paths are outside the sealed 78-owner DOM inventory:
zero assigned files, implementation lines or test lines. Counting grants no
behavior credit and leaves global tables, pins and historical ledgers intact.

Other raw media names remain open, with onerror explicitly unsupported.
These owner cases make no source-fetch, playback or pause-policy claim.
Playback-rate backend propagation, partial named-property interfaces,
anonymous JSC intrinsic source, foreign/weak ownership, close during active
JavaScript and full interface or LibJS/HTML parity remain open. The browser
continues to use JavaScriptCore.
