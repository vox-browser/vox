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
