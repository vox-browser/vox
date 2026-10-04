# Source UTF8 decoder prerequisites

Source is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` and its locked
`encoding_rs 0.8.40` package (archive SHA256
`2a7a45518d2863d18aa47f4a0cf9faec2aa4304cc09df5e41299f276b3ad135e`).
The existing hand-written `decode_utf8` has concrete malformed-prefix defects:
`E1 41` drops ASCII A after a prematurely classified truncated sequence, and
`E1 80 41` emits an extra replacement. Actual Source Rust bridge calls produce
U+FFFD followed by A for both inputs. These consumer defects were open at
the initial validity-only prerequisite below and are fixed by the separate
whole-input consumer feature recorded later in this document.

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


## Whole-input Source consumer and owning output

Feature `9c256f3c6be6b6b6a0ed440f0548ce44294860dc` replaces the defective
hand-written `decode_utf8` with the UTF8 branch of Source's
`Encoding::decode_without_bom_handling` (`encoding_rs/src/lib.rs:3134–3200`).
`UTF8Decoder::to_utf8` (`LibTextCodec/Decoder.cpp:543–546`) calls
`rust_decode_to_utf8` (`Decoder.cpp:129–147`); the actual Rust bridge
(`Rust/src/lib.rs:81–118`) selects this whole-input operation when BOM handling
is disabled and checks fatal only after the replacement result.

The translated operation validates the initial prefix and returns it directly
when every byte is valid. For malformed input it creates the actual five-slot
decoder, rounds the Source without-replacement capacity to a power of two,
selects the minimum of that capacity and Source's replacement maximum, copies
the valid prefix, and calls the replacement decoder into the remaining owning
output. It accumulates consumed/produced counts and error flags. OutputFull
requests Source's maximum capacity for the remaining input from the produced
string length, retaining pending decoder state before the next call. Source
`decode_to_string`'s spare-capacity writes (`lib.rs:4108–4141`) are lowered to
base offsets into the original output array, preserving earlier prefix and
replacement bytes. Fatal checks then withhold the compatibility return value
on malformed input, matching the bridge's withheld callback.

This fixes `E1 41` and `E1 80 41` to one U+FFFD followed by A, including after a
valid prefix and before embedded NUL. Partial final sequences, invalid second
bytes, supplementary scalars, a literal U+FFFD and repeated malformed input
retain exact Source output and error flags. Existing given-decoder BOM handling
continues to own BOM removal. TextDecoder still uses its existing compatibility
stream-boundary mechanism until the separate actual StreamingDecoder owner
slice; this feature does not claim that mechanism is Source's retained runtime
state or that UTF8 output replaces Source's native UTF16 destination operation.

Rust physical Cow borrowing and String/Vec ABI are not reproduced. The V return
value owns copied bytes; the output array models logical spare capacity and
reserve requests without claiming Rust allocator over-allocation, uninitialized
spare memory or allocation-failure behavior. Source capacity arithmetic uses
64-bit `usize`; the V array rejects capacities exceeding INT_MAX before
allocation. Power-of-two rounding here operates within these bounded supplied
V input lengths; Source's behavior for enormous usize arguments is not claimed.
No public constructor/wrapper or alternate reader cache is added.

Tooling-only `0be2960629105e88aa3a2fe1dd3460404aa52f67` adds
`tools/source_utf8_whole_input_probe.py`. It validates the same exact Source pin,
locked archive and every registry file, then compiles the unmodified actual
LibTextCodec Rust bridge. Both native debug/release filtered tests pass **903
inputs**: every byte, incomplete/malformed multi-byte prefixes, sixteen valid
prefix lengths, twelve repeated-malformed lengths, NUL and astral suffixes.
Actual bridge outputs equal Source's direct whole-input outputs; fatal success
and withheld output equal Source's actual error flag. Debug and release golden
artifacts compare byte for byte. Checked-in record line breaks are formatting
only, and their JSON values equal the native artifact exactly.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/utf8_whole_input.json` | `0d81cb6eb0fd9cd8a3af6bb24e6b3d0d94cfe8e59c6220a8b2067297852e0327` |
| `source-utf8-whole-input-probe.log` | `8f2ac2a49f9a469be10d99137ed74d839a52c8a9a42352156b01f69136b224d8` |

The focused V golden file passes **1/1 default, 1/1 GC-none and 1/1 production
GC-none**; complete Encoding passes **12/12 in both GC modes**, in
`source-utf8-whole-input-{focused-default,focused-gc-none,production-gc-none,full-default,full-gc-none}.log`.
The genuine existing FileReaderSync Text adapter passes **1/1 in both modes**,
including new actual Blob→owned Text→target JSC primitive regressions for both
malformed-prefix cases and final incomplete input. The existing FileReader Text
BOM fixture passes **1/1 GC-none**. Logs are
`source-utf8-whole-input-native-{default,gc-none}.log` and
`source-utf8-whole-input-fileapi-gc-none.log`. The initial native fixture compile
failure from an omitted u16 literal cast is retained in
`source-utf8-whole-input-native-before-u16-cast-{default,gc-none}.log`; no Source
expected output was changed. LibJS, the frozen whole-checkout proof and native
browser bundle remain unchanged.


## Actual UTF8-selected outer streaming owner prerequisite

