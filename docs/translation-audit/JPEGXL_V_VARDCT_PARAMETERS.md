# JPEG XL V VarDCT parameters and orders, 2026-11-09

Four additional slices execute in pure V:

| Slice | Implementation commit |
| --- | --- |
| Quantizer parameters and inverse scales | `91f7da0ef` |
| Color-correlation parameters and factors | `e20d33856` |
| Block maps and coefficient entropy contexts | `5a44b2ad9` |
| Natural and entropy-coded coefficient orders | `32c901c97` |

Focused checks pass in both GC modes and with optimization. JPEG XL cadence is
**4/10** after the preceding full thirty-five-file checkpoint. The corpus
checker discovers thirty-nine files; this continuation does not claim a new
full-package checkpoint. Production JPEG XL still uses Rust.

## Source and comparison boundary

The pinned `jxl` 0.7.0 archive SHA-256 remains
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Quantizer, color-correlation, block-context, coefficient-order and half-float
source files were verified byte-for-byte against that archive. Quantizer and
color references invoke the existing cached crate. Block and coefficient
oracles include the original source files unchanged with cached dependencies,
module reexports, constants and an inert logging macro. Natural orders use the
original transform-type LUT. Its `jxl_transforms` 0.7.0 source was verified
against archive SHA-256
`55b9b6a075a5554b5625828c322975372897be79b347d2795de721d27a2ed2b0`.

The temporary migration oracles linked existing cached artifacts directly;
there was no Cargo rebuild, network access or V-generated expectation. Their
SHA-256 identities were:

| Oracle source | SHA-256 |
| --- | --- |
| Parameters | `de5a96e582d715b247ed8585e1d423a5d6ad68c9a28bbd43c808a548715be1a4` |
| Block contexts | `9f53cf6efe558f33a049c19933a24e5a2ae92d08904f71cfd0347eb871e1e80d` |
| Coefficient orders | `cd4c404276bf682706871c42851ee0c3975451d727e6039519474888ce88d8ac` |

