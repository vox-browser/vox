# FileReader text package source mapping

Source: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
This document maps the completed package/read-operation slices and their
remaining native receiver, witness and wrapper-world boundaries.

`FileAPI/FileReader.cpp:137` selects an explicit encoding label, otherwise a
parsed MIME charset, otherwise UTF-8. Its Text arm then calls
`LibTextCodec/Decoder.cpp:378`'s given-decoder BOM override rather than the public
Encoding API TextDecoder constructor. `fileapi/file_reader.v::blob_package_data`
now invokes the existing translated `encoding/decode_with_bom_override.v`
helper at that same boundary.

A Unicode BOM overrides either selected label. The pinned Source helper removes
the sniffed BOM, then asks the selected Rust decoder to decode with BOM removal;
two matching initial BOMs are therefore removed, a third remains, and an
opposing UTF-16 BOM becomes U+FFFE. This preserves the actual pinned behavior
and its I/O-queue FIXME rather than rewriting it from the specification.

The new `file_reader_text_bom_test.v`, existing reader regressions and existing
decoder tests pass **3/3 in both GC modes**, recorded in assignment 7's
`Build/audit-fixes/source-file-reader-text-bom-{default,gc-none}.log`. They cover
explicit/MIME/default selection, UTF-8 and both UTF-16 override directions,
repeated and opposing BOMs, synchronous readAsText and the existing asynchronous
compatibility adapter's resulting text/events.

The asynchronous compatibility read adapter retains copied pending bytes and an
explicit `process_pending_tasks()` call. That compatibility path is distinct from the subsequently translated actual
ReadOperationState/default-reader/Promise owner graph described below. Neither
path supplies the native FileReader wrapper-world ArrayBuffer result cache. The independent global/task/event owner
prerequisite below supplies actual owners for those operations.

## Internal replacement decoder

Source `LibTextCodec/Decoder.cpp:283` and `:476` select a RustDecoder for the
standardized `replacement` encoding. Its Rust bridge (`Rust/src/lib.rs:81`)
accepts the label and invokes `decode_with_bom_removal` in replacement mode.
Source's public Encoding/TextDecoder constructor separately rejects this
encoding. The prior V helper incorrectly shared that constructor rejection
with its internal decoder path.

`encoding/replacement_decoder.v` translates the exact pinned `encoding_rs`
0.8.40 dependency's `src/replacement.rs::decode_to_utf8_raw` and
`src/lib.rs::Decoder::decode_to_utf8` replacement wrapper. The actual `emitted`
slot remains false after empty input or output capacity below three bytes.
The first malformed result consumes one byte; the wrapper emits one U+FFFD;
subsequent input is consumed without output. The one-shot adapter allocates the
Source decoder's three-byte maximum output. Replacement itself removes no BOM;
the existing Source helper's prior Unicode sniff still overrides it.

FileReader explicit/MIME replacement labels now return empty text for empty
input and one U+FFFD for any nonempty input without a Unicode BOM. Public
TextDecoder still reports RangeError for every replacement label.
Raw decoder/capacity state, emission across chunks, labels, internal BOM
override, explicit/MIME ordering and synchronous FileReader tests pass with
the existing BOM and public decoder-stream neighbors: **5/5 in both GC modes**
in `source-replacement-decoder-{default,gc-none}.log`.

`tools/source_replacement_decoder_probe.py` includes the unmodified Source
LibTextCodec Rust bridge in a temporary test crate. It copies Source's Cargo
lock, pins encoding_rs 0.8.40 and checks the cached package's SHA256 against the
locked checksum (`2a7a45518d2863d18aa47f4a0cf9faec2aa4304cc09df5e41299f276b3ad135e`).
Every cached package file is checked against that archive before compilation.
The actual bridge's labels/one-shot/replacement/fatal behavior and the actual
raw decoder's state/capacity behavior pass **2/2 in debug and 2/2 in release**,
recorded in `source-replacement-decoder-probe.log`. This probe does not compile
the C++ FileReader owner or establish legacy iconv decoder parity.

## FileReader global/task/event owner prerequisite

