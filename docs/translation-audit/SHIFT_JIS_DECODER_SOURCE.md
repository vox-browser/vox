# Selected Shift_JIS Source decoder translation

Upstream is pinned to `963d46a829f3e1b79f44dba9d02afb70654300fa` and its
locked actual `encoding_rs 0.8.40` dependency. Source and the package cache
remain read-only; all generated V assets and probes belong to this repository.

## Original FFI baseline and existing defect

The current Common/Stream compatibility path decodes each Shift_JIS chunk
through iconv without retaining Source's `ShiftJisDecoder.lead` slot
(`shift_jis.rs:18–49`). A GC-none reproduction at private caller feature
`e3218e7a` sends `82`, then `a0`, then an empty flush. Replacement mode emits
U+0082 and U+00A0 separately, while fatal mode throws TypeError on the first
incomplete item. Source instead succeeds without output on `82`, retains the
lead, then emits U+3042 (`e3 81 82`) on `a0` in both error modes.

Tool `e279652bb60ca6fcdf2874df191dde75327e1bb1` verifies this through the genuine
original Source Rust new/decode/free FFI. Native debug/release each pass 1/1
and generate an identical 20-sequence baseline covering split lead, whole
input, incomplete EOF, invalid ASCII trail, NUL, both BOM flags and fatal mode.
The Source bridge invokes byte callbacks only for nonempty output; the initial
probe's assumption that every successful call had a callback failed and was
corrected to record actual callback presence. That probe-only failure is
retained in `source-shift-jis-baseline-before-optional-callback.log`.

- Native `baseline.json` SHA256:
  `6e563ee714612aaab4264560b4b23ff79fbbffdeaef485015abbdaa7c25aa60c`.
- `source-shift-jis-baseline-probe.log`:
  `66f7facebce19fa76e74bcf88dd4c326807586b5e0753281e8bbbb96ff570b13`.
- `source-shift-jis-before-owner-gc-none.log`:
  `6f5808ddd517a62bcd944e7453eb6f88eed3c531885933674de4d5254c2c42a6`.

This is the pre-fix decoder defect. The first prerequisite below does not yet
change its public behavior.

## Exact JIS0208/IBM data and ordered decode helpers

Feature `60664767fd906a67016cc4a7953790601e0ab7f5` copies the six actual Source
literal tables used by the full Shift_JIS decode body. `data.rs:28922–29530`
defines level-one Kanji (2,965 units), level-two/additional Kanji (3,390), IBM
Kanji (360), symbols (240), symbol triples (33) and range triples (54): 7,042
units total. No synthesized mapping or Unicode-library replacement is used.
The Source and WHATWG licenses remain attached to the V table asset.

The separate helpers translate `data.rs:114142–114156` and `:114185–114199`
in their exact triple order. Each tests unsigned pointer-minus-start against
length, then selects the original symbol offset or arithmetic BMP range.
V lowers Source wrapping subtraction to the equivalent closed range for these
small actual ranges on the pinned unsigned 64-bit ABI. It retains None for
unmapped pointers and never falls through to an invented decode mapping.
Shift_JIS's higher-level table priority and decoder state are subsequent work.

Tool `87ddd9ec0b4ef89236f81381db1a57e73eabd582` validates the locked Source
archive/configuration via the preceding actual probe, then adds only table
observation exports and direct calls to the unchanged original helpers in an
ignored copied package. The exact literal arrays are generated only after
native validation. Native debug/release observe all 7,042 original static units
and 11,286 ordered helper cases, covering all pointers through 11,280 plus
five large usize boundary values. Both profiles reproduce identical artifacts.
No Source helper/decoder body or cached package file is modified.

The implementation's focused tests compare every table unit and every native
Some/None result exactly. Default, GC-none and production GC-none each pass
1/1 in `source-jis0208-data-focused-{default,gc-none,production-gc-none}.log`.

- `encoding/jis0208_data.v` SHA256:
  `4c52aaae89b34043e93b510fbfd1a05b8153498c7b233afc8b8480b1ec1287a1`.
- `encoding/fixtures/jis0208_tables.json`:
  `ef8cccc86ecfb6bfa7619226f722d5353958f565b6ed87301bb0b53726bf2934`.
- `encoding/fixtures/jis0208_helpers.json`:
  `cdfe0747f3023d72e32ea1cb0760c7846800bdc047575880ab892ff41a9b6843`.
- `source-jis0208-data-probe.log`:
  `23bb0022880b1402497b447b286279108a5ad4a759ff4a00e1d997fb58919ec0`.

