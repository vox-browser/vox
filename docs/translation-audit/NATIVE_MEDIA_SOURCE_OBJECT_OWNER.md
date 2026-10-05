# Native MediaSource object URLs and actual document attachment

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Native feature: `0ea70c17`. Supporting event-target fix: `d397f279`.
Supporting changed-src replay: `6d23dae1`. Each commit contains its own
implementation and focused tests.

The actual Window script startup now installs a native MediaSource wrapper.
Construction calls the translated MediaSource factory with the genuine
relevant settings object's Window EventTarget. It allocates the existing V
MediaSource and its two actual SourceBufferList records. One native wrapper
owns each MediaSource in this runtime, and the same wrapper is registered
with the real EventTarget binding. Prototype changes do not change that
identity. Derived constructors retain their selected prototype and original
prototype-access exceptions.

The exposed slice includes readyState, duration, the three source event
handlers, endOfStream, isTypeSupported and canConstructInDedicatedWorker.
Native accessors and operations have Source property flags and engine method
metadata. State and algorithms remain in the translated MediaSource; the
bridge does not duplicate them. Numeric, DOMString and optional-enum
conversions precede the typed operations after receiver validation. Author
conversion exceptions retain their original engine values. Numeric conversion
uses a captured engine ToNumber function: the JavaScriptCore C conversion
otherwise accepts BigInt, which WebIDL must reject. InvalidStateError
becomes an actual DOMException. The worker capability flag remains false,
as in the pinned Source.

URL.createObjectURL now selects a genuine Blob/File or MediaSource native
wrapper. The MediaSource arm stores the actual V pointer and attachment hook,
with the actual current HTML settings owner. Its empty compatibility ID is
unused; identity and attachment require the live object. Fake prototypes,
Symbol.toStringTag, author Symbol.hasInstance and Proxy wrappers neither
acquire that brand nor trigger author properties during union selection.
Invalid values preserve the generated “No union types matched” TypeError.
Static receiver values are irrelevant to union selection.

The actual HTMLMediaElement caller authorizes its copied URL entry against
its own Document settings, resolves the live store object, assigns that exact
MediaSource and queues sourceopen on the existing HTML event loop. Native
listeners and event-handler attributes observe the same target, callback
receiver and state. The [queued-event correction](MEDIA_SOURCE_QUEUED_TARGET_OWNER.md)
retains the original V MediaSource pointer instead of copying its mutable
receiver. Duration updates reach the assigned media element;
endOfStream queues sourceended. Revoking the URL removes the store entry
without detaching an existing media attachment. A later media load resets the
attachment and queues sourceclose. The Blob Fetch arm rejects a MediaSource
tag even for a document destination, without entering the network hook.

The page fixture uses normal browser navigation and run_document_javascript
startup. Author code constructs the source and URL and writes the actual
video's src attribute through document replay.
[Changed src replay](SCRIPT_MEDIA_SRC_OWNER.md) now synchronizes the cached
media model and invokes the actual resource-selection caller, checking
store/source/settings identity, native event delivery, revocation and
detachment. This proves that public MediaSource construction and URL creation
reach the actual DOM media
owner through a live script attribute change. It does not claim native
JavaScript HTMLMediaElement.load exposure.
Late queued source callbacks after Runtime.close do not enter the released
engine; the existing EventTarget binding's closed owner gate handles them.

## Verification

| Run | Result | Seconds |
| --- | --- | ---: |
| Initial native compile | 2 files fail compilation; zero test runtime | 150.157 |
| First executed native/page batch | Event identity, BigInt conversion and page attachment failures | 220.339 |
| Diagnostic command | Interrupted; excluded from passing evidence | — |
| Diagnostic retry | Host fixture compiler failure; active page still fails attachment | 244.134 |
| Detailed host diagnostic | Wrong copied event target and BigInt InvalidStateError reproduced | 121.357 |
| Corrected four-file batch | 3 PASS; attribute fixture compiler failure | 227.126 |
| Final default neighbors | 5/5 files PASS, including corrected attribute fixture | 205.212 |
| Final GC-none batch | 10/10 files PASS, including 66-case main regression | 322.646 |

Final default coverage is eight distinct passing files across the corrected
batch and final neighbor command. Only the attribute fixture changes between
those commands: its Result-returning helper now handles Options explicitly.
The final ten-file GC-none command uses one unchanged snapshot. Both
unmodified Source URL outputs reproduce all **377 lines** exactly in each GC
mode. Formatting verification and git diff checks also pass.

Initial old-V diagnostics caught an if-expression prototype selection and
two incorrect Option operators on a plain pointer return. The first executed
run then exposed actual wrong event identities and BigInt conversion. Its
page fixture lacked a genuine Page; the corrected Page-backed fixture proves
fully-active state but still reproduces the stale media-model source. The
supporting src correction then makes the public author-script caller pass.
A diagnostic fixture used the nonexistent string.join method. The first
command was stopped and its retry also fails at compilation; neither is
passing evidence. The detailed corrected host diagnostic prints the actual
wrong callback identities and the BigInt InvalidStateError before those
implementation fixes. All logs and original fixtures are retained.

Separate direct baselines reproduce all three queued-event target failures
and both audio/video empty-currentSrc failures. Their earlier shared-directory
and missing-navigation-helper compiler failures have zero test runtime and
are excluded from behavioral evidence. The src baseline retains the exact
prior replay function with the current supporting models; it is not an old
whole-repository snapshot. No pre-change native absent-constructor runtime
baseline was run; that gap was established by inspection.

Exact argv, environment overrides, exit codes, log hashes, private fixtures,
final feature hashes and exact Source-output hashes are recorded in
`Build/audit-fixes/source-media-source-native-manifest.json`, SHA256
`6e343326728ad21b8e4ae513f078a7143578e555d81861eb2e52f804dc9fb5dd`.
The final code snapshot has SHA256
`3ccffc9ac199eab216f87a8c82db957dbc85faa2e9dd93cc4e037c167f1d35f8`.
All **3,176 recorded V/native-helper files**, **42 selected Source references**
and both compiler executables remain unchanged through the final default
neighbor command and ten-file GC-none batch. The three passing files in the
preceding corrected batch have unchanged implementations and test closures;
only the independently compiled attribute fixture differs. External native
libraries and the whole toolchain are outside this record.

The refreshed `0ea70c17` inventory contains **432,272 implementation V LOC /
153,433 test V LOC** across 78 owners. The source-event slice adds six module
implementation lines and 49 test lines; browser/root integration is excluded.
Artifact `Build/audit-fixes/source-current-module-loc-0ea70c17.json` has SHA256
`658656d07641cecbfa8bbcc605608b0574f8d1bddd1c3a922be0fb257e1496f8`.
Physical counts and structural mappings do not measure parity.

## Remaining boundaries

Native SourceBuffer/SourceBufferList wrappers and addSourceBuffer exposure,
DedicatedWorker startup, foreign realm/world identity, Source event clock
integration, complete codec/demuxer/playback behavior, generated diagnostic
text beyond the union error, parser UTF-16 boundaries, allocation limits,
physical GC edges and IPC remain separate. Runtime.close callback safety is
not a physical GC ownership proof. Upstream handle, removeSourceBuffer and
seekable-range FIXMEs are also separate.

The [previous frozen production bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md)
predates this feature and the preceding native URL methods. No updated
production or screenshot verification is claimed. The audit remains
**32 fixed / 25 partial / 9 open**.