`fileapi/file_reader_global_context.v` retains the real creation global
EventTarget and its HTML owner operations. `html/file_reader_operations.v`
creates this context from genuine Window/Worker settings and preserves Source
`FileReader.cpp:95`'s WindowOrWorkerGlobalScope verification with a fatal boundary.
Every closure retains those settings and therefore their creation Realm and
relevant agent; no author property/ID or newly manufactured global is consulted.

The queue hook translates `HTML/EventLoop/EventLoop.cpp:774`'s JS::Object
`queue_global_task` overload: it uses the creation settings' event loop and
reads their current associated Window Document at queue time; Worker tasks have
no Document. It does not call the DOM::Node/current-Document overload or capture
the Document at FileReader construction. `FileReader.cpp:193`'s wrapper obtains
the actual currently running TaskID, invokes its callback, then removes only
that ID from the reader's pending set. Source `abort()` removes matching IDs
from the genuine affiliated queue, clears the set, sets the abort flag, and
fires the trusted events. Reentrant work queued by an abort handler retains its
new IDs when the old executing wrapper returns.

`create_associated_event` uses the existing HTML global-relative high-resolution
clock (`global_relative_event_timestamp`) for the actual settings and keeps
ordinary trusted, non-bubbling/non-cancelable Event records. Standalone reader
construction/manual task processing stays a separate compatibility path.

The focused actual-owner, existing standalone reader and existing owning Blob
files pass **3/3 in both GC modes**, recorded in
`source-file-reader-owner-{default,gc-none}.log`. Actual event-loop processing
tests cover creation-global identity, Document capture at queue time, inactive
queued Document retention, Worker loop/null Document, affiliated-only task
removal, reentrant abort-handler tasks, trusted Window/Worker clock values and
the loadend suppression after a reentrant read. Test loading state still uses
the existing compatibility read entry point; the Source Stream read operation,
native FileReader wrapper/bindings and wrapper-world result cache remain open.

## BinaryString byte/code-unit packaging

`FileReader.cpp:181` uses `Utf16StringBuilder(bytes.size())`, appends each byte
as one code unit, and returns the resulting UTF16 string. The former V helper
manually emitted UTF8 bytes. `file_reader_binary_string` now appends exactly
those u16 values to the code-unit buffer and constructs the existing owned
Source `libjs.Utf16String` record. Its existing UTF8 projection supplies the
standalone result's compatibility string. No byte decoder or independent
UTF8 encoder is used; every input byte maps to the identical value in 0–255.

The focused BinaryString and existing reader files pass **2/2 in both GC modes**
in `source-file-reader-binary-string-{default,gc-none}.log`. Tests cover all
256 values, embedded NULs, BOM byte sequences retained verbatim, ASCII versus
UTF16 storage, immutable input ownership and FileReaderSync's same package.
This feature changes no LibJS implementation and supplies no native result
wrapper or per-world cache.

## Data URL record prerequisite

Source `LibURL/URL.cpp:167` constructs a genuine URL record: scheme `data`, an
opaque path and exactly one path string built from MIME, optional `;base64`,
a comma and payload. It does not parse either input or percent-escape spaces,
query/fragment punctuation, NUL or non-ASCII bytes. `url/data_url.v` now
translates that helper and uses the existing translated URL serializer.

The new data URL record and existing URL record files pass **2/2 in both GC
modes** in `source-data-url-record-{default,gc-none}.log`, covering record fields,
both base64 modes, opaque literal byte preservation, empty inputs and separate
record/path ownership. The helper prerequisite is committed separately from
the FileReader caller feature.

FileReader's Source DataURL arm calls this helper, serializes it, then invokes
`Infra/SerializedURL.h:16`'s `Utf16String::from_ascii_without_validation`.
The original V Infra function remains a compatibility string identity for
older consumers. The separate owned-record caller below now retains Source's
unchecked ASCII bytes and code-unit/storage metadata; native primitive access
is a distinct adapter. Its UTF8 projection returns those
same bytes without decoding (`AK/Utf16View.cpp:17`), so direct V concatenation
already matches compatibility bytes. This does not justify replacing that
Source ASCII record with UTF8 decoding, arbitrary byte widening or new escaping.