This is a complete data/helper prerequisite, not a completed Shift_JIS decoder.
The raw UTF8/UTF16 variant bodies, actual lead ownership and malformed unread
ordering, outer Converting/Finished lifecycle, original owning bridge and
Common/TextDecoder consumers remain separate required slices. Native public
holders, real TransformStream/controller/realm ownership and physical
allocation/OOM remain explicit. No LibJS implementation or native browser
bundle changed or was built privately.


## Actual raw UTF8 variant and retained normalized lead

Feature `d5b2cc6a2a4be7f2649f9e858cf0c0e4bd5f65de` translates the complete selected
Shift_JIS raw UTF8 decode body (`shift_jis.rs:18–178`) and its exact reachable
`ascii_compatible_two_byte_decoder_function!` expansion (`macros.rs:131–289`).
Its actual optional lead stores the normalized offset, not the original input
byte. Source neutral-state and checked additional/max-capacity methods retain
that slot. V preserves the actual retained-lead prolog before ASCII copying,
three-byte BMP reservation before consuming a trail, EOF lead clearing and
one-byte malformed return, and inner/outer ASCII-copy transition order.

The complete trail lookup retains Source's fast Hiragana/Katakana checks,
then level-one Kanji, level-two/additional Kanji, upper IBM, lower IBM,
EUDC, symbol and range priority. Invalid/unmapped ASCII trails are unread and
return Malformed(1,0), whereas non-ASCII trails stay consumed and return
Malformed(2,0). Standalone 0x80 and half-width Katakana return to the outer
ASCII-copy loop. No mapping or replacement algorithm is invented. Wrapping
range tests are lowered to equivalent closed ranges, independently witnessed
for every two-byte input.

Source ByteSource/Utf8Destination positions are lowered to offsets within
original owning buffers. The existing exact BMP-to-UTF8 writer is reused;
only Source SIMD ASCII copying is flattened to a scalar copy with the same
minimum-length, stop status and space checks. In particular, the retained-lead
prolog's return to ASCII copying stays distinct from the main pair body's
BMP-guarded next read. The raw feature does not add a replacement wrapper or
owning outer lifecycle yet.

Tool `0b0d1542443d279fcd55398902fe05e2edabc118` reuses the validated locked copied
package, exports the actual original constructor and a read-only normalized
lead observer, and directly calls unchanged native raw methods. Debug/release
both compare identical artifacts for ALL 65,536 byte pairs at two capacities,
whole and three retained split calls: 524,288 exact raw records. The records
contain returned status/read/written/malformed/bytes-after, actual lead presence
and value, and only committed output. Unused zero padding is not an output
claim; the fixed 15-byte fixture layout reserves eight payload bytes per record.

The native probe additionally observes three genuinely constructed/held-lead
states for 27 checked-capacity results and 522 zero/short-output/malformed/
ASCII-unread/EOF edge sequences (1,566 calls), using original methods and
actual retained records. Source files are hashed before adding observation
exports. Original package/cache files and all raw/macro/helper bodies stay
unchanged. Debug/release reproduction remains exact for all three artifacts.

Focused V default, GC-none and production GC-none each pass 1/1 in
`source-shift-jis-raw-focused-{default,gc-none,production-gc-none}.log`. Every
native raw record is also exercised at nonzero input/output owner offsets,
including preserved destination prefixes. Tests compare all native maximums,
Some/None boundaries and short-output slot/error ordering. The initial
compilation log retains a test-only invalid mutable integer position argument;
it was changed to a returned fixture offset without changing any native result.

- `shift_jis_raw_pairs.bin` SHA256:
  `4aad41e9d86f198fd75eac200f32bb91b3393f21d75f8ca6defdf5c8b3c311d7`.
- `shift_jis_raw_capacities.json`:
  `972b6a6fd3d6e0789373d00fdfe590d2f374c12a81fbaef372816ceb40f94120`.
- `shift_jis_raw_edges.json`:
  `b88d41cb045e7bf60b9d89972957e3ea190d262042151c1d62f18c3390e29484`.
- `source-shift-jis-raw-probe-complete.log`:
  `4b663484e141f1537a20e400a4395515b0d1aa69ac67f4b392b570647182f385`.

This completes only the logical raw UTF8 destination and its genuine lead
ownership/capacity prerequisite. Raw UTF16, actual outer Converting/Finished
owner and replacement loop, original String bridge and Common/TextDecoder
consumers remain separate. The observed public split-lead defect stays open
until the real consumer is connected. Physical native storage/OOM, public
holder/realm/wrapper/TransformStream ownership and other codecs remain scoped
as above. No LibJS implementation or native browser bundle changed privately.
