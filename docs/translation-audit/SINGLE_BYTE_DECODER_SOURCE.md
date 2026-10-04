# Source SingleByte UTF8 decoder mapping

Source is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` and its locked
`encoding_rs 0.8.40` package (archive SHA256
`2a7a45518d2863d18aa47f4a0cf9faec2aa4304cc09df5e41299f276b3ad135e`).
This slice translates its SingleByte UTF8 decoding path. It does not translate
multibyte codecs, the SingleByte UTF16-output path or encoders.

## Table and algorithm ownership

`encoding/single_byte_data.v` copies all 27 exact 128-entry arrays from
`encoding_rs/src/data.rs::SINGLE_BYTE_DATA`. The private decoder table slot
selects the registered Source table. `LibTextCodec/Decoder.cpp:78–104,248–307`
registers IBM866, ISO8859 families, KOI8, Macintosh and Windows families;
ISO-8859-8-I selects the same Hebrew table as ISO-8859-8. The generated lookup
thus covers 28 names with 27 actual tables. Existing standardized-label
conversion still chooses those names; its ordering is unchanged.

`encoding/single_byte_decoder.v` retains the already translated scalar
`SingleByteDecoder::decode_to_utf8_raw` algorithm
(`encoding_rs/src/single_byte.rs:39–159`) and supplies its actual table slot.
The Source `ByteSource`/`Utf8Destination` accounting, ASCII-copy stop result,
inner punctuation phase, three-byte BMP capacity reservation, undefined-entry
`Malformed(1,0)` result and exact BMP UTF8 writes remain in that path. Source
SIMD ASCII acceleration is lowered to the scalar copy with the same bounds and
observable counters. Private table data and positions use the existing
flattened V records; Source's immortal table references and physical Rust
slice/layout types are not separately modeled.

The added replacement loop directly follows
`encoding_rs/src/lib.rs:3985–4031`'s `Decoder::decode_to_utf8`: accumulate raw
read/write counts, return on InputEmpty/OutputFull, record malformed input,
write the exact three U+FFFD bytes, and continue from the accumulated offsets.
Source raw decoding has already reserved those three destination bytes before
reporting malformed input. The V lowering retains base offsets into the actual
owning source/destination arrays. A mutable V slice argument copied the output
in the initial implementation; the corrected offsets preserve Source's writes
into its original destination, including output after a replacement.

The whole-input path uses the Source maximum `3 * byte_length` capacity and
preserves the produced string's explicit byte length. The Source Rust bridge
(`LibTextCodec/Rust/src/lib.rs:81–118`) checks fatal after replacement decoding
and withholds its callback on errors; the V typed TextDecoder boundary reports
its existing decoding TypeError in that case. Undefined table entries now
replace or fail according to that Source path. Leading, interior and trailing
NUL remain output bytes rather than terminating a C-string conversion.

Feature `11c50065dd690b623fd7eb368408fb664c43f69e` includes the implementation,
native golden assets and focused tests. Windows-1252's old private helper now
delegates to this same table/decoder; its original fixture remains as a
regression. Other single-byte codecs no longer enter the truncating iconv
compatibility path. Multibyte codecs still use their prior compatibility
backend and retain its limits; the existing UTF8/UTF16/user-defined paths are
outside this slice.

Source capacity multiplication is checked in `usize`. Flattened V arrays use
signed 32-bit `int` lengths and reject `byte_length > INT_MAX / 3` before
allocation. This narrower V allocation boundary is not Source's exact overflow
or allocation-failure behavior. Source Cow borrowing/Vec allocation, decoder
outer lifecycle/BOM records and physical SIMD ownership are not claimed here.
The supplied primitive byte/label adapters and public owner/binding boundaries
retain their earlier scopes; no new native wrapper or fabricated owner appears.

## Independent Source evidence

Tooling commit `6275d88d0f459000cabedb93c869bb5014315ffe` adds
`tools/source_single_byte_decoder_probe.py`. It requires the exact Source HEAD,
includes the unmodified LibTextCodec Rust bridge, validates the locked archive
checksum and every cached archive file, and runs the actual native decoder.
Its Source table asset copies the validated dependency data after those checks.
The probe passes **2/2 debug and 2/2 release** tests. Its calls establish all
256 input bytes for every name, every individual high-byte fatal outcome,
replacement/fatal behavior, empty output and embedded/trailing NUL, together
with **7,540 raw/replacement capacity, status, consumed, written, malformed,
error-flag and output cases**. Goldens are emitted by Source's actual calls,
independently of V decoding. It does not compile the C++ FileReader owner or
build the V browser bundle.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/single_byte_all-bytes.json` | `93291adcbe61c9acd08a8e18e1ce118e4c3d7c48be2efeb172714c819bd146f7` |
| `encoding/fixtures/single_byte_raw-capacities.json` | `d69738fda2741d23b78ddc0dabf94dcace50a32b9802369126121e26195fabaa` |
| `source-single-byte-decoder-probe.log` | `c5196ea04cba3ecee0e0ff1dcdb8e54208a14a973fe73b37fc2457a287a6410d` |

Focused new table/loop, original Windows1252, streaming TextDecoder and
given-decoder BOM files pass **4/4 in both GC modes** in
`source-single-byte-decoder-focused-{default,gc-none}.log`. The full Encoding
package passes **8/8 in both modes** in
`source-single-byte-decoder-encoding-{default,gc-none}.log`; production GC-none
new/original decoder files pass **2/2** in
`source-single-byte-decoder-production-gc-none.log`. Fixtures compare exact
native outputs/counters, including every undefined entry and retained original
destination writes. The initial output-owner failure log remains in
`source-single-byte-decoder-focused-before-output-owner.log`; no expected
Source data was altered to pass it.

All implementation changes are outside LibJS. The earlier clean frozen LibJS
and exact AST proof checkout remains unchanged and is not a verification claim
for these later Encoding changes.