The separate `blob_package_data` caller feature now follows that Source call
chain through the genuine `url.create_with_data` record, its existing serializer
and Infra's existing UTF8 compatibility projection. FileReader DataURL,
existing reader and URL helper files pass **3/3 in both GC modes**, recorded in
`source-file-reader-data-url-{default,gc-none}.log`. Tests retain default MIME
selection, literal supplied MIME without parsing/escaping, empty payloads,
UTF16-label irrelevance and raw WTF8/non-ASCII/NUL serialized compatibility
bytes, including the actual internal Blob/FileReaderSync caller. These byte
checks do not establish Source's unchecked ASCII storage or native primitive
code-unit projection.


## Fixed typed-array length prerequisite

The separate typed fixed-view prerequisite retains `BufferSource.array_length_`
at view construction, using Source `TypedArray.cpp:116`'s original byte length
divided by element size. The optional getter is available only for typed
arrays. This slot stays unchanged after detachment or an out-of-bounds witness,
so FileReader's `contained_data` check need not infer the original length from
copied witness bytes. New slot and existing buffer files pass **2/2 in both GC
modes** in `source-fixed-array-length-{default,gc-none}.log`. Native arrays and
auto-length views remain outside this fixed typed record; no LibJS code changed.


## FileReader stream and callback-context owner prerequisite

Source `FileReader.cpp:215` obtains the reader's creation relevant Realm, then
calls `Blob::get_stream(realm)` and `get_a_reader()`. Its setup task and both
Promise callbacks enter `TemporaryExecutionContext(realm, Yes)`. The separate
owner prerequisite extends the genuine FileReader global context with that
`StreamRealm`, the actual settings' existing Blob stream supplier, and a runner
which enters and closes the existing Source temporary execution context. No
standalone byte aggregation callback or newly fabricated global is supplied.

`create_file_reader_in_realm` retains explicitly supplied creation-Realm hooks;
the realm ID must equal the actual settings' Realm. The ordinary owner entry
point uses `settings.stream_realm()`. Both continue to use the same actual
Window/Worker FileReading queue, microtask jobs and associated global. This
owner bridge alone does not change the compatibility asynchronous read body.

The context regression retains an actual pending Blob stream default reader
and its existing WebIDL Promise, observes settlement through the owning
microtask queue, enters the reader's exact principal/incumbent settings, and
checks cleanup of nested script/callback contexts. The existing typed
`DefaultReaderReadRequest` result-object projection remains a typed boundary;
this prerequisite does not claim genuine native result objects, native
FileReader exposure, per-world ArrayBuffer caching or native Uint8Array
retained-length witness parity.

The new stream-context, existing FileReader owner and owning Blob files pass
**3/3 in both GC modes**, recorded in
`source-file-reader-stream-context-{default,gc-none}.log`.


The separate owning-Realm check uses an unconditional mismatch guard and
Source VERIFY panic before context/Blob/task construction, so `-prod` cannot
remove the verification. An actual wrong-Realm subprocess checks the fatal
diagnostic rather than an author-visible error. The stream-context file passes
**1/1 in both GC modes**, and its production-valid fixture passes **1/1 with
`-prod -gc none`**, recorded in `source-file-reader-owner-verify-*` logs.

## Actual owning asynchronous read operation

`fileapi/file_reader_stream_operation.v` now translates Source
`ReadOperationState` and `FileReader.cpp:215–375` through the established
creation-global owner context. It snapshots the Blob type, throws the actual
typed InvalidStateError record while loading, resets result/error/abort state,
obtains the genuine owning Blob stream and its default reader, initiates a
chunk read, then retains the actual reader, empty bytes, first-chunk flag,
optional monotonic timer and recursive Promise-processing closure.

The setup task is queued directly on the actual global's FileReading queue,
outside the reader's affiliated TaskID set exactly as Source. Each chunk uses
the retained `ReadPromise.as_webidl_promise()` capability and real owning
microtask scheduler with Source temporary contexts. Fulfillment queues
loadstart once, reads the existing typed default-reader value/done result,
appends the represented fixed Uint8Array bytes, throttles progress at exactly
50ms using the independent retained ArrayLength slot, and reads the next
actual chunk Promise. Completion moves the accumulated bytes into a tracked
FileReading task before packaging and dispatching load/error/loadend.
Rejection uses the corresponding tracked error task. No aggregation read-loop
shortcut or manual pending-byte completion is used for actual owner readers.