Feature `6548c0f6e1d22ff41f32202e0717572e8ba62037` translates the Source
UTF8-selected outer Decoder for the actual `BomHandling::Off` and
`BomHandling::Remove` constructors. It owns the existing five-slot UTF8 variant
and Source's reachable lifecycle: AtUtf8Start, SeenUtf8First, SeenUtf8Second,
Converting and Finished (`lib.rs:3565–3587,3763–3784`). This fixed-UTF8
specialization does not accept Source's general BOM-sniffing constructor or
other encoding variants. Encoding pointer/VariantDecoder Rust physical layout
is not reproduced, and foreign UTF16-start/BOM-morphing cases are outside its
typed scope.

`encoding/utf8_streaming_decoder.v` lowers the reachable branches of
`public_decode_function!` (`macros.rs:1292–1631`), including replay of one or two
previous BOM bytes into the actual variant, source-offset accounting, original
destination ownership and the delegate's finalization check. Source's
ConvertingWithPendingBB arm follows a malformed EF in a foreign encoding;
EF BB with last=false cannot be malformed in this actual UTF8 variant, so that
foreign lifecycle is absent from the specialized record. A complete UTF8 BOM
is omitted once; an incomplete or nonmatching prefix is replayed for actual
UTF8 decoding. Source's empty AtUtf8Start input returns InputEmpty without
marking Finished even when last=true. Converting marks Finished only after a
last=true delegate result of InputEmpty; a raw EOF Malformed result leaves
Converting until the replacement loop's subsequent call finishes it.

Both maximum UTF8 capacities follow Source's actual lifecycle arms
(`lib.rs:3806–3978`), including two added bytes for either partial-BOM state and
checked 64-bit usize results. The replacement loop retains exact original
indexed writes. Reusing Finished or replaying previously seen BOM bytes into
an insufficient destination preserves Source's fatal panic messages and order;
these are explicit V panic guards, not production-disabled asserts or public
decoding errors.

The private `decode_owned_utf8` operation translates the actual Rust streaming
bridge's String maximum-capacity owner (`LibTextCodec/Rust/src/lib.rs:164–214`):
query the fatal/nonfatal capacity from the retained outer record, allocate the
bounded output, invoke the actual decoder with the supplied last flag, expose
exact produced bytes before returning its InputEmpty success flag. Fatal raw
Malformed can therefore produce partial callback bytes while returning false;
the existing C++ typed caller subsequently discards those bytes on its error.
This prerequisite returns those two internal outcomes directly and does not
install a new public partially implemented API. Source String/Vec physical
allocation and narrower flattened V INT_MAX capacity limits retain the scope
from the whole-input section.

Tooling-only `dde8e75a031ac717d2fe7cda782c258e575e0f7b` adds
`tools/source_utf8_streaming_decoder_probe.py`. It reruns the validated pinned
Source/helper/raw prerequisite probes, then appends only a probe observation
export for the original native outer record's actual lifecycle. Source's
private Debug value is formatted using the actual no-std package's alloc macro.
All original implementation bytes remain intact. The probe constructs the
actual `UTF_8.new_decoder_with_bom_removal()` or
`new_decoder_without_bom_handling()` records, calls raw/replacement operations,
and invokes actual `decode_to_string`/without-replacement methods using Source's
requested maximum capacities. Only the observation exports and isolated
AArch64 manifest described earlier differ from the copied package.

