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
