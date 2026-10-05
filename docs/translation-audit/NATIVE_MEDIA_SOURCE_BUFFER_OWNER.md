# Native MediaSource buffer owners and operations

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature: `1b436216c3e02201be1458dd30a3899107af943a`. Implementation and focused tests share that commit.

Window startup now installs SourceBuffer and SourceBufferList interfaces and
MediaSource.sourceBuffers, activeSourceBuffers and addSourceBuffer. They wrap
the existing V buffer/list records, use their actual relevant Window and bind
the same native EventTarget. Repeated getters/index access return the same
wrapper, while source and active lists remain distinct. A copied JavaScript
array or duplicate state machine is not used.

SourceBuffer exposes mode, updating, timestampOffset, five event-handler
attributes, appendBuffer, abort, changeType and remove. Native methods and
accessors retain IDL property flags, names and arities. Constructors for both
buffer interfaces reject invocation and construction. Caller-realm buffered
TimeRanges and the pinned FIXME track/window attributes remain separate.

List indices use the pinned PlatformObject indexed branches: live getters,
read-only enumerable/configurable descriptors, indexed write/define/delete
rules, supported-index-first key order and failed preventExtensions. The
engine continues to own ordinary storage and prototype traversal. There is
no named item method or synthetic iterable added to the anonymous IDL getter.

Receiver validation precedes WebIDL conversions and typed algorithms.
DOMString/enum and numeric conversion retain original author exceptions;
restricted doubles reject NaN/infinity and ToNumber rejects BigInt. remove
converts start before its unrestricted end. BufferSource uses the existing
captured native-engine intrinsics for real ArrayBuffer/view slots, shared and
resizable restrictions, witnesses and span copying. Author buffer/length/
offset properties and Proxy brands do not acquire native identity. Detached
ArrayBuffer, typed-array and DataView input contributes empty bytes. The
bridge materializes a byte copy before invoking V append; its large-allocation
limits and exact allocation-error precedence remain a separate boundary.
InvalidStateError/NotSupportedError retain native DOMException identity, and
QuotaExceededError uses the existing specialized binding. No forced buffer
quota-exhaustion fixture is claimed here.

Seven native host cases cover metadata/identity, DataView subspans, typed
view content retained after mutation, detached sources, conversion ordering,
abort from updatestart, recognized Cluster-before-init fatal errors, removal,
live list clearing after actual media detachment and callbacks after
Runtime.close. A separate real page case executes author code from sourceopen,
adds and appends a buffer, and verifies actual DOM media attachment and queued
native event identity. Its append contains an incomplete WebM header; it does
not establish full decoding or playback.

## Verification and retained evidence

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | Native fixture compiler failure; zero runtime | 59.043 |
| baseline-corrected | Five executed absent-interface/addSourceBuffer failures | 40.446 |
| focused | Original five native cases PASS | 55.921 |
| default | 23/23 files PASS before brand correction | 827.155 |
| gc-none | 23/23 files PASS before brand correction | 778.813 |
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

The first baseline has four invalid error returns in void test functions and
zero test runtime. The corrected baseline executes all five original cases:
one absent-interface assertion and four missing-addSourceBuffer exceptions.
The final host file adds two cases and the actual page fixture. The focused
five-case run passes before those additions; the final runs include every
final fixture and implementation on unchanged file snapshots. Their actual
HEAD/status are retained; file-content validation precedes the feature commit.

Both broad commands use `VJOBS=2` and
`/Users/alex/code/v/v -old-compiler -enable-globals test mediasourceextensions`
plus five browser binding files,
two page files and `main_test.v` (66 cases). GC-none adds `-gc none`.
All 15 module files are included. Those sweeps precede the shared error-brand
correction. The final four-file commands run `buffer_source_error_brand_test.v`,
`media_source_buffer_host_test.v`, `crypto_digest_host_test.v` and
`main_media_source_buffers_owner_test.v` in each mode after that correction.
The broad snapshots record 4,852 files; the post-brand snapshots record 4,853.
Each pair is unchanged, including 16 selected Source references and two compiler
executables. An additional pinned AbstractOperations.cpp reference is hash-checked
against the Source commit. After the final tests, unrelated Crypto formatting
is restored with identical non-whitespace tokens, V string literals and copier
constant. No new runtime behavior is introduced by that restoration. The exact
before/after representations and restoration proof remain retained.

Frozen production `1b436216` builds and ad-hoc signs successfully, passes
signature verification and headless startup, and passes the public page's
synchronous setup checks. Its queued public page verifies buffer/list identity,
append/remove task ordering, mode/timestampOffset writeback and endOfStream.
The native viewport matches its green reference over **480,000 pixels** with
**zero differing pixels**; maximum channel error, MAE and RMSE are also zero. The diff command
explicitly passes `0 0` tolerances. The headless page checks setup only; the
queued completion is verified by the native rendered page. Code, selected
Source files, compilers and the binary stay unchanged through these commands.
Binary SHA256 is `9422a724c62670976cadff60a8f947e4f9fbb5f780b459df21172e4a9b9fa814`.
Production manifest SHA256 is `60d44cc8f8b1a56940061fd0a276d59ead045e87a83068ba680492cfb6501487`.
No standard smoke screenshot sweep or new Wasm/LibJS package sweep is claimed.

Shared retained evidence `Build/audit-fixes/native-media-buffers-evidence.json`
has SHA256 `daa0407d825d1987dc32c623d9e4d0543cb35513371276d754f4c40dee67ea66`. It records all nine test manifests,
production argv/exits/log hashes, private baseline fixtures, the formatting
restoration, feature commits and inventory. The refreshed inventory artifact
`Build/audit-fixes/source-current-module-loc-1b436216.json` has SHA256
`683cda23adcb72215c2ae225829c749f542c12b9d0373b9f1ccc2a26621e3261`. Module counts are unchanged;
these additions belong to excluded browser/root support.

## Remaining boundaries

Caller-realm TimeRanges, the IDL FIXME attributes and operations,
DedicatedWorker startup, foreign realms/WrapperWorlds, Source event clocks,
full codec/demuxer/playback behavior, UTF-16 parser boundaries, large allocation
limits and physical weak/strong GC equivalence remain separate. Native maps
retain owners for Runtime lifetime; callback safety and both GC modes do not
prove upstream collector behavior. The audit stays **32 fixed / 25 partial /
9 open**. Module LOC remains **432,276 implementation / 153,754 test** across
78 owners because browser/root support is excluded.

The preceding [buffer event task correction](SOURCE_BUFFER_EVENT_TASK_OWNER.md)
and [list task ordering correction](SOURCE_BUFFER_LIST_TASK_OWNER.md) provide
the queued-owner prerequisites. This feature adds public native callers.
