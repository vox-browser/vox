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

## Actual selected UTF8 streaming owner and original owning bridge

Feature `2d8143f49440dc92d728cf076b1e62b4b330092f` retains the real selected
`VariantDecoder::ShiftJis` record inside a `Decoder` lifecycle owner. Source
`encoding_rs lib.rs:3764–3783` selects Converting for both Off and Remove
constructors of this non-Unicode encoding. The selected reachable decode arm
is `macros.rs:1311–1312`, with its exact last/InputEmpty transition to Finished
at `:1616–1630`. Malformed and OutputFull retain Converting and the raw lead.
Source maximum queries delegate to the retained variant; Finished misuse
keeps an explicit fatal guard under V production compilation.

The UTF8 replacement loop follows `lib.rs:3992–4031`, retaining the original
source/destination owners and lowering remaining Rust slices to V base
indices. U+FFFD is written in the Source's three separate byte operations.
When a genuine held lead reaches EOF with zero, one or two output bytes,
Source clears the lead, then panics after respectively zero, one or two
replacement bytes. The V guard preserves the same write order and fatal
category. It does not turn Source misuse into a decode error.

The bounded owning UTF8 call follows original Source Rust
`Libraries/LibTextCodec/Rust/src/lib.rs:161–216`: choose the actual fatal or
replacement maximum capacity, perform one raw owner operation, and retain its
success flag and internal partial bytes. Source invokes its byte callback only
for a nonempty output. A failed fatal call can provide partial callback bytes;
the caller must examine success before appending them. The actual Common
caller is the next slice, so this prerequisite does not itself repair public
chunk decoding yet. The raw UTF16 destination remains untranslated here.

Tool `87c58181` first validates the pinned archive/configuration and existing
exact raw data/decoder probes. It includes the unmodified original Source
bridge and links it to the validated ignored copy of encoding_rs, adding only
read-only lead/lifecycle observers. It creates one genuine Box-backed owner
per owning sequence. Source/cache files and original decoder bodies remain
unchanged. Debug and release reproduce the same 1,988 sequences / 5,964 calls,
including 284 owning sequences / 852 genuine FFI calls, all split points of
21 inputs, capacities 0/1/2/3/4/8, both BOM flags, NUL and UTF8/UTF16 byte
prefixes. Eight failed owning calls provide genuine nonempty partial callbacks.

The capacity-limited natural sequences have **zero** native fatal calls:
short output prevents their prefix from consuming the lead. The initial probe
incorrectly expected a panic from those sequences; its failure is retained in
`source-shift-jis-streaming-probe.log` and the diagnostic log. Seven separate
native witnesses first create an actual held lead with enough output space or
finish the actual owner, then directly observe Source short-output and Finished
panics, including the partial replacement bytes and post-panic lead/lifecycle.
The earlier unlinked copied-dependency harness failure is retained in
`source-shift-jis-streaming-before-copied-dependency.log`.

Focused default, GC-none and production GC-none checks each pass 1/1 in
`source-shift-jis-streaming-focused-{default,final-gc-none,production-gc-none}.log`.
They compare every native returned counter, output, normalized lead and
lifecycle; raw outer calls also run against original input/output owners with
nonzero offsets and preserve prefix bytes. Compiled child tests preserve the
fatal boundaries under production compilation.

- `shift_jis_streaming_sequences.json` SHA256:
  `32a7713b96e276bc8ced9a996bc20c2c4ceb8ba113538cdefa524dfa50a112fb`.
- `shift_jis_streaming_fatal.json`:
  `e0f091a64547c429622bbbc4c4662863d4cddc32216b5a5c168ef573bba53eed`.
- Final actual Source probe log:
  `65d071d9a17a7e01189a671da77055cd83ff22ee09abac1eadfca19bf5a745fb`.

Physical Rust String/Vec/Box allocation, C ABI, allocator/OOM and native public
holder ownership are not reproduced by V value flattening. Source's usize
capacity is queried first; V then has a separately named existing signed-int
array allocation limit. Other decoder variants, the raw UTF16 destination,
TextDecoder's direct UTF16 destination and actual TransformStream/controller
ownership remain separate work. No LibJS implementation or native browser
bundle is changed by this feature.

## Actual Common UTF8 consumer and split-lead repair

Feature `b49176d2e4db40916c966c995ab0941bb57845b9` installs the real selected
Shift_JIS streaming owner in the existing Common record. Source
`TextDecoderCommon.cpp:48–51` replaces its OwnPtr with a new StreamingDecoder;
the V setter replaces the actual retained lead/lifecycle and keeps the presence
VERIFY. Source item processing at `:63–67` calls to_utf8 without flushing, and
EndOfQueue at `:69–73` calls finish with an empty input. The consumer uses those
same genuine owning bridge operations. Fatal failure is checked before the
existing output queue is modified, matching `:53–61`. Serialization retains
the existing UTF8-to-string compatibility projection; no invented pending-byte
aggregation or per-chunk iconv call remains on the selected Shift_JIS path.

