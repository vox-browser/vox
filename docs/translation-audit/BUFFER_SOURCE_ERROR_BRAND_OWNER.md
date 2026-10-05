# BufferSource detachment keeps error branding intrinsic

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature: `5846bfd3581db932fba50678f269a6041dd2202f` includes its focused
Crypto regression and implementation in the same commit.

The shared native-engine BufferSource copier previously used
`error instanceof TypeError` when a detached ArrayBuffer caused construction
of its byte view to throw. Author code can install TypeError[Symbol.hasInstance];
the independent Crypto baseline executes that hook once and turns copying
into an author-thrown Promise rejection. Pinned WebIDL::get_buffer_source_copy
returns empty bytes for detached backing stores through its internal state,
without an author error-brand lookup.

The copier now captures Function.prototype[Symbol.hasInstance] before author
scripts and invokes that intrinsic through the already captured Reflect.apply.
The TypeError object and byte-view constructor remain the original captured
engine values. This preserves the empty-byte detached path without invoking
an author replacement. No generic instanceof semantics are changed.

The focused case installs a throwing author hook, hashes detached ArrayBuffer,
typed-array and DataView inputs through actual native Crypto promises, and
expects zero hook calls and three SHA-256 digests of empty bytes. The native
SourceBuffer fixture independently exercises these detached forms with the
same hook installed, followed by copied typed-view Cluster bytes.

| Run | Result | Seconds |
| --- | --- | ---: |
| brand-baseline | Combined Crypto assertion fails at runtime | 87.705 |
| brand-baseline-counter | Author hook counter is 1 instead of 0 | 79.761 |
| brand-final-default | Four affected files PASS after brand correction | 244.409 |
| brand-final-none | Four affected files PASS after brand correction | 347.155 |
| Production build | PASS | 639.312 |
| Production codesign | PASS | 0.029 |
| Production headless | PASS | 1.040 |
| Production public-headless | PASS | 0.109 |
| Production reference | PASS | 3.476 |
| Production public-capture | PASS | 2.788 |
| Production strict-diff | PASS | 3.598 |

The first Crypto baseline fails its combined result assertion at runtime.
The counter baseline explicitly records **1** author hook call against
expected **0**, with no compiler failure. Final four-file batches include this
focused case, all seven native buffer cases, the existing Crypto digest file
and the actual page caller. Both GC modes pass on the same file snapshot.
Unrelated Crypto formatting was then restored to keep the commit focused;
all non-whitespace tokens, V string literals and the copier constant remain
identical. The separate restoration proof and both representations are
retained. Production verification builds the restored committed source.

Shared retained evidence `Build/audit-fixes/native-media-buffers-evidence.json`
has SHA256 `daa0407d825d1987dc32c623d9e4d0543cb35513371276d754f4c40dee67ea66`. It records all nine test manifests,
production argv/exits/log hashes, private baseline fixtures, the formatting
restoration, feature commits and inventory. The refreshed inventory artifact
`Build/audit-fixes/source-current-module-loc-1b436216.json` has SHA256
`683cda23adcb72215c2ae225829c749f542c12b9d0373b9f1ccc2a26621e3261`. Module counts are unchanged;
these additions belong to excluded browser/root support.

The preceding 23-file sweeps in both GC modes predate this error-brand change;
they do not count as post-change whole-module sweeps. All remaining buffer,
realm/world, allocation and physical collector boundaries are unchanged.
The [native buffer owner feature](NATIVE_MEDIA_SOURCE_BUFFER_OWNER.md)
records its separate code-and-test commit and frozen production page.
The audit stays **32 fixed / 25 partial / 9 open**.
