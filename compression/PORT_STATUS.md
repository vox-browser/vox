# Compression module V translation

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Compression`

Translation workspace: `~/code/libweb_v/compression`
Audited: 2026-08-16

Both upstream Compression `.cpp` implementation units have an audited V
implementation mapping. Their headers and Web IDL format enums are represented
by typed V streams, constructors, and records.

| Upstream implementation unit | V implementation |
| --- | --- |
| `CompressionStream.cpp` | `compression_stream.v` |
| `DecompressionStream.cpp` | `decompression_stream.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Compression/` | 2 | 359 | 322 | 135 | Complete |

The port covers format parsing, zlib, raw DEFLATE, and gzip encoding and
decoding, the readable/writable transform boundary, chunk copying, flush and
close state, error propagation, end-of-stream validation, checksum validation,
and rejection of data trailing a raw DEFLATE stream.

The JavaScript binding owns a native zlib or Brotli decoder context for each
DecompressionStream and uses the translated native TransformStream queues.
Each write copies BufferSource internal slots, emits decoded bytes immediately,
and preserves output produced before an invalid checksum or trailing-input
error. Flush requires the codec end marker. Cancellation, errors and runtime
shutdown release codec contexts. Both the current IDL name `brotli` and the
existing `br` alias are accepted. The older complete-buffer model API remains
available for internal callers.

Native decoding links zlib and libbrotlidec; Brotli encoding links
libbrotlienc. The other encoders retain their valid stored-DEFLATE streaming
implementation. Linux setup already installs libbrotli-dev. Native binding
coverage does not establish all upstream compression tests or production
browser acceptance.

## Verification

```text
$ /Users/alex/code/v/v test compression
Summary for all V _test.v files: 1 passed, 1 total.
```