Native debug and release each pass **5,000 sequences**, **12 actual observed
lifecycle/variant states with eight checked capacity lengths**, and **144
genuine fatal calls**. The sequences cover every two split positions for
thirteen empty/ASCII/NUL/BOM/malformed/astral inputs, Off/Remove, seven raw
capacities, both error modes and actual owned String calls. Explicit
post-conversion-EOF calls establish Finished's fatal boundary. Harness-only
catch_unwind records actual post-panic slots but invents no returned counters.
Both profile artifacts match byte for byte; fixture line breaks are formatting
only and their JSON values equal native output exactly.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/utf8_streaming_sequences.json` | `c1a2b28bf2ec73f103e3b859cf4f1f78920a50bc9d392d003c733cb62a036c52` |
| `encoding/fixtures/utf8_streaming_capacities.json` | `880c9405f827f6ac9e41315998f25ea3ea3b98aafe0d101a06b3358e998686e0` |
| `source-utf8-streaming-probe.log` | `5abc19026158df3b0b11f5cc0f148ec54ac16249b8e82f220648326786751826` |

Focused V tests pass **1/1 default, 1/1 GC-none and 1/1 production GC-none**,
including genuine compiled-child Finished capacity/decode and short-BOM-replay
fatal calls. Complete Encoding passes **13/13 in both modes**, in
`source-utf8-streaming-{focused-default,focused-gc-none,production-gc-none,full-default,full-gc-none}.log`.
Initial tooling no-std format-macro and V conditional-option syntax failures
remain in `source-utf8-streaming-probe-before-alloc-macro.log` and
`source-utf8-streaming-before-option-guard.log`.

The record is still a private prerequisite. Actual TextDecoderCommon ownership
and public stream hookup, UTF16 destination operations, other selected codecs,
general BOM sniffing/morphing and genuine TransformStream/realm/binding graphs
remain separate. The existing compatibility pending-input/chunks path is not
claimed as those Source owners. LibJS and the frozen proof checkout are
unchanged; no native browser bundle build or capture was run.


## Retained UTF8 Common consumer

Feature `7915051dca6ed4d571c9bc77e0d51c200552097f` installs the proven actual
UTF8-selected streaming decoder into the existing V TextDecoderCommon object.
Source `TextDecoderCommon.h:50–89` owns a mutable
OwnPtr<TextCodec::StreamingDecoder>; its setter (`TextDecoderCommon.cpp:51–54`)
constructs that owner from encoding, ignore-BOM and error-mode fields. The two
Source process forms (`Common.cpp:67–77`) call `to_utf8(item)` with last=false
or `finish()` with empty input and last=true, then append only successful output
to the existing queue. `TextDecoderStream.cpp:160–211` uses those forms for
chunks and flush. The existing output queue keeps single output/builder storage
and Source's later UTF8-to-UTF16 serialization boundary.

The V Common embeds the actual selected decoder record directly and represents
the Source OwnPtr's null/VERIFY boundary with a private presence flag. It mutates
that retained record in place, instead of copying an unwrapped optional value
or allocating a separate unmanaged heap owner. This is a flattened owning-field
representation, not the physical OwnPtr/Rust Box ABI. The real TextDecoder
constructor now invokes the same Source setter as the existing stream
constructor. UTF8 item processing uses the actual per-call maximum-capacity
owner with the supplied last flag; its private Source BOM/lifecycle/five-slot
state persists across calls. UTF8 no longer feeds the old pending-input/bom-seen
compatibility fields or prematurely decodes a chosen boundary as a complete
stream. Failed fatal bridge output is withheld from the Common output queue,
matching `append_decoded_output` (`Common.cpp:57–65`).

The bounded public model entry points for UTF8 streams now reach that actual
owner, including split UTF8 BOMs, preserved BOMs, incomplete scalar prefixes,
invalid-continuation reprocessing, NUL and real empty-input flush. This is not
new JavaScript interface exposure. Other encoding labels keep their prior
adapter paths. The public stream model's primitive-byte input and observable
chunks array retain the earlier compatibility boundary: Source's actual
AllowSharedBufferSource conversion, TransformStream/controller/realm/Promise
and native interface wrappers are not implemented by this slice.

Source TextDecoder.decode instead calls the same owner's native UTF16
destination (`TextDecoder.cpp:71–96`); the V TextDecoder still projects its
flattened public strings through the UTF8 destination. UTF16 capacity, native
buffer ownership and destination behavior are explicitly not inferred from
UTF8 goldens. Its separate Source non-streaming reset-before-error correction
remains pending at this feature. The combined typed input/end-of-queue adapter
remains that public TextDecoder compatibility path; the source-faithful Common
stream calls use item/no-flush and empty-input/end-of-queue.

The new fixture compares **1,876 actual native owned calls** from the earlier
5000-sequence golden through the Common queue, fatal-output withholding and all
retained lifecycle/variant slots. It also verifies actual stream constructors,
split BOM/scalar state in the Common field, no use of old UTF8 pending bytes,
flush-to-Finished and a genuine compiled-child Source VERIFY failure before
owner initialization. Focused checks pass **1/1 default, 1/1 GC-none and 1/1
production GC-none** in
`source-text-decoder-common-utf8-{focused-default,focused-gc-none,production-gc-none}.log`.
The implementation passes complete Encoding **14/14 in both GC modes** in
`source-text-decoder-common-utf8-full-{default,gc-none}.log`; after that sweep,
only the focused test was strengthened with its exact count and cold-owner
fatal case, and all three focused checks were rerun. The genuine native Sync
Text fixture passes **1/1 GC-none** in
`source-text-decoder-common-utf8-native-gc-none.log`. Initial test compilation
failures caused by cross-test-only DTO references are retained in
`source-text-decoder-common-utf8-before-fixture-dto-*.log`; the corrected focused
file declares its own native JSON observation DTOs. No expected Source result
was changed. LibJS and native browser bundle/captures are unchanged.


## TextDecoder non-streaming reset before errors

Feature `140699036a3d62474347cc3b64a6dccec2f2fe8d` fixes the existing
TextDecoder model's non-streaming reset order. At the pinned Source revision
`963d46a829f3e1b79f44dba9d02afb70654300fa`, `TextDecoder.cpp:87–96` keeps the
owner for streaming calls, but saves the result of a non-streaming
`to_utf16(..., Flush::Yes)` call, invokes the Common setter and only then maps
the saved result to output or an exception. This ordering applies to failed
decoding too. The V model previously returned directly on a decoding error,
leaving its actual UTF8-selected owner and BOM/variant slots in their old state.
It now invokes the existing Source setter before returning that error; successful
non-streaming calls also reset before queue serialization. Streaming errors
continue to retain the owner. The existing decoding-error message is preserved.

The focused pre-fix regression demonstrates the actual retained ED-prefix
upper boundary `0x9f` instead of the fresh owner's `0xbf`, in
`source-text-decoder-reset-before-feature-gc-none-regression.log`. Earlier
fixture compilation failures caused by selecting a nonexistent Utf16String
factory are retained separately in the two `before-feature` logs; the corrected
fixture uses the existing public `utf16_string_from_utf8_without_validation`
projection on the decoder's valid UTF8 result. No LibJS implementation changed.

Tool `eb77527501ff86ab69a493003ccbd81ea76567f6` invokes the actual pinned
Rust `textcodec_rust_streaming_decoder_new`,
`textcodec_rust_streaming_decoder_decode_to_utf16` and free functions, with real
Box-backed decoder records. Source's C++ wrapper passes its flush flag through
`StreamingDecoder::to_utf16` (`LibTextCodec/Decoder.cpp:523–526`); the Rust FFI
uses the real UTF16 maximum-capacity owner, u16 destination and fatal/replacement
paths (`Rust/src/lib.rs:218–262`). The probe creates a fresh actual owner before
freeing the old one after each non-streaming attempt, mapping the reviewed C++
setter order without claiming that its VM/GC class was compiled by this probe.
It verifies 16 real-owner scenarios, 64 observed calls and eight fatal failures,
covering retained partial 2/3/4-byte prefixes, ED's restricted continuation
boundary, remove/preserve BOM, NUL and astral output. Two additional native
retained-versus-fresh witnesses verify that a failed owner retains a consumed
BOM while a fresh owner applies its configured BOM handling.

Actual native debug and release checks pass 1/1 each and compare their artifact
bytes exactly. The checked-in fixture has the same JSON values, with only
per-record line breaks added. The tool reuses the existing validated Source
pin, Cargo.lock/archive checks and actual original Rust bridge, with the earlier
isolated AArch64 default-alloc validity-probe configuration documented above.
No upstream or package-cache file was modified.

| Artifact | SHA256 |
| --- | --- |
| Native `utf16_reset.json` | `58154ba4eab312b1fc61cbe20e26ae765567496bca48871137ccb70d7e023c81` |
| `encoding/fixtures/text_decoder_utf16_reset.json` | `79df1ea735f95f8dbc5ec79d36514ebdf5e18d1849bd97d1a32daacc7f9188a7` |
| `source-text-decoder-utf16-reset-final-probe.log` | `260083935755eff9e412532b098699d43797735381b7033e1f6e0c771617e2a9` |

The fixture compares the V public result's logical UTF16 units with those
native UTF16 observations, and verifies fresh lifecycle/five-slot state after
every non-streaming result or error. Its second test verifies owner retention
after a streaming error, followed by explicit flush/reset and fresh BOM handling.
Focused checks pass 1/1 in both GC modes in
`source-text-decoder-reset-focused-{default,gc-none}.log`; complete Encoding
passes 15/15 in both modes in
`source-text-decoder-reset-full-{default,gc-none}.log`.

This is the actual reset-order correction through the model's existing typed
input/string boundary. V TextDecoder still uses the proven UTF8 destination;
the native UTF16 witnesses establish returned logical units and retained/reset
behavior for these cases, not V UTF16 destination capacity, physical buffer
ownership or general UTF16/multibyte codec parity. Actual native
AllowSharedBufferSource conversion, engine allocation/OOM mapping and public
TextDecoder/TransformStream wrappers remain separate dependencies. No native
browser bundle build or capture was run privately.


## Raw UTF16 destination of the retained UTF8 variant

Feature `0a8802ca16ec3d115d591a42058d5afbeaccdc89` adds the actual UTF8
variant's raw UTF16 destination to the same five-slot SourceUtf8Decoder record.
The new prefix helper translates
`encoding_rs-0.8.40/src/utf_8.rs:334–549`:
`convert_utf8_to_utf16_up_to_invalid` copies an ASCII prefix, validates complete
2/3/4-byte sequences with the existing exact Source mask table and stops before
invalid, incomplete or non-fitting input. Its output positions count UTF16
code units. The full lookahead requires two output units for an astral value;
BMP prefix values fit in one. The shorter tail excludes four-byte leads and
returns immediately after its final complete three-byte value. Source's
manually inlined next-lead continuations return to the same outer iteration
here, preserving the exact masks, bounds, written units and stopping positions.

The raw method expands the existing `decoder_functions!` five-slot body
(`utf_8.rs:611–708`, `macros.rs:10–122`) with `Utf16Destination`.
`copy_utf8_up_to_invalid_from` (`handles.rs:737–744`) invokes the prefix helper
only in neutral state. The subsequent Source macro checks input availability
before its two-unit astral destination check (`handles.rs:598–605`), then
consumes a byte. It preserves malformed lengths, invalid-continuation unread,
the exact lower/upper-bound updates and pending EOF slot clearing without
resetting those bounds. Source destination writes emit ASCII/BMP units or the
actual surrogate-pair formulas (`handles.rs:616–639`). Base offsets lower
remaining slices into the original input and mutable output owners; V's mutable
slice-copy behavior does not supply substitute destination storage.

The separate UTF16 replacement loop translates `lib.rs:4355–4400` over that
raw variant, appending one `0xfffd` unit after every malformed return and
accumulating counters. As with the UTF8 destination, pending malformed EOF is
checked before output space. The actual Source indexed replacement therefore
panics on a zero-capacity destination; V preserves that fatal write boundary.
It does not convert this condition into an author-visible decoding error.

Tool `4f3245fd76751965c9870264f462dfc36d5b5472` validates the pinned Source
checkout and locked archive using the existing probe workflow. It appends only
snapshot/helper exports in an ignored copied package and calls the actual
prefix function and actual raw/replacement decoders. Original implementation
bodies, upstream and package-cache files remain unchanged. Native debug and
release produce byte-identical artifacts for all 65,536 byte pairs at both
one- and two-unit capacities, 3,024 longer prefix cases and 11,932 raw/replacement
sequences. These include every byte at multiple capacities, retained partial
prefixes, restricted continuations, invalid-byte reprocessing, NUL, BOM bytes
and astral pairs. Nine native zero-capacity EOF calls panic; their actual
post-panic slots are recorded without inventing return counters.

The binary pair fixture records, in ascending first/second byte order and then
capacities one/two, the returned u8 read/written counters followed by that
capacity's little-endian u16 units. Only committed units are observed; remaining
slots are zero placeholders in the fixture. It contains 655,360 bytes. The JSON
fixtures retain the exact native values, with per-record line breaks added.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/utf8_utf16_prefix_pairs.bin` | `8f1c27d377305b26bc71ebdc79c29400846b94e66f69fee549b15ecd59b54be2` |
| `encoding/fixtures/utf8_utf16_prefix_edges.json` | `04833671347607447559d2b3b1fd269cb64fdc1dc73354b14f1ec9f1c2b08e5b` |
| `encoding/fixtures/utf8_utf16_decoder_sequences.json` | `36446b59b6718a9d977c336a9e612c946967483c3cc31e08ce188818fa798a30` |
| `source-utf8-utf16-decoder-probe.log` | `1cb1f7af9883762d0a9a25b6c142c38f06a3ab5b5cc96f5839c88ada0a728f2f` |

