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

The JavaScript binding owns a zlib decoder context or a buffered Brotli
decoder for each DecompressionStream and uses the translated native
TransformStream queues. Each write copies BufferSource internal slots, emits
zlib-family output immediately, and preserves output produced before an invalid
checksum or trailing-input error. Flush requires the codec end marker.
Cancellation, errors and runtime shutdown release codec contexts. Both the
current IDL name `brotli` and the existing `br` alias are accepted. The older
complete-buffer model API remains available for internal callers.

zlib-family decoding links zlib. Brotli decoding and encoding use vlib's pure V
`x.compress.brotli` codec (quality 5, 4 MiB window for encoding) and link no
Brotli library. That decoder takes a whole stream, so the incremental decoder
buffers input and re-decodes once it has grown by a quarter (or on flush): a
Brotli DecompressionStream emits its output when the stream's last meta-block
arrives rather than per meta-block, and the total work stays linear. Bytes after
the stream are located by decoding prefixes, so output before trailing input is
still delivered. The other encoders retain their valid stored-DEFLATE streaming
implementation. Native binding coverage does not establish all upstream
compression tests or production browser acceptance.

## Verification

```text
$ /Users/alex/code/v/v test compression
Summary for all V _test.v files: 1 passed, 1 total.
```
