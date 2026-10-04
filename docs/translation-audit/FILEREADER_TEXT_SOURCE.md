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

The asynchronous compatibility adapter retains copied pending bytes and an
explicit `process_pending_tasks()` call. This feature does not provide Source's
owning Window/Worker FileReading tasks, ReadOperationState/default-reader graph,
Promise callbacks, native FileReader wrapper-world ArrayBuffer result cache or
relevant-global event timestamps.

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
