# Source unchecked ASCII UTF16 ownership

Recorded 2026-10-04 against read-only Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

`AK/Utf16String.cpp:40–53` copies the supplied bytes without ASCII validation.
Up to `MAX_SHORT_STRING_BYTE_COUNT` it uses the short record; longer input calls
`Utf16StringData::from_ascii` (`AK/Utf16StringData.cpp:58–64`) and copies into
owned ASCII storage. `Utf16View::code_unit_at` (`AK/Utf16View.h:394–400`) converts
plain native `char` to `char16_t`. `Utf16View::to_utf8` (`AK/Utf16View.cpp:17–23`)
returns its raw bytes directly when that ASCII storage flag is set. The helper
therefore must retain both the owned byte sequence and the native-char unit
projection, including malformed UTF8 and embedded NUL; UTF8 decoding would
change the Source result.

The existing translated `libjs.Utf16String` now has a private immutable raw byte
slot for this construction. `utf16_string_from_ascii_without_validation`
copies the input and materializes the same native `char` conversions with V's
C ABI `char`. `.str()` returns retained bytes, `.code_units()` returns a copied
unit slice, cloning retains owned bytes, and existing storage predicates retain
Source short/long metadata. Internal compatibility edits to the old mutable
unit array cannot reuse a stale byte slot. Normal code-unit, IPC ASCII validation
and UTF8 decoder construction continue to use their existing paths. V retains
flattened owned arrays rather than reproducing AK's physical inline record or
reference-counted heap allocation ABI.

The feature commit is `f25db8a4ee368ff03692f76c55371f0d752600ca`. New ownership,
existing byte-decoder and well-formed-string fixtures pass **3/3 with default GC
and 3/3 with GC-none**, recorded in
`source-utf16-ascii-focused-{default,gc-none}.log`. They cover all 256 values,
short threshold/empty input, raw WTF8/truncated bytes, NUL, copied input and
access ownership, clone lifetime, stale internal units and IPC validation.

The independently reviewable probe tool is
`3657138f5534b6504f6054bbb63139d129cfe4f3`,
`tools/source_utf16_ascii_probe.py`. Its native **-O0 and -O2 runs pass** in
`Build/audit-fixes/source-utf16-ascii-probe.log`. The real current AK headers
and exact unchanged Source constructor/allocation/from-ASCII bodies establish
owned short and long storage. The exact fly-string destruction prefix and
`AK/kmalloc.cpp` system-allocator instrumentation branch are also compiled.
The existing upstream AK dylib supplies verification and unreachable non-ASCII
helper dependencies; it is older than pinned current AK's StringBuilder ABI,
and its vcpkg simdutf headers lack later replacement helpers. This probe does
not build the complete current AK library or execute the complete
String-returning `Utf16View::to_utf8` method. It checks the genuine `ascii_view`
span used directly by that method's Source ASCII arm. Per-source/function and
linked dependency hashes are printed in the retained log.

On this arm64 macOS native ABI, plain `char` is signed: bytes `0x80` and `0xff`
produce units `0xff80` and `0xffff`; their byte projection stays `0x80` and
`0xff`. The actual native probe checks all 256 units, short limit 7, empty/NUL,
input mutation and copied owner survival. Other C ABIs retain their own native
plain-char signedness rather than forcing macOS's signed conversion.

This is a bounded owned-string prerequisite. Source FileReader DataURL routing,
native Sync return adapters and genuine asynchronous HostDefined/world weak
ArrayBuffer caching are distinct translation slices. Full LibJS and exact AST
verification is recorded separately for the frozen implementation snapshot.
