# Native TimeRanges and SourceBuffer buffered snapshots

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature: `35a7fa38d19683d856f30ab2cad22462b553a1a3`. Implementation and focused tests share this commit.

Actual Window MediaSource installation now exposes the TimeRanges interface
and SourceBuffer.buffered. The getter invokes the existing V SourceBuffer
algorithm and wraps the returned HTML TimeRanges record in its calling
Runtime. It creates a fresh snapshot on every successful read. Wrapper
identity for one native range record is stable within one Runtime, while
independent Runtimes use separate wrapper maps and prototypes. The pinned
realms.py policy explicitly selects the caller realm for NeedsCallerRealm
members. Cross-realm borrowing remains outside this host slice.

TimeRanges exposes the readonly length getter and start/end operations,
with native function metadata and the IDL property flags. Its interface
constructor rejects both invocation and construction. Instances inherit
Object.prototype through TimeRanges.prototype and have the pinned string tag;
there is no indexed or iterable interface in the pinned IDL.

Receiver checks run before argument count validation and index conversion.
Indices use the existing WebIDL unsigned-long conversion with the actual
engine ToNumber operation, including truncation, modulo wrapping, nonfinite
zero conversion and BigInt/Symbol rejection. Author conversion exceptions
preserve their original JavaScript value. Invalid converted indices become
native IndexSizeError DOMExceptions with code 1 and the Source diagnostic.
Captured runtime intrinsics and stored prototypes avoid author Number,
TimeRanges and DOMException replacement during wrapping and error creation.

The existing V buffered algorithm still rejects a removed buffer. Pinned
SourceBuffer.cpp labels that guard as FIXME and does not implement it. This
slice preserves the existing translated behavior and records this deviation;
it does not claim exact removed-buffer Source parity. Existing snapshots
remain readable after append, removal and media detachment.

## Focused checks and evidence

Five host cases cover fresh snapshots and getter metadata/receiver rules;
TimeRanges metadata, native identity and integer conversion; brand/conversion
ordering and original exceptions; independent runtime wrappers and closed
runtime safety; and actual native append/remove snapshots. The byte-stream
fixture contains a complete EBML initialization for one VP9 track and a
single keyframe Cluster. It exercises translated buffered range records,
not a complete codec or playback path.

The root page case runs through actual document startup and sourceopen and
updateend callbacks. It attaches the actual video through the native object
URL, appends initialization and Cluster bytes, reads the resulting range,
removes it and checks that both the empty and populated prior snapshots stay
unchanged. The actual media owner and HTML script execution-depth cleanup
are verified.

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | Original absent interface/getter assertion fails at runtime | 51.638 |
| focused | Immutable closure capture compiler failure; zero runtime | 77.295 |
| focused-corrected | Five host cases and one actual page case PASS (2 files) | 139.191 |
| default | 22/22 files PASS | 1403.951 |
| gc-none | 22/22 files PASS | 1353.273 |

The initial baseline and its original files are retained. The first focused
compile rejects the cleanup closure's immutable binding capture. Its source
representations and log are retained separately from the executed baseline.
Review also corrects private fixture byte lengths and unrelated interface
lookups before any of that draft's test cases execute. Before the broad runs,
getter metadata and receiver assertions are strengthened and failed native
unwrap/closed-runtime operations are explicitly required to fail.

The final commands use `/Users/alex/code/v/v -old-compiler -enable-globals`,
`VJOBS=2`, and add `-gc none` for the second mode. They include the five-case
host file, existing native buffer host, DOMException and numeric conversion
neighbors, all 15 MediaSourceExtensions test files, HTML support algorithms,
the new page case and the 66-case main regression.

Manifest and retained log paths use the
`Build/audit-fixes/native-time-ranges-<mode>` prefix. The final pairs record
**4,859 unchanged files**, **12 selected Source references**
and two compiler executables. Their snapshots are identical, including the
actual pre-commit HEAD/status. The committed implementation has the same
verified file bytes. A supplemental realms.py hash is checked against the
pinned Source commit and recorded separately from those 12 run references.

The consolidated `Build/audit-fixes/native-time-ranges-evidence.json` has
SHA256 `b21b679b4ca92c876fa1677dad0c139ba34b6375043df9fc4312a1e2c250d77d`. It records all
five manifests and log hashes, retained baseline/compiler-failure files,
helper hashes, the supplemental Source policy and feature commit. The final
default manifest has SHA256
`bbd0d41b0a6c7bb76ada5a6aaa10c3d5e72c967348378e70bae30c4871588f7c`;
the GC-none manifest has SHA256
`52a37c70187818e5722dd74a7ff04a1b89911cd6de9cd035cb4fcbb74d4c9aa1`.
All five changed/new V files pass `v -old-compiler fmt -verify`, and
`git diff --check` passes.

## Remaining boundaries

These wrappers use the actual calling Runtime but do not establish foreign
realm borrowing, WrapperWorld support, DedicatedWorker startup, IPC or
physical weak/strong collector equivalence. Native records and JavaScript
wrappers remain retained for the Runtime lifetime. HTMLMediaElement's public
buffered/seekable/played exposure, upstream FIXME track/window members and
complete demuxer/decoder/playback behavior remain separate.

The last [frozen native buffer production proof](NATIVE_MEDIA_SOURCE_BUFFER_OWNER.md)
predates this getter. No rebuilt production, screenshot sweep or current
Wasm/LibJS sweep is claimed for this feature. The audit remains **32 fixed /
25 partial / 9 open**. Module physical counts stay **432,276 implementation /
153,754 test V LOC** across 78 owners; this slice adds browser/root support.
