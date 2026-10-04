# Source UTF8 decoder prerequisites

Source is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` and its locked
`encoding_rs 0.8.40` package (archive SHA256
`2a7a45518d2863d18aa47f4a0cf9faec2aa4304cc09df5e41299f276b3ad135e`).
The existing hand-written `decode_utf8` has concrete malformed-prefix defects:
`E1 41` drops ASCII A after a prematurely classified truncated sequence, and
`E1 80 41` emits an extra replacement. Actual Source Rust bridge calls produce
U+FFFD followed by A for both inputs. These consumer defects remain open at
the initial validity-only prerequisite below; no decoder-state/consumer fix is
claimed by an otherwise unused private helper.

## Scalar valid-prefix prerequisite

Feature `52534e118c5f98c49084d4a84743eeb7f6eb7600` translates
`encoding_rs/src/utf_8.rs:173–331`'s scalar `utf8_valid_up_to` path and its exact
384-byte `UTF8_DATA.table` (`utf_8.rs:35–73`). It preserves Source's unsigned
wrapping range check (`lib.rs:5029–5031`), ASCII valid-prefix scan,
four-byte-lookahead and shorter-tail branch ordering, two-byte continuation
test, three-byte mask predicate and four-byte mask predicate. Source's manually
inlined next-lead continuations return to the V loop; `break 'outer` returns
the same consumed prefix. Position lookahead is widened for the Source
non-overflowing `usize` arithmetic under V's narrower array-int bounds.

Source's ASCII/SIMD acceleration is lowered to the scalar scan. Its physical
aligned table layout and native SIMD implementation are not reproduced. The
table values and scalar predicates are copied directly from Source rather than
constructed from an independent UTF8 specification or generic replacement
policy. This helper is the prerequisite for
`Utf8Destination::copy_utf8_up_to_invalid_from` (`handles.rs:1093–1103`), which
validates the minimum source/destination span and copies that exact prefix.
That destination operation and the five-slot Utf8Decoder state remain separate
features at this stage. UTF16 conversion, UTF8 encoding and outer Rust decoder
lifecycle/BOM records are also outside this initial slice. LibJS is unchanged.

## Actual Source helper probe and harness scope

Tooling-only `12662a94e9148fd841696118ef52ac2fe36be278` adds
`tools/source_utf8_validity_probe.py`. It verifies the exact upstream HEAD,
Cargo.lock package version, archive checksum and every cached archive file.
The unmodified Source LibTextCodec Rust bridge produces malformed-prefix/fatal
goldens in **1/1 debug and 1/1 release** filtered tests. Source's original two
bridge tests remain present and are filtered for this focused run.

For the private-module helper, the validated complete dependency is copied to
ignored output, and a harness-only export is appended to copied `src/lib.rs`.
All original implementation bytes remain intact. The harness export calls the
actual `utf_8::utf8_valid_up_to`; it does not reimplement that function. A
temporary binary invokes it directly, including native NEON dispatch for long
inputs on the actual AArch64 machine, and emits its returned prefix lengths.
Rust's standard UTF8 validator supplies an additional independent assertion for
the exhaustive short vectors, not the emitted expected values.

The original registry-normalized package manifest could not resolve the unused
optional `any_all_workaround` package in offline mode. That initial failure is
retained in `source-utf8-validity-probe-original-manifest.log`. The copied probe
therefore uses a minimal isolated AArch64 manifest with Source's actual default
`alloc` configuration and exactly locked selected dependencies: cfg-if 1.0.4,
scopeguard 1.2.0, multiversion_no_op 1.0.0, rustversion 1.0.23 and simdutf8 0.1.5
with Source's aarch64_neon/public_imp flags. Optional disabled feature names are
declared for cfg checks. This is an explicit probe manifest/access modification;
it is not a successful build of the original normalized manifest. Upstream and
registry files are read-only, and no original helper body is modified.