The focused native-backed test checks 852 Common calls against the exact
original Source owning FFI records and every normalized lead/lifecycle after
each call. It checks 742 typed Stream calls through their first failed
algorithm, all eight withheld nonempty failed callbacks, preservation of a
preexisting output queue, real owner replacement and compiled cold-owner
VERIFY children. The typed Stream still lacks the actual TransformStream
controller/error/Promise graph; tests stop at its first failed callback rather
than inventing a controller state. Default, GC-none and production GC-none
each pass 1/1 in `source-common-shift-jis-focused-*.log`.

The retained before/after probe proves the original split-lead defect is fixed:
`82` succeeds with no output, `a0` emits U+3042 and the empty flush emits no
output, in both fatal and replacement modes. Its after log is
`source-shift-jis-after-common-gc-none.log`. BOM flags retain their actual
non-Unicode Source behavior; UTF8/UTF16-looking byte prefixes do not trigger
Unicode sniffing on this selected owner.

Full Encoding checks run at exactly feature `b49176d2` and pass **29/29 in both
GC modes**. The entire tracked checkout, not only Encoding, remains clean and
byte-identical throughout both parallel sweeps: 4,154 files with whole-manifest
SHA256 `a961d62bf1cbf25ff975d87e5c914b6b708b294b37f766cb0318f7e9cb934936`.
Before/after manifests, HEAD and status are retained under
`Build/audit-fixes/source-common-shift-jis-frozen/`. Independent ignored native
probe preparation only reads original Source methods; no tracked file or
translation dependency is mutated during these checks.

The existing flattened TextDecoder generic path also consumes Common for
Shift_JIS. Source TextDecoder.cpp directly calls to_utf16, so its precise
raw/outer UTF16 destination, maximum-capacity owner and caller remain required
separate slices despite this repaired typed output behavior. This feature does
not claim native TextDecoder holders, branded BufferSource/shared copies,
actual realm/string wrappers, physical allocator/OOM parity or real
TransformStream/controller ownership. Other multibyte labels retain their
previous compatibility adapter. No LibJS code or native browser bundle changes.

## Same raw variant's direct UTF16 destination

Feature `4c22c75ab9c03262298e5dc4a1109303b5a623c3` translates the second actual
expansion of Source's shared Shift_JIS decoder body, `macros.rs:324–340`, using
`Utf16Destination` with the **same** `ShiftJisDecoder.lead` record. Source's
trail/table priority and ASCII unread/malformed ordering remain the actual
`shift_jis.rs:51–172` body already mapped above. Source's destination checks
one available BMP code unit (`handles.rs:590–596`), writes exactly that unit
(`:612–640`) and widens ASCII through its basic-Latin copying loop
(`:660–697`). The V method preserves those checks and direct unit writes.
It does not decode to UTF8 first or construct a second independent lead slot.

The pre-implementation native probe observes the actual missing destination:
a whole `82 a0` can fit U+3042 in one UTF16 output unit, while the UTF8 body
requires its original three-byte BMP handle. This is a missing destination
body/capacity contract; the preceding Common repair already gives the correct
basic typed string and is not presented as a new public value defect.
`source-shift-jis-utf16-raw-before-implementation.log` retains that native run.

Tool `50de2abb` validates the original Source pin/archive/configuration and
prior raw prerequisites, then calls unchanged original raw UTF16 and UTF8
methods on genuine retained records. Debug/release each observe all 65,536
byte pairs with capacities 1/4, whole and three retained split calls: 524,288
exact result/counter/lead/code-unit records. The little-endian binary fixture
stores seven header bytes plus four padded u16 payload units; assertions only
compare the genuinely reported written units. It additionally observes 290
short-output sequences / 870 calls (capacities 0–4) and 232 alternating UTF8 /
UTF16 sequences / 696 calls on the same actual decoder. The original three
state / 27 capacity fixture is reproduced identically and is not duplicated.

Focused default, GC-none and production GC-none each pass 1/1 in
`source-shift-jis-utf16-raw-focused-*.log`. Every native record also executes
with nonzero input/output base offsets on the original V owners and preserves
prefix units. Mixed destination tests compare genuine counters, normalized
lead and native UTF8 bytes or direct UTF16 units after every call.