Both upstream `FIXME: Set fr's error` omissions remain unchanged: package
errors and rejected chunks fire error but do not manufacture a stored error.
The initial Blob/setup tasks survive abort; already queued affiliated event
tasks are removed. Source uses the shared `m_is_aborted` Boolean rather than
an operation generation. Thus a new read started by an early abort handler can
reset that flag before the old untracked setup callback; the translated body
retains the pinned source behavior. A read started by a load handler suppresses
that operation's loadend while retaining the new operation's tasks.

This body operates through the existing real Streams/Promise owner records
and their typed result-object/fixed Uint8Array projection. It does not establish
native result-object Get operations, genuine native/auto-length SeqCst
witnesses, public FileReader bindings or per-wrapper-world ArrayBuffer identity. Those
remain separate native runtime prerequisites; the later bounded DataURL owner
slice supplies raw unchecked-ASCII result metadata. Standalone `FileReader.create()` and its explicit manual task
adapter retain their existing compatibility behavior.

New actual read-operation, existing owner-task, monotonic-threshold and
standalone reader files pass **4/4 in both GC modes**, recorded in
`source-file-reader-stream-operation-{default,gc-none}.log`. Seven actual owner
cases cover pending Blob/setup/event phases, immutable queued bytes and Blob
type snapshot, actual InvalidStateError identity, all four package types,
empty-chunk progress suppression, early/late abort, load-handler reentrance,
the Source shared-abort-Boolean edge, rejected-stream FIXME behavior and actual
Worker/null-Document routing. The separate threshold test covers no previous
time, exact 50ms and both adjacent nanosecond boundaries.

## FileReaderSync actual ArrayBuffer allocation

Source `FileReaderSync.cpp:31–35` obtains the supplied relevant global's Realm,
copies bytes through `read_as_array_buffer_impl`, then creates a new actual
ArrayBuffer in that Realm. The separate bounded native adapter
`Runtime.source_file_reader_sync_array_buffer` now follows that call chain
using the real supplied FileReaderSync/Blob records and existing genuine
`Runtime.source_array_buffer` engine factory. The Runtime's actual JS context
is the explicit target Realm; no author-visible global alias or constructor
is consulted and no Promise/task path is added.

New Sync allocation and existing genuine buffer files pass **2/2 in both GC
modes**, recorded in `source-file-reader-sync-array-buffer-{default,gc-none}.log`.
Tests verify actual ArrayBuffer identities/prototypes, independently owned
copies after byte mutation, fresh repeated/empty results, the same reader/Blob
in two actual engine Realms and poisoned author ArrayBuffer/globalThis aliases.
Source IDL exposes FileReaderSync only in DedicatedWorker/SharedWorker. This
typed native adapter introduces no Window interface or placeholder constructor;
actual public Worker receiver/constructor bindings remain open.

## Remaining result-world and weak-cache dependency

Source `FileReader.cpp:99–128` selects the relevant target Realm, obtains its
actual `HostDefined.wrapper_world`, and caches a lazily created ArrayBuffer in
`WrapperWorldWeakValueCache<JS::ArrayBuffer>`. Source `FileReader.h:123` and
`Bindings/WrapperWorld.h:100` require both world keys and buffer values to be
weak; `set_result` clears that cache while already handed-out buffers retain
their own storage. Main worlds are agent-owned and can span multiple Realms;
non-main worlds are Realm-local.

The current `bindings/wrapper_world.v` cache is a typed `map[u64]&T`. Its keys
are pointer identities and its values are strong V references, with no weak
key/value pruning. It therefore cannot establish the required weak lifetime
behavior. Native Runtime already retains actual HTML settings through
`bind_scripting_environment`; the result boundary still needs genuine target
HostDefined/world selection and actual weak engine/GC ownership before it can
reuse Source's cache. A new Runtime-context-ID map or a manufactured world
would change the Source identity/lifetime model and is not implemented here.

Raw result strings retain their genuine Source storage through the separate
BinaryString/Text and DataURL owned-slot prerequisites below. Native result
projection and the actual world/weak-cache dependency remain separate. These findings are dependencies for a subsequent result
wrapper feature, not a claim that the newly completed owner read loop or Sync
allocation has provided public FileReader/native-world parity.