Cached `libjxl-0f4870c888fc4600.rlib` SHA-256 was
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`;
`libjxl_transforms-a858b76184796a88.rlib` was
`e1f0257f34d0017dd69860476cb6bee832e0e8952886326d7094b439ce7a6803`.
Frozen developer checks execute with V alone. Temporary oracle files and job
output were removed after recording this report.

| Frozen corpus | Cases | Successful source results |
| --- | ---: | ---: |
| Quantizer parameters | 4,096 | 4,096 |
| Color-correlation parameters | 4,096 | 2,525 |
| Block-context transcripts | 512 | 375 |
| Zero-density contexts | 8,192 | 8,192 |
| Complete natural coefficient vectors | 13 | 13 |
| Complete entropy coefficient orders | 256 | 153 |

These add **17,165** source cases, bringing the package to **257,783**. Each
map/query transcript or complete order result counts once, consistent with
earlier whole-plane/row/transcript counts.

Quantizer cases cover every selector pair, endpoint payloads and random words;
inverse global and LF scales compare exact binary32 words. Color cases compare
both base values, LF factors, arbitrary signed factors, output float words and
consumed bits. Signed zeros, source subnormal behavior, finite/range rejection
and consuming both half fields before validation are retained. The shared half
conversion still matches the preceding exhaustive primitive corpus.

Block transcripts compare every threshold, every map entry, context counts,
all thirteen shapes and three channels at sampled LF indices, QF threshold
equality/next values, all nonzero buckets and density offsets. LF threshold
selector 3 retains the source's wrapping cast after adding 65,808. Corpus
errors include oversized maps, holes, excessive distinct contexts and EOF.
Zero-density coverage includes all 7,938 normalized coordinate/previous-bit
combinations, plus 254 scaled cases through the largest 32-by-32-block order.
V rejects invalid public indices, storage and normalization coordinates.

Natural vectors compare all **131,328** source indices across the thirteen
shapes. Decoding compares SHA-256 over all 39 component vectors, each prefixed
by its u32 length, with every word serialized little endian. The source process
streams original words into Python's SHA-256; no candidate output participates.
There are 113 accepted non-natural results and 111 distinct accepted digests.
Coverage includes simple prefix permutations, valid/invalid ANS checksums,
accepted LZ77 headers, high mask bits, zero masks, malformed headers and byte
prefixes. Component arrays are independently owned. V computes natural orders
per invocation rather than sharing the source's lazy global cache; no memory
or performance parity is claimed for that ownership choice.

One block record and sixty coefficient records overread EOF in the cached
source. Their rejection results are compared, but their beyond-input cursors
are excluded from position equality because V's checked reads can stop earlier.
All remaining cursor values compare exactly. This preserves the previously
documented checked-reader boundary rather than claiming source EOF cursor parity.

Corpus SHA-256 values:

| File under `jpegxl/testdata/` | SHA-256 |
| --- | --- |
| `quantizer.tsv` | `d4dde011000c90a6a6858172dd44587a90b2b0b5efa02393b9e8265b63778aec` |
| `color-correlation.tsv` | `5f2cb355f4be62d37e307ab685e0c37f779e979372cb92b725d895ac1f1b38de` |
| `block-context.tsv` | `3f880ee3f69007d88a088270a83f8a54cdae1e4c135480d821dc8107631890b9` |
| `zero-density.tsv` | `d8fc396235c627b2d4d87f24759ef1e2339488d870c3f98933f764f4fa6d50ad` |
| `natural-coefficient-orders.tsv` | `4807eb90ea548578f83f01ceea1e9171b0672ebd90cb894e9289a430ac9f857b` |
| `coefficient-orders.tsv` | `fc1b82ef26a7d90704a662f583aec25db0be3ed155d05de1f6e383b1514f3e2d` |

## Executed checks

Every test command uses current V with `-memory-limit 10G -b c -cc clang`,
`V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`, `RUSTC=/unavailable/rustc` and
`RUST_CARGO=/unavailable/cargo`. Separate default/no-GC jobs execute the four
focused files. Color's half-helper extraction also checks
`primitives_corpus_test.v` and `bit_reader_test.v` in both modes. All expensive
commands use `tools/run_memory_bounded.py` with unique locks/reports, a 3 GiB
process-tree budget and a 180-second timeout.

| Successful job | Files | Sampled RSS peak, bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | ---: | --- |
| Quantizer, default | 1 | 272,285,696 | 3.52 | 0 / 0 |
| Quantizer, no GC | 1 | 262,324,224 | 3.49 | 0 / 0 |
| Color, default recovery | 1 | 271,974,400 | 3.35 | 0 / 0 |
| Color and half readers, no GC | 3 | 265,535,488 | 7.82 | 0 / 0 |
| Block contexts, default | 1 | 281,968,640 | 3.49 | 0 / 0 |
| Block contexts, no GC | 1 | 273,104,896 | 3.52 | 0 / 0 |
| Coefficient orders, default | 1 | 321,683,456 | 44.54 | 0 / 0 |
| Coefficient orders, no GC | 1 | 1,495,875,584 | 38.76 | 0 / 0 |
| All four focused files, `-prod` | 4 | 535,724,032 | 32.36 | 0 / 0 |

The first color selection failed to compile its test's unsupported `u64.bytes()`
helper. Both unchanged primitive/bit-reader files passed in that selection;
their default-mode credit is retained alongside the corrected color-only pass.
The test now uses literal encoded bytes. The failed whole selection earns no
whole-batch pass credit. Source results and implementation semantics did not
change to obtain a pass.

An initial block oracle input generator assumed 64 large-alphabet reference
rows existed; it stopped before writing an oracle, and the following compile
exited 1. The corrected generator reused existing cases with maximum symbols
7 and 255. Its first reference run then exited 101 because its wrapper
asserted source cursors could never overread EOF. Removing that wrapper
assertion retained the original source, including the overread rejection.
Only the complete 512-record final source run receives reference credit.

The compiler is `V 0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
A 168-input manifest covers JPEG XL V files and test data, browser JPEG XL
fixtures, corpus checker and memory guard. Its sorted
`path<TAB>SHA256<LF>` SHA-256 is
`8868519ada4a03e523c0dd4bb0bf26e391114013403b405afa6f64d7e253eec6`.
The compiler and all selected inputs were checked before the final no-GC job,
between it and optimized validation, and after optimized validation. All
identities remained unchanged. Other broad suites and historical ledgers were
not changed or rerun.

For example, the optimized command under the shared environment above is:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/pure-v-jpegxl-vardct-20261109-09/vardct-optimized.lock \
  --report Build/pure-v-jpegxl-vardct-20261109-09/vardct-optimized.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang -prod test \
  jpegxl/quantizer_test.v jpegxl/color_correlation_test.v \
  jpegxl/block_context_map_test.v jpegxl/coefficient_order_test.v
```

Default/no-GC commands select the relevant focused file, omit `-prod`, and add
`-gc none` for ownership checks. The no-GC color command additionally selects
the two half-reader files named above. Temporary job locks/reports were released
and removed after these checks. Each focused implementation commit requested
the managed, coalesced production rebuild; no separate browser build was queued.
Standalone codec tests supply this validation, without a production-browser
execution claim.

## Remaining dependency work

VarDCT coefficient reconstruction and transforms, quantization matrices,
VarDCT EPF sigma generation, XYB/transfer conversion, frame dependencies and
rendering pipeline assembly remain. The complete-file V APIs keep their
existing bounded lossless subset. Broader partial/streaming rendering and
production integration remain open.

The tracked Rust source/manifests are still under `native_jpegxl_rust/`.
`images/jpegxl.v` calls the native decoder, `build-prod-browser.sh` builds its
Cargo helper, `tools/test_jpegxl.py` rebuilds that helper for native testing,
and CI still checks the Rust toolchain. Those dependencies must be removed
together after V preserves the production static 8-bit sRGB/gray contract.