Both native debug and release helper runs pass **65,536 exhaustive two-byte
inputs, 1,048,576 exhaustive E0–EF three-byte inputs, 81,920 four-byte boundary
class inputs and 454 ASCII-prefix/tail/SIMD-threshold/lead cases**. Golden binary
files store one actual Source prefix length per declared nested input order;
the JSON file records actual Source input/prefix pairs. These fixture formats
are test data, not a production serialization format.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/utf8_validity_pairs.bin` | `09c2af9b8fa4cc385b80ce34f04da2667c133a9868401043c8f47b926808e614` |
| `encoding/fixtures/utf8_validity_triples.bin` | `32b1089485e53e617903d3f2e302197a2f391c7196f3d5cd664f0721dd6b3ca3` |
| `encoding/fixtures/utf8_validity_quads.bin` | `d250274e411cd742439374ee04c609fb1387b560e3fb70dd6eb31c4bcf0787f0` |
| `encoding/fixtures/utf8_validity_edges.json` | `88608dad0a43528dab8512fd108045a7fc4b89f2c5f5c19907a1952d9fac54c2` |
| `source-utf8-validity-probe.log` | `767332bfefae8ac06f9d7eb195433151dde0d9f7c4a7be17d2704183cf8623da` |

The feature's golden-comparison fixture passes **1/1 with default GC, 1/1 with
GC-none and 1/1 with production GC-none**, in
`source-utf8-validity-{focused-default,focused-gc-none,production-gc-none}.log`.
It checks those exact native returned lengths, NUL, astral sequences, malformed
continuations and incomplete tails. No native browser bundle/capture or frozen
LibJS proof checkout is changed.


## Actual five-slot decoder and replacement prerequisite

Tooling-only `a827ff78` and feature `561ab5e830e73f73ba4531eac981de06f21cd3e2`
add the actual Source Utf8Decoder translation and focused native-golden tests.
`encoding/utf8_decoder.v` translates `utf_8.rs:551–708`: constructor,
`in_neutral_state`, `extra_from_state`, all three checked maximum capacities,
and the UTF8 raw decoder body. Its five retained slots are Source's code point,
continuation count, continuation requirement, lower boundary and upper boundary.
`macros.rs:10–72` checks input availability before destination space and commits
the byte only after four-byte astral space is available. The destination valid
prefix copy (`handles.rs:1093–1103`) uses the prior actual Source scalar validator.
ASCII, two-/three-/four-byte starts, constrained second bytes, invalid-continuation
unread, partial input and final incomplete input keep Source's exact branch and
slot-update order. In particular, final incomplete input clears code point and
counts without clearing the two boundary slots; an invalid continuation clears
both boundaries and leaves that byte for the caller to reprocess.

The UTF8 replacement wrapper lowers the actual `Decoder::decode_to_utf8`
`lib.rs:3985–4031` loop, including original indexed U+FFFD writes. Source's
replacement loop can panic at EOF when a pending sequence is finalized into a
zero-/one-/two-byte destination: the raw EOF arm reports Malformed before a
space check, and replacement writes exceed the destination. The first native
failure at `src/lib.rs:4025` remains in
`source-utf8-decoder-probe-source-eof-panic.log`. This feature preserves the fatal
outcome, including production V bounds checks; it does not convert it into an
author-visible decoding error. Actual owner calls must use Source's maximum
capacity path. Checked capacities model the pinned native 64-bit `usize`; V's
signed-int array allocation bound remains a separate narrower boundary.

The probe first reruns the Source bridge and validated private-helper setup
above. It appends probe-only private slot snapshots and the actual UTF8 variant
reference export to ignored copied modules, leaving every original Source body
intact. Raw calls invoke that actual private decoder; replacement calls invoke
Source's actual `UTF_8.new_decoder_without_bom_handling()` record. Harness-only
`catch_unwind` records 27 genuine fatal calls without fabricating returned
counters. Other observed results provide exact consumed/written counts, malformed
lengths, output bytes, error flags and all five slots. The capacity fixture
contains 60 deduplicated actual observed native states, each queried at eight
small/large 64-bit input lengths; decimal strings preserve large exact values.

Both native debug and release runs pass **11,932 sequences**, **60 observed
states with all three maximum capacities**, and **27 fatal short-EOF calls**.
Their generated artifacts match byte for byte across the two profiles. The
checked-in JSON files add only line breaks between complete native records;
parsed JSON values compare exactly to the generated native artifacts.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/utf8_decoder_sequences.json` | `8ed113ce52351ea206488c905dd7eaef2466e7bc8fb513205f75e734b72fd7b4` |
| `encoding/fixtures/utf8_decoder_capacities.json` | `53a49283dbd79da7fec941df93bd540ddbb2aaadbc4192295ee47c0b3b0ef2ce` |
| `source-utf8-decoder-probe.log` | `50329478344c58da76a7bb02695bc4949bf9c960f481bbe0c9a03b79557a4033` |

The focused V file passes **1/1 default GC, 1/1 GC-none and 1/1 production
GC-none**, including actual compiled-child fatal calls at all three short
capacities. Complete Encoding passes **11/11 in both GC modes**, in
`source-utf8-decoder-full-{default,gc-none}.log`. Initial fixture failures
(`source-utf8-decoder-focused-before-fatal-{output,diagnostic}.log`) preserve the
incorrect diagnostic assumptions; the actual V panic is `array.set: index out
of range` and the source decoder function is on the native stack. A temporary
probe count-assertion placement compile failure is retained in
`source-utf8-decoder-probe-before-count-placement.log`.

This is a private decoder prerequisite. The existing whole-input consumer and
stream boundary buffering have not yet been routed through it. Rust outer
lifecycle/BOM bookkeeping, UTF16 destination conversion, encoder operations,
physical String/Cow/Vec allocation and native SIMD ownership remain outside
this feature. LibJS and the frozen proof checkout are unchanged; no browser
bundle build or capture was run privately.