Focused V checks pass 1/1 in both GC modes. The final fixture also verifies
explicit input/output positions against all longer native prefix cases and
preserves the original destination's leading guard units. Complete Encoding
passes 16/16 in both modes, and the final focused production GC-none check
passes 1/1, including the genuine compiled-child fatal replacement write.
Evidence is retained in
`source-utf8-utf16-decoder-{focused-default,focused-gc-none,full-default,full-gc-none,production-gc-none}.log`.

This establishes the variant's logical UTF16 destination. ASCII acceleration
is represented by Source's scalar prefix writes; uncommitted SIMD slack writes,
native alignment and physical slice/Vec allocation are not claimed. V array
lengths remain int-sized, while capacity arithmetic retains the prior checked
64-bit Source model. The actual Off/Remove outer UTF16 lifecycle expansion,
maximum-capacity Rust bridge owner and Source TextDecoder UTF16 caller remain
subsequent features. Other selected codec variants and BOM morphing remain
separate. LibJS and native browser bundle/captures are unchanged.


## Outer UTF16 destination and owning bridge buffer

Feature `0f6be173ae533f830c49469e882ee486eccc0e66` translates the UTF16
destination of the existing actual UTF8-selected outer decoder. It adds
methods to that same SourceUtf8StreamingDecoder and mutates the same lifecycle
and five-slot variant already used by Common's UTF8 destination. The
`public_decode_function!` expansion (`macros.rs:1292–1631`) retains the reachable
Off/Remove constructor arms: AtUtf8Start, SeenUtf8First, SeenUtf8Second,
Converting and Finished. Potential BOM bytes are either consumed as a complete
BOM or replayed through the actual raw UTF16 variant with Source's offset and
write-counter ordering. Replay with fewer than two output units preserves the
Source fatal condition. Only last=true plus InputEmpty marks a converting owner
Finished; empty input at AtUtf8Start keeps Source's existing early-return state.
Finished capacity/decode/owning calls fail fatally. The foreign-codec pending-BB
arm remains unreachable for this actual selected variant, as in the UTF8 slice.