## Owned BinaryString and Text result slots

The separate result prerequisite now carries an immutable private
`Utf16String` in `FileReaderResult` for BinaryString and Text. BinaryString
retains the actual byte/code-unit builder record rather than discarding it
through `.str()`. Source Text `FileReader.cpp:174` calls
`Utf16String::from_utf8(utf8_result)`; its actual `String const&` overload in
`AK/Utf16String.h:49` delegates to `from_utf8_without_validation`. The existing
explicit Source LibJS helper supplies this owned record directly, with no
LibJS implementation change and no scalar string iterator substitution.

Clone, `set_result` and `result` retain those exact units and storage metadata.
The typed raw-record getter returns them only for a string result whose
compatibility text still agrees; stale DTO edits cannot reuse old metadata.
Loading/abort/null and byte results return no string record. This initial
BinaryString/Text slice left DataURL behind its genuine unchecked-ASCII
prerequisite; the separate owner slice below now retains that Source record.

New raw result, existing BinaryString/Text BOM and actual owner-operation files
pass **4/4 in both GC modes**, recorded in
`source-file-reader-raw-result-{default,gc-none}.log`. Cases retain all 256 byte
units, NUL, supplementary text, decoding replacement and BOM behavior, lone
surrogates, original wide-ASCII storage, copied input/access ownership,
clone/set/access lifetimes, loading/abort clearing and stale DTO rejection.
Native primitive projection and genuine per-world weak ArrayBuffer caching
remain separate prerequisites.

## FileReaderSync native BinaryString return

The separate bounded native BinaryString adapter follows Source
`FileReaderSync.cpp:46–49`'s `read_as<Utf16String>(Blob, BinaryString)` call, then
passes that exact owned record to the existing genuine
`Runtime.javascript_utf16_string` primitive ABI. This uses the actual supplied
target Runtime and source Sync/Blob records; it does not reconstruct units from
UTF8 diagnostics, consult an author String/global alias or install a public
Worker receiver. New BinaryString and existing Sync buffer files pass **2/2 in
both GC modes** in `source-file-reader-sync-binary-string-{default,gc-none}.log`.
Native tests retain all 256 units, embedded NULs, copied input ownership, empty
strings, poisoned String/globalThis aliases and two actual target Runtimes.

There is no partial async native `result()` implementation here. Its bytes
variant remains behind the actual Source world/weak-cache dependency; no fresh
buffer fallback or invented author-visible unsupported-result error is added.


## DataURL unchecked ASCII result owner

The actual `Infra/SerializedURL.h:16–24` helper delegates to
`Utf16String::from_ascii_without_validation` without decoding its bytes.
The separate `infra.utf16_string_record_from_url_ascii` returns that genuine
translated owned record to the DataURL package arm. FileReader stores it through
the same immutable slot and clone/set/get path as BinaryString and Text. The
legacy Infra string helper remains a compatibility projection for its older
callers. Source default/literal MIME selection, URL creation/serialization and
UTF8 compatibility bytes remain the established call chain.

Feature `62d3111996cbb0a08e9f5376b8cf64d30f9d9a5b` depends on the independently
completed unchecked-ASCII record `f25db8a4ee368ff03692f76c55371f0d752600ca`.
[AK source mappings and native probe limits](UTF16_UNCHECKED_ASCII_SOURCE.md)
explain why raw non-ASCII bytes use the target ABI's plain-char unit projection
and retain their original byte projection. New Infra/owned DataURL and existing
DataURL/raw-slot fixtures pass **4/4 with default GC and 4/4 with GC-none** in
`source-file-reader-data-url-raw-{default,gc-none}.log`. They check raw
WTF8/non-ASCII/NUL MIME bytes, exact unit/storage metadata, empty/default MIME,
actual Sync packaging, cloned/retained ownership and stale DTO rejection.
No native facade, async partial getter or new ArrayBuffer cache is introduced.

