# JPEG XL LF streams and HF metadata

Three additional V slices on 2026-11-09 reconstruct HF metadata and connect
HF metadata/VarDCT LF stream decoding to the existing modular and reconstruction
stages. The package now has **281,817 frozen source records and 68 test files**.
The preceding [65-file checkpoint](JPEGXL_V_HF_ENTROPY.md) remains the last full
selection; its later signed-zero fix and these three slices put cadence at
**4/10**. A full 68-file pass is not claimed.

| Slice | Commit |
| --- | --- |
| HF metadata map reconstruction | `805f49bb1` |
| HF metadata modular stream | `e3e3280ca` |
| VarDCT LF stream | `244451805` |

The production decoder, Cargo/CI hooks and native JPEG XL developer test still
require Rust. LF/global/frame assembly, frame dependencies, feature streams,
final image resampling and production integration remain. These checks do not
establish complete-file VarDCT or production-browser parity.

## Metadata reconstruction

`reconstruct_hf_metadata` consumes four decoded modular planes: two 64px color
tile maps, a two-row transform/quantization table and a per-block sharpness
plane. It preserves signed16 truncation, signed color clamping, quantization
clamping to 1..256, all 27 transform kinds, anchor/follower IDs, 32-block group
boundaries, subsampling restrictions and source acceptance of unused trailing
transform records. Width/height are bounded to 1..256 LF blocks and count to
1..65,536. Source error strings, partial output maps on error, image padding,
borrow ownership and unrestricted internal APIs are not parity claims.

The original **3,129-byte** `decode_hf_metadata_finish` function is included
unchanged in a temporary migration oracle. It uses the cached original integer
image/rectangle types, transform metadata and errors. Thin adapters supply
decoded modular channels, the normalized `is444` predicate and typed output
rows; output-row adapters check type identity before borrowing the actual image
row. The cached output-buffer row method is crate-private, so this reference
does not exercise pipeline output-buffer ownership. Inputs are independently
constructed; expected maps never run the candidate V algorithm.

There are **256** frozen records: **208 accepted and 48 rejected**, including
complete 256x256 LF groups, every transform, clamping endpoints, wrapped input
values, oversized/cross-group transforms, subsampled large transforms, invalid
IDs/sharpness and exhausted/trailing records. Successful comparisons serialize
every visible color, raw-quantization, transform and sharpness word, plus width
and height: **773,525 exact little-endian u32 words** in total. Rejections
normalize to `err` with no partial map serialization. Separate API tests check
channel geometry and unused invalid transform records.

| Reference input | SHA-256 |
| --- | --- |
| `jxl` 0.7.0 crate | `6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e` |
| Original `frame/modular/mod.rs` | `8c1e521cd0343d6d55b6f7d8f203c3c5655d5a98eb0229a501b7424f03bab853` |
| Temporary oracle source | `693bf5a756c8aa0b3112fb26583043758b917f12232a68a0ae140f560a05070e` |
| Frozen `hf-metadata.tsv` | `ad79e4761a739f9482fa068f6c4247d45dfd5afe94b98ceaba94f1a0afe7c499` |

The original file is byte-verified against the cached crate archive. Cached
library/transform artifact pins and Rust compiler flags are those in the
[HF/color report](JPEGXL_V_HF_ENTROPY.md). No Cargo rebuild, source-gold refresh
tool or runtime Rust dependency is introduced. Source compilation and execution
run under separate 3 GiB guards. The final compile exits zero at 117,833,728-byte
sampled peak in 0.502 seconds; source execution exits zero at 30,752,768 bytes in
2.360 seconds. The first compile failed on the crate-private output row method
(exit 1, 97,271,808 bytes, 0.625 seconds); the typed row adapters resolve that
access without changing the original reconstruction arithmetic.

## Stream composition

`read_hf_metadata` reads the declared transform count and decodes the four
modular planes before reconstruction. It preserves the two color planes' shift
metadata, group-local geometry and `1 + 2 * num_lf_groups + group` stream ID.
Section padding remains the owner frame's responsibility.