`max_utf16_buffer_length` translates `lib.rs:4276–4350` for those actual
constructors. Converting/AtUtf8Start delegate to the retained variant; partial
BOM states perform checked `byte_length + 2`, then checked `+ 1`. The Source
result applies to fatal and replacement output alike. The UTF16 replacement
loop retains `lib.rs:4355–4400` and its actual indexed one-unit replacement write.
The owning method follows the original Rust bridge (`Rust/src/lib.rs:218–262`):
query that retained owner's maximum, allocate its u16 destination, decode with
the actual last/fatal flags and retain produced callback units before returning
the success bool. A failed call may produce partial callback units; the C++
typed caller (`Decoder.cpp:149–162`) subsequently withholds its failed result.
This prerequisite exposes those internal callback units only to its private
translated caller, not as a new author-visible result.

Tool `02b128327db3eb71fec40d5b7170a1a52a8f9f2d` invokes actual Source outer
decoders and, for owning modes, includes the original Rust bridge verbatim and
calls its original new/decode/free functions on genuine Box records. Snapshot
exports observe the actual Box's retained Decoder; no synthetic owner or FFI
read/status counters are supplied. Debug and release each pass 2/2 native tests
and compare all output artifacts byte exactly: 5,000 sequences, 12 actual
lifecycle/variant capacity states at ten checked lengths, 76 direct native
fatal calls, and 16 additional failed calls with nonempty partial callbacks.
The owning sequences include 1,876 observed successful/failed FFI calls.
The extra cases prepend ASCII, NUL or BOM before malformed input and vary
Off/Remove and flush/no-flush, proving the callback-before-false behavior that
the initial split vectors did not exercise.

The probe retains the validated original dependency bodies and Source pin.
Its isolated bridge test crate selects the already validated copied
default-alloc AArch64 dependency through a path dependency, with explicit
workspace exclusion for that dependency's own isolated workspace. The original
bridge is compiled under its normal native test configuration, including
Source's test allocator/panic setup; its production allocator/abort ABI and
physical Box/Vec layout are not inferred from the V arrays. Direct Source
decoder/max-capacity panics are caught only by the harness to record absence
of return data. Initial workspace-root and callback-type inference failures
are retained in `source-utf8-utf16-streaming-probe.log` and
`source-utf8-utf16-streaming-partial-callback-probe.log`.

| Artifact | SHA256 |
| --- | --- |
| `encoding/fixtures/utf8_utf16_streaming_sequences.json` | `85b8668b0792660827cdb55dc18b73fe8174460db0c3556520af4bba1f42a6e0` |
| `encoding/fixtures/utf8_utf16_streaming_capacities.json` | `ab64a8ce9eaa488b49578cac0bfac43edde60282ac410518e36d9413abbc6184` |
| `encoding/fixtures/utf8_utf16_partial_callbacks.json` | `01961169596d6ca6a5c4f663c0ff63d67ae50deffecea6c234cba6ad7ad30ba2` |
| `source-utf8-utf16-streaming-final-partial-probe.log` | `1386dceb56462d2bfd5bbbc3fcdc4df64d02af9338bb45082b3c281f081eb4fe` |