The separate tooling followup `d84c28095593428c5324fbdc21fca4ab5253b1ae` now
requires the exact pinned Source HEAD before reading headers or generating
probe artifacts. Its positive -O0/-O2 probe passes in
`source-utf16-ascii-probe-pinned.log`; a temporary wrong-HEAD checkout is
rejected before header access in `source-utf16-ascii-probe-wrong-pin.log`.

The malformed/non-ASCII MIME cases above establish output ownership for supplied
UTF8 compatibility bytes. `blob_package_data` still accepts `mime_type ?string`,
where Source accepts `Optional<Utf16String>` and invokes its `to_utf8()`.
`AK/Utf16StringBase.h:60` declares that operation's default as
`AllowLonelySurrogates::Yes`, but the current probe does not execute the full
native UTF16 MIME-to-UTF8 call chain. Manually deriving compatibility bytes from
a raw V UTF16 record is not additional native MIME-conversion proof. Public
Blob construction normalizes its type to ASCII; the source internal
`Blob::create(ByteBuffer, Utf16String)` (`Blob.cpp:31–35,139–144`) preserves an
explicit supplied type. Native Sync DataURL raw-output fixtures keep this typed
compatibility input boundary explicit; ordinary normalized ASCII/default-type
Blob owners validate its direct native return path.

## FileReaderSync native DataURL return

The separate bounded native DataURL adapter follows
`FileReaderSync.cpp:58–61`'s `read_as<Utf16String>(Blob, DataURL)` call and passes
that exact owned result to `Runtime.javascript_utf16_string`. It uses the
actual supplied target Runtime and Sync/Blob records and preserves the
unchecked ASCII output's code units. Feature
`ff136bce0f1a45b24eaa158f286b3f3ec150c89e` includes its native fixture; that
file passes **1/1 with default GC and 1/1 with GC-none** in
`source-file-reader-sync-data-url-{corrected-default,gc-none}.log`.

Tests check genuine primitive identity/type and unit access, empty/default and
normalized ASCII Blob types, actual target Runtimes and poisoned String/global
aliases. Raw MIME-output cases are supplied compatibility-byte inputs, with the
native MIME conversion boundary above kept explicit. An initial test-only JS
index assertion used positions 7/10 for bytes actually at 6/9; its failing log
`source-file-reader-sync-data-url-default.log` is retained. The direct native
unit-array checks already passed, the fixture positions were corrected, and
both final mode checks passed without production changes.

This supplies no public Worker receiver/constructor or asynchronous result
wrapper. The genuine HostDefined/world weak ArrayBuffer cache remains open.

## Source Windows-1252 decoder prerequisite

Native Sync Text checking exposed a concrete existing dependency: V stdlib
`encoding.iconv.encoding_to_vstring` appends a zero then constructs with
`cstring_to_vstring`, truncating decoded output at its first NUL. Source
`LibTextCodec/Decoder.cpp:131–147` forwards its Rust bridge output through
`append_decoded_bytes` with the explicit length (`Decoder.cpp:115–123`). The
Rust bridge (`Rust/src/lib.rs:81–118`) likewise invokes its byte callback with
`output.len()`. Source therefore preserves leading, interior and trailing NUL.

The separately completed Windows-1252 prerequisite
`65a64f68039d5f091f2c530839facd1ff0d68a78` translates pinned
`encoding_rs 0.8.40`'s `SingleByteDecoder::decode_to_utf8_raw`, scalar
`ByteSource`/`Utf8Destination` positions, ASCII copy, BMP capacity checks and
UTF8 writes (`src/single_byte.rs`, `src/handles.rs`) with its exact
`src/data.rs::SINGLE_BYTE_DATA.windows_1252` table. The flattened phase follows
Source's ASCII acceleration versus inner punctuation loop and its three-byte
BMP reservation; consumed/written counts match the native decoder. All 128
high-byte entries are defined, including C1 controls, so replacement and fatal
modes both accept every Windows-1252 input byte. The whole-input owner uses
Source's maximum `3 * byte_length` UTF8 capacity and returns the produced slice
with its explicit byte length. Physical Rust Cow borrowing/Vec allocation is
not reproduced by the flattened V owned buffer.

