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

The Source replacement decoder is a separate missing dependency: standardized
labels such as `iso-2022-kr` select `replacement`, which LibTextCodec supports,
but the existing V helper delegates to public TextDecoder and rejects it. A
Unicode BOM bypasses that fallback, while no-BOM replacement remains open here.
The exact pinned dependency is `encoding_rs` 0.8.40, recorded in Source's Cargo
manifest/lock; its `src/replacement.rs` and LibTextCodec Rust bridge provide the
body for the separate internal-decoder follow-up.