Focused V checks pass 1/1 in both GC modes. After the partial-callback fixture
was added, final complete Encoding passes 17/17 in both modes and final
focused production GC-none passes 1/1 in
`source-utf8-utf16-streaming-final-{full-default,full-gc-none,production-gc-none}.log`.
The actual compiled children cover zero/one-unit BOM replay failures and
Finished decode, capacity and owning calls. Existing raw UTF16 tests separately
retain the zero-capacity malformed-EOF replacement fatal write. Both destinations
keep their actual shared retained slots. No expected Source output was changed.

The owner is a logical translation of the Source UTF8-selected UTF16 path.
V's narrower int array capacity has an explicit separate guard; a failed Source
checked-usize maximum query still returns failure. Native allocation/OOM,
physical Box/Vec buffers, SIMD slack and other selected codec variants remain
bounded as described above. TextDecoder's Source UTF16 caller is the next
separate consumer feature; Common/Stream continue to use their existing Source
UTF8 destination. LibJS and native browser bundle/captures are unchanged.


## TextDecoder's actual UTF16 owner caller

Feature `6abe845ec9beaa6377b13a8272f3cd07074ace26` connects the UTF8-selected
branch of the existing TextDecoder.decode model to the proven actual retained
UTF16 destination. Source `TextDecoder.cpp:71–96` calls the retained
StreamingDecoder's `to_utf16`, passing Flush::Yes only for non-streaming calls.
Its C++ bridge (`LibTextCodec/Decoder.cpp:149–162,523–526`) builds an owned UTF16
result from the real callback units and withholds that result if decoding fails.
The V caller now invokes the same logical owning path with the exact last/fatal
flags, saves its units/success, resets a non-streaming owner before examining
that saved result, and returns the existing decoding error on failure. Produced
fatal callback units remain internal. A streaming call retains the actual
lifecycle/variant slots, including after a decoding error.

Successful output constructs the existing genuine Utf16String unit-owner
record using `libjs.utf16_string_from_code_units`. Its `.str()` projection retains
the model's previous public string return. The validated UTF8 decoder only
emits well-formed UTF16 units here, so this projection requires no new
replacement policy, representation rule or LibJS implementation change.
TextDecoder no longer decodes through the Common UTF8 output queue for this
selected encoding. Common/Stream continue to call their Source UTF8 destination,
and the other-label adapter remains separate. The existing presence/owner guard
is preserved before touching the retained decoder.

The new focused test compares all 1,876 observed native owning calls from the
actual original-FFI UTF16 golden through the existing TextDecoder entry point,
including BOM splits, incomplete scalar prefixes, NUL, astral units, successful
flushes and fatal errors. It checks the actual retained slots for streaming
calls and the Source fresh owner for every non-streaming result or error.
Deliberate post-Finished native decoder calls are excluded from the public
caller comparison: Source TextDecoder replaces that owner before returning.
All 16 genuine failed nonempty partial-callback cases throw the existing error
without returning their units; subsequent calls verify the already witnessed
fresh/retained BOM distinction. A genuine compiled child verifies that the
missing-owner guard remains fatal in production.

Focused checks pass 1/1 default, 1/1 GC-none and 1/1 production GC-none in
`source-text-decoder-utf16-owner-{focused-default,focused-gc-none,production-gc-none}.log`.
Complete Encoding passes 18/18 in both modes in
`source-text-decoder-utf16-owner-full-{default,gc-none}.log`, with the tracked
implementation/tests unchanged during those sweeps. The genuine native Sync
Text regression passes 1/1 GC-none in
`source-text-decoder-utf16-owner-native-sync-text-gc-none.log`. No expected
native Source value was changed.

This closes the selected UTF8 TextDecoder UTF16 destination/caller gap described
in the earlier prerequisite sections. The public input and returned-string
projections are still typed model boundaries, not native JavaScript interface
exposure. Actual BufferSource copying/detachment conversion, Source engine
allocation/OOM exceptions, physical C++ builder/Box/Vec representation, native
TextDecoder wrappers and other codec owners remain explicit dependencies.
The existing Utf16String code is unchanged; no additional LibJS code was
introduced. No native browser bundle build or capture was run privately.

## UTF16 variant and raw UTF16 destination

The next concrete mismatch is independently witnessed through the original
Source Rust streaming-to-UTF16 FFI: UTF16LE `00 d8 00`, or UTF16BE `d8 00 00`,
retains a high surrogate and one trailing byte until EOF, reports one
`Malformed(3,0)` sequence and emits one U+FFFD in replacement mode. Before this
translation, the existing TextDecoder model returns two replacement units for
both byte orders. `source-utf16-eof-both-before-owner-gc-none.log` retains that
failing comparison. The original-FFI native probe passes debug/release for
32 scenarios and 64 calls, covering each split, Off/Remove and fatal/replacement
mode. Fatal calls fail without a produced callback result. Its native log is
`source-utf16-eof-probe.log` (SHA256
`adb3269c1d1bfbdc678fc544cb2c1c6962a35d6fa0b6f2aa5f613c8c6b24ebfc`).