- `shift_jis_utf16_raw_pairs.bin` SHA256:
  `445a0b517f7f11dd1ae44b5cc4f6a24496679d07161fe67d3eabc1d226372d62`.
- `shift_jis_utf16_raw_edges.json`:
  `d7d0b7c95e23b2620b8bb957557b6af320b80afe82e855cb32081a7c5cbf7563`.
- `shift_jis_raw_mixed_destinations.json`:
  `ffc37a07cdeb4e7d67827e20626ae26382298ed629acd61bd186e4b947841d84`.
- Final actual Source native probe log:
  `c96078691568c300764ee46f58863d379265db835ec9b354274f45b91863173a`.

The outer UTF16 replacement/capacity/lifecycle owner, original owned u16 FFI
bridge and direct TextDecoder caller remain subsequent features. The preceding
29/29 frozen whole-checkout proof predates this slice; its three focused checks
cover this implementation. Raw logical output does not claim Source SIMD
trailing garbage, Rust Vec allocator/OOM or public native owner parity. No
LibJS code or native browser bundle changes.

## Same streaming owner's UTF16 lifecycle and genuine owning u16 bridge

Feature `a5308f3c96cc9ce99e6dc0c8e650c55c15d53c2d` adds the selected direct
UTF16 outer operation to the existing Shift_JIS streaming owner. Both
UTF8/UTF16 methods consume the same real normalized lead and Converting /
Finished lifecycle. Source's shared `public_decode_function!` calls the variant
then finishes only on last/InputEmpty (`macros.rs:1311–1312,1616–1630`). The
UTF16 maximum query delegates directly to that variant for Converting and
keeps the Source Finished panic. No independent decoder lifetime or conversion
of intermediate UTF8 output is introduced.

The replacement loop translates `encoding_rs lib.rs:4357–4400`: aggregate
actual remaining-owner offsets, append one U+FFFD after malformed, and retain
actual returned counters/error flag. A genuine held lead at EOF can produce
malformed with zero output space; the explicit production guard retains the
Source's indexing panic after the lead is cleared. Raw failures do not finish
the owner. The genuine Source Rust u16 bridge (`LibTextCodec/Rust/src/lib.rs`
streaming decode_to_utf16 body) queries its actual maximum, initializes a u16
Vec, chooses fatal/raw or replacement decoding, calls back only for reported
nonempty units and returns the success flag. V preserves these logical units
and failed partial callbacks internally until the caller checks that flag.

Tool `cc3a6047` includes the original Source bridge verbatim after validating
Source pin/archive/configuration and preceding UTF8 probes. Debug/release
produce identical 1,704 UTF16 sequences / 5,112 calls with capacities 0–4,
both actual BOM constructors, all cuts of 21 inputs, raw/replacement/owning
modes and eight failed nonempty u16 callbacks. Four direct native fatal
witnesses cover the zero-unit replacement and Finished query/decode boundaries.
The same tool creates 568 genuine Box-backed original FFI owners with
alternating UTF8/UTF16 calls: 1,704 calls and 16 failed nonempty callbacks.
Actual normalized lead, lifecycle, maximum capacity and callback absence are
observed after each operation; no decoder body is modified in Source/cache.

Default, GC-none and production GC-none each pass the feature's 1/1 focused
check in `source-shift-jis-streaming-utf16-focused-*.log`. All returned raw
counters and owned units match native records exactly. Raw replacement calls
also execute with nonzero offsets on original input/output owners. Mixed
actual destination calls retain one lead/lifecycle, and compiled children
preserve zero-output and Finished fatal boundaries under production.

- `shift_jis_streaming_utf16_sequences.json` SHA256:
  `8568ca2abd085b1340cb3b94c1494db9b389bb5aa9511064431d1e80fabda2d5`.
- `shift_jis_streaming_utf16_fatal.json`:
  `a5aa0f1926eaeaee9e0a03d1796d18cdd84b52ca5f02a84d64fb62e37c028ee8`.
- `shift_jis_mixed_owned_destinations.json`:
  `361eb074f5382e27746afd884708698e797f6e4d25cb298ef8782ace3d37be21`.
- Final actual native probe log:
  `3e1ee8c5afa8da72fdd80ce92b9f2aa960dc09fa4bcba187f195e738ffe35379`.

The V u16 array is a logical lowering of Source Vec/FFI ownership; its signed
int allocation capacity limit is explicit after the Source usize query.
Physical allocation/OOM, original Rust Box/C ABI and native public TextDecoder
holder remain boundaries. The direct TextDecoder caller is the next feature;
Common/Stream retain their actual UTF8 destination. No LibJS implementation or
native browser bundle changes, and the preceding 29-file frozen sweep remains
scoped to its earlier snapshot.
