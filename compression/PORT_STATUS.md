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

The JavaScript binding owns a buffered decoder for each DecompressionStream
and uses the translated native TransformStream queues. Each write copies
BufferSource internal slots and preserves output produced before an invalid
checksum or trailing-input error. Flush requires the codec end marker.
Cancellation, errors and runtime shutdown release codec state. Both the
current IDL name `brotli` and the existing `br` alias are accepted. The older
complete-buffer model API remains available for internal callers.

Every format decodes with vlib's pure V codecs and links no native library:
`compress.deflate` for deflate, deflate-raw and gzip, and `x.compress.brotli`
for Brotli, which also encodes (quality 5, 4 MiB window). These decoders take
whole streams, so the incremental decoder buffers input and decodes again once
it has grown by a quarter (or on flush): a DecompressionStream emits its output
when the stream's end marker arrives rather than per block, and the total work
stays linear. A DEFLATE stream's length comes from the raw inflater's consumed
count plus its zlib/gzip framing; a Brotli stream's end is located by decoding
prefixes. Either way output before trailing input is still delivered, and a
following gzip member is trailing input, as with a zlib inflater. The other
encoders retain their valid stored-DEFLATE streaming implementation. Native
binding coverage does not establish all upstream compression tests or
production browser acceptance.

## Verification

```text
$ /Users/alex/code/v/v test compression
Summary for all V _test.v files: 1 passed, 1 total.
```