Feature `6007017086b8978da0a53ac8d7cc1fbf5e44ddfe` translates the actual four slots
from encoding_rs `utf_16.rs:14–197`: retained surrogate, optional lead byte,
endianness and pending-BMP flag. The raw UTF16 destination expands the actual
`decoder_functions!` control order, including the pending-BMP preamble, two-unit
astral check before body byte consumption, EOF BMP-space check before retained
slots are cleared, exact malformed lengths/bytes-after and the Source EOF Full
arm's literal zero counters. Consecutive high surrogates retain the second one;
a BMP after a high surrogate remains in the actual pending-BMP slot.

`handles.rs:746–804` supplies the fast prefix's exact input/output minimum,
last-high-surrogate exclusion, speculative first-surrogate write, paired-low
check and committed positions. Unaligned code-unit loads and the Endian swap
are lowered to explicit byte reads on the original input owner; the ordinary
scalar `copy_bmp_to` body at `handles.rs:182–194` supplies the copy loop. SIMD
acceleration and its uncommitted slack writes are not represented as a physical
ABI guarantee. Original-owner base offsets preserve Source remaining slices
without V's mutable-slice storage copy. Source checked 64-bit usize capacities
are translated independently; V int-array allocation remains a narrower owner
boundary. The replacement loop follows Source Decoder's indexed U+FFFD write.
The UTF8 destination is deliberately absent from this bounded variant feature.

Tooling commit `cf133f1123424da9de83711c6aa4e534ef8758be` contains the native EOF,
existing-model reproduction and raw-slot probes. It enforces Source HEAD
`963d46a829f3e1b79f44dba9d02afb70654300fa`, validates all registry implementation
files against the exact Cargo.lock archive checksum, and appends only genuine
constructor/snapshot exports to an ignored dependency copy. Decoder/destination
implementation bodies stay unchanged. The existing helper harness's isolated
AArch64 default-alloc manifest and locked dependencies are retained; this uses
normal Cargo test allocation/panic behavior rather than the production C ABI's
physical allocator/Box layout. The reused UTF8 validator/bridge checks also run
before the UTF16 driver; they do not substitute for the UTF16 observations.

Actual native debug and release produce identical artifacts: 262,144 exhaustive
unit/capacity records (all 65,536 units in both byte orders, capacities 1/2),
15,248 raw/replacement retained sequences and 14 checked-capacity states. The
binary record excludes uncommitted output slots and fixes their bytes to zero;
JSON includes genuine returned counters, output and all four actual slots.
Their SHA256 values are:

- `utf16_raw_units.bin`: `91a06ee524347865a719de11021d9f611849bebbb77f689798f2e72323fd32ec`.
- `utf16_raw_sequences.json`: `be0b000b810bb5186286f537b588c499c271d38d00584cade40e0a8a160725e2`.
- `utf16_raw_capacities.json`: `87ab7b5b709596b3e0023a0367fcdc9727c264ab0f6eb928718da5379448b690`.

The final native log `source-utf16-decoder-probe-final.log` hashes to
`c12d0520ee2aa825b2151ec6e3b5ed996621e2ac06b49a239a81105c5120610c`.
Focused V tests pass 1/1 default, GC-none and production GC-none in
`source-utf16-raw-focused-final-{default,gc-none,production-gc-none}.log`.
They compare every native observation and repeat retained sequence calls with
guarded original-owner offsets. An initial test launch before fixture copying
failed only to open the three fixture files; that log is retained separately.

The existing public TextDecoder UTF16-selected branch has not yet been changed
by this prerequisite. The native EOF mismatch therefore remains visible there
until the actual outer Off/Remove owning lifecycle and caller are translated.
Common/Stream's UTF8 destination, generic whole-input UTF16-to-UTF8 wrappers,
other codec families, native WebIDL wrappers and Source physical allocation/OOM
behavior remain separate work. No LibJS implementation or native bundle was
changed or built privately.

## UTF16 owning Off/Remove lifecycle and original FFI output

Feature `2d3b444ab8fdb76f14ff2e1db84ae87b205fa02d` owns the proven UTF16 variant
inside the actual selected Decoder lifecycle. It translates Source's Off/Remove
constructor states and the reachable UTF16 arms of `public_decode_function!`
(`macros.rs:1292–1631`), together with the actual UTF16 maximum-capacity query
(`lib.rs:4276–4350`) and original streaming bridge (`Rust/src/lib.rs:218–262`).
The retained BE/LE start and seen-first-BOM states select only their matching
fixed encoding. Opposite BOMs are ordinary code units; general BOM-sniffing
morphs and foreign encoding variants are unreachable through these constructors.
An empty start returns InputEmpty before the Finished transition, as Source does.

A rejected split BOM replays its original first byte into the actual variant;
Source's zero/one-unit replay output buffers remain fatal. Matching BOM offsets
count consumed bytes correctly. The actual raw variant retains odd bytes,
surrogates and pending BMP across calls; Finished occurs only after a last raw
InputEmpty result. Replacement repeatedly delegates through that owning
lifecycle. Its maximum-capacity u16 owner returns actual internal callback units
and success, including produced partial units on fatal failure. The C++ caller's
failure withholding remains separate. V int-array allocation is explicitly
narrower than Source checked usize capacity, and physical Vec/Box/C++ builder
representation and OOM remain distinct boundaries.