Source's maximum-capacity multiplication is checked in `usize`; the current V
byte-array owner uses signed 32-bit `int` lengths. Its allocation guard therefore
rejects input lengths above `INT_MAX / 3`, even where Source's `usize` capacity
could represent the product. This is the existing flattened V allocation
boundary, not Source's exact overflow or allocation-failure behavior. The
independent diagnostic/comment correction
`5b00cae4f609e43f687d1d71eef2ac1549133975` names this boundary explicitly;
it does not change the decoder or its successful byte/capacity results.

`TextDecoder` now selects this translated path for standardized
`windows-1252` (including its existing latin1/ISO-8859-1/ASCII aliases). Other
legacy codecs still use their existing iconv compatibility backend, including
its NUL truncation dependency; this feature claims no complete Rust codec or
legacy-decoder parity. UTF8, UTF16, user-defined and replacement paths retain
their existing separately scoped implementations.

The independent tool `26f5d795ac82edc814afb9735b69f81293ba93cc`,
`tools/source_windows_1252_probe.py`, reuses the existing exact Cargo.lock and
archive-file validation and includes the unmodified pinned Source Rust bridge.
The required Source HEAD is checked before probing. Its **2/2 debug and 2/2
release tests pass** in `source-windows-1252-probe.log`: all 256 bytes, aliases,
fatal/BOM flags, empty input, leading/interior/trailing NUL and 65 raw capacity,
status/read/write/output cases. The committed golden JSON assets are emitted
by those actual Source decoder calls, independently of V's translated table.
MIT and WHATWG notices are retained with the translated algorithm/data.

New golden comparison, existing streaming TextDecoder and given-decoder BOM
files pass **3/3 with default GC and 3/3 with GC-none** in
`source-windows-1252-focused-{default,gc-none}.log`. Native Sync Text remains a
separate consumer feature, rerun after this actual decoder prerequisite.
No LibJS implementation or frozen full-proof checkout is changed here.

## FileReaderSync native Text return

The separate native Text adapter follows Source
`FileReaderSync.cpp:51–54`'s `read_as<Utf16String>(Blob, Text, encoding)` call.
Source's template (`FileReaderSync.cpp:64–70`) copies the actual Blob bytes and
passes its type and encoding to `FileReader::blob_package_data`; the translated
Sync owner already follows that chain. The new adapter takes the resulting
owned raw UTF16 slot directly to the existing
`Runtime.javascript_utf16_string` native primitive ABI. Its supplied Runtime,
FileReaderSync and Blob are actual owning records. Author-visible String and
globalThis aliases do not select the string construction path.

Feature `79ec0465a76f4c73521a6ed2bc5431821a32f526` includes the native fixture.
It passes **1/1 with default GC and 1/1 with GC-none** in
`source-file-reader-sync-text-{default,gc-none}.log` after the separate
Windows-1252 prerequisite above. Tests cover copied input ownership, embedded
and trailing NUL, supplementary units, UTF8/UTF16 BOM overrides, malformed UTF8
replacement, empty output, invalid-label MIME fallback, explicit-label
precedence, poisoned author aliases and two actual target Runtimes. The original
NUL failure logs are retained as
`source-file-reader-sync-text-before-windows1252-{default,gc-none}.log`.
Their expected NUL units were preserved; the separately translated decoder
fixed the underlying output-length dependency.

The adapter's `encoding_name ?string` remains the established typed UTF8
compatibility boundary. Source accepts `Optional<Utf16String>`; generated
optional DOMString conversion and public DedicatedWorker/SharedWorker
FileReaderSync receiver/interface exposure (`FileReaderSync.idl:2–11`) remain
open. This feature covers the owned-result native primitive projection and the
tested decoder paths; other legacy iconv codecs retain their limits above.
It adds no asynchronous result wrapper or replacement for Source's genuine
HostDefined/world weak ArrayBuffer cache.

The subsequent [Source SingleByte UTF8 decoder slice](SINGLE_BYTE_DECODER_SOURCE.md)
replaces the remaining single-byte iconv paths with all 27 pinned Source
tables and the actual malformed/replacement loop. Its exact native bridge
goldens and both-mode/production checks establish that bounded decoder path.
The earlier Windows1252/Text statements about other legacy codecs describe
their scope at that stage; multibyte iconv compatibility and public owner/label
conversion limits remain open after the SingleByte feature.