`read_vardct_lf` reads the two-bit extra precision, derives normalized sampling,
decodes the original **Y, X, B** channel order and invokes LF reconstruction and
LF-context generation. Its stream ID is `1 + group`. Returned planes use local,
already subsampled block coordinates. Existing frame geometry and modular APIs
are reused. These VarDCT APIs require the source format's fixed group-size shift
of one; malformed geometry and group indices fail before input consumption.

Constructed composition tests run **33 successful packets per stream reader**
and six malformed/missing-tree inputs per reader. They use actual Huffman
single-symbol entropy, supplied global decision trees, both storage widths,
unaligned prefixes and non-power-of-two edge groups. Stream-property trees make
an incorrect stream ID change decoded values. Metadata tests exercise four
different transform/color/sharpness constants and unused count records. LF tests
distinguish all three coded channels, all four sampling modes, every extra
precision and strict LF threshold buckets.

These are composition checks against specified constant packets and known
planes. They are **not** a new independent native compressed-stream corpus.
The underlying decoder already has its separate 303-record source modular-stream
corpus and LF reconstruction has 512 native cases; both regression files are
included in the final checks. Final image/frame assembly remains open.

## Executed checks

V remains `0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
All V checks use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc`, `RUST_CARGO=/unavailable/cargo` and
`-memory-limit 10G -b c -cc clang`. Every job uses its own 3 GiB process-tree
memory guard. GC modes run separately. RSS is sampled and shared pages may be
counted twice; this is not an allocation or performance claim. Unrelated host
work existed.

| Successful focused check | Peak RSS bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | --- |
| Metadata, default | 322,174,976 | 4.096 | 0 / 0 |
| Metadata, no GC | 315,834,368 | 3.807 | 0 / 0 |
| Metadata, optimized | 499,793,920 | 8.786 | 0 / 0 |
| Metadata stream, corrected default | 294,453,248 | 3.509 | 0 / 0 |
| LF stream, default | 296,763,392 | 4.110 | 0 / 0 |
| Final six-file selection, default | 322,945,024 | 14.658 | 0 / 0 |
| Final six-file selection, no GC | 315,490,304 | 17.219 | 0 / 0 |
| Three new files, optimized | 502,464,512 | 20.307 | 0 / 0 |

The first metadata-stream test used Result propagation for an Option (compile
exit 1, 130,531,328-byte peak, 3.751 seconds). Its corrected test explicitly
unwraps the optional single-symbol query; packet inputs and expected outputs
were unchanged. Failed compile attempts receive no execution credit.

The final six-file command, inside its unique memory guard, is:

```sh
/Users/alex/code/v/v -memory-limit 10G -b c -cc clang test \
  jpegxl/hf_metadata_test.v jpegxl/hf_metadata_stream_test.v \
  jpegxl/lf_stream_test.v jpegxl/modular_stream_test.v \
  jpegxl/modular_groups_test.v jpegxl/vardct_lf_test.v
```

The second selection adds `-gc none`; the optimized selection adds `-prod` and
selects only the first three new files. All actual test and guard exits are zero.
The final **256-input** sorted `path<TAB>SHA256<LF>` manifest has SHA-256
`30c337be8965e83df63593d3f85ef926033ec1eee0116cf9bfb3705c30eca2d2`.
It covers every package V source/test file, recursive data/test fixtures, all
seven browser JPEG XL resources, the V corpus checker and memory guard. All
content hashes/change times and the compiler pin remain unchanged across final
default/no-GC selections and optimized checks.

The job's temporary source-reference programs, binaries, inputs, locks and
reports under `Build/pure-v-jpegxl-metadata-20261109-15` are deleted after receipt
and unlocked-lock verification. Shared build artifacts remain untouched. No
newer full-suite run or manual production build was requested. Each commit
requests the managed shared production rebuild; no browser validation is claimed.