Tool `c0637ce9ae1c8098cdaeea9285edb0a2e51c699b` includes the original read-only
Source Rust bridge verbatim and uses genuine new/decode/free Box-backed records
for owned modes. It reuses the validated raw prerequisite dependency copy with
only a lifecycle observation export added. Its temporary parent workspace
explicitly excludes that dependency's isolated workspace and retains the same
locked Source AArch64 default-alloc package configuration. Raw modes observe
real returned counters; FFI modes record only the genuine max capacity, success,
callback units and actual retained slots. No discarded FFI counter is fabricated.

Actual debug/release both pass 2/2 and produce byte-identical artifacts:
13,840 split-input sequences, 28 distinct checked-capacity states and 32 native
fatal calls. The sequence fixture includes 5,192 genuine nonpanic owning FFI
calls. A separate fixture observes 32 actual nonempty fatal callback results
before the bridge returns false. Source body/EOF malformed lengths, replay,
NUL, paired/unpaired/consecutive surrogates, matching/opposite/repeated BOMs and
all capacities from zero through 32 are included. Fixture SHA256 values are:

- `utf16_streaming_sequences.json`: `7cf8f3d07fadd4fb9528ff53076587b6eeb5c5362e775f93cfc8837082cd36fa`.
- `utf16_streaming_capacities.json`: `48c172d4b6a9a47b1fdad43a9ecd2b244f83f7901fff31e6f4f2f05ad84beee1`.
- `utf16_partial_callbacks.json`: `6b3e68a50b0c459935a0c69b54245528ee89fcf7a0f97318053d17456f33b5eb`.

The final native log `source-utf16-streaming-probe-final.log` hashes to
`3500c15c4757a1f5bd7ca54d521b58d48939ac0ab6d4d4cf0c4a5888abc3f71e`.
Focused V checks pass 1/1 in default, GC-none and production GC-none in
`source-utf16-streaming-focused-final-{default,gc-none,production-gc-none}.log`.
Every nonfatal native observation is compared exactly; ten compiled children
exercise BE/LE zero/one-unit BOM replay and Finished capacity/decode/owning calls.
Initial focused compilation exposed a test helper isolated in another `_test.v`
file; the fixture now owns its own slot assertion helper, with those initial
logs retained. No native expected value was changed.

The public TextDecoder caller remains unchanged in this prerequisite. Source
Common/Stream's UTF8 destination and generic whole-input UTF16-to-UTF8 wrappers
still require their actual destination bodies; this owner does not replace them
with a conversion workaround. Native public interfaces, BufferSource conversion
and other codecs remain explicit. No LibJS implementation or native bundle
was changed or built privately.

## TextDecoder UTF16-selected actual owner caller

Feature `f8a77f36e362a9a8ea41b76084e62331a5519d04` connects UTF16LE/BE branches of
the existing TextDecoder to the proven real UTF16 destination. The selected
variant belongs to the Source Common record's owning StreamingDecoder
(`TextDecoderCommon.cpp:61–65`), with the existing OwnPtr presence/VERIFY boundary
retained. `TextDecoder.cpp:71–96` calls that owner's `to_utf16`, retaining its
four variant slots and BOM lifecycle for streaming calls. A non-streaming call
saves the result, resets the configured owner, then exposes success or the
existing TypeError. The caller follows that exact order, withholding every
fatal partial callback result.

Successful units construct the existing genuine Utf16String unit-owner and
use its existing `.str()` compatibility projection. Actual decoded output is
well-formed UTF16: paired surrogates are emitted together and malformed input
is replaced or withheld. This adds no Unicode representation or replacement
policy. LibJS implementation code is unchanged. Public BufferSource input and
returned model strings remain typed compatibility boundaries; native interface
exposure, actual engine allocation/OOM and physical C++/Box/Vec ownership are
not claimed by this caller.

Focused tests compare all 5,192 real owning FFI calls in the prior sequence
fixture through this existing entry point, excluding deliberate internal
post-Finished misuse that Source TextDecoder prevents by resetting. They check
actual retained BE/LE slots and fresh reset owners on every streaming/flushed
success or error. All 32 genuine failed nonempty callback cases throw without
returning their units. The original-FFI EOF fixture covers 32 cases/64 calls
across both byte orders, every split, BOM setting and fatal option; both
three-byte input cases now return one U+FFFD. Reuse after fatal EOF and absent
input are checked, and two compiled child calls preserve the production
missing-owner fatal guard. `utf16_eof.json` SHA256 is
`1cbebd070be955f3402eaca4e85d515b877f52be28fe035fb877baab01443365`.

Focused checks pass 1/1 default, GC-none and production GC-none in
`source-text-decoder-utf16-variant-focused-{default,gc-none,production-gc-none}.log`.
The original model reproduction now passes for both byte orders in
`source-utf16-eof-after-owner-gc-none.log`; the original failing logs are retained.
The genuine native Sync Text check passes 1/1 GC-none at the clean caller snapshot
in `source-text-decoder-utf16-variant-native-sync-text-gc-none.log`.

Initial full sweeps at caller snapshot f8a77f36 passed 20/21 in both modes and
identified the old BOM-override fixture described below. After its independently
witnessed correction, complete Encoding passes **21/21 in both modes** at clean
snapshot `de622687b564885d7c3dd41c2324d64c490b794f`; tracked files remained
unchanged throughout those sweeps. Final logs are
`source-text-decoder-utf16-variant-final-full-{default,gc-none}.log`.

Common/Stream still require the same actual variant's Source UTF8 destination;
this caller does not convert its UTF16 output to substitute for those owners.
The generic whole-input UTF16-to-UTF8 decoder and other codecs remain separate
translation bodies. No native browser bundle was built or captured privately.
