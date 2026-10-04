# FileReader text package source mapping

Source: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
This document covers the typed text package, not the complete FileReader owner.

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
explicit `process_pending_tasks()` call. Packaging does not provide Source's
ReadOperationState/default-reader graph, Promise callbacks or native FileReader
wrapper-world ArrayBuffer result cache. The independent global/task/event owner
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
The V Infra function is currently a compatibility string identity. Source's
unchecked ASCII storage retains raw byte metadata and its raw code-unit/native
primitive access is a separate boundary. Its UTF8 projection returns those
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
