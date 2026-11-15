# Native LibJS Intl implementation

This is a partial native implementation. It does not establish full ECMA-402,
ICU, GitHub initialization, rendering or Brave pixel parity. Runtime tests and
browser comparisons remain held at the user's request; new assertions are
prepared source, not passing evidence.

Implemented APIs:

| API | Current implementation |
| --- | --- |
| `Intl.getCanonicalLocales` | Checked locale-list access, ASCII Unicode locale grammar, CLDR aliases, canonical extension ordering and deduplication |
| `Intl.Locale` | Native slots, constructor options and getters, `toString`, likely-subtag `maximize`/`minimize` |
| `Intl.DateTimeFormat` | Gregorian/ISO date fields, styles, numbering-system digits, hour cycles, fractional seconds, bound `format`, `formatToParts`, `resolvedOptions`, `supportedLocalesOf` |
| `Intl.ListFormat` | CLDR conjunction/disjunction/unit templates and styles, checked string iterables, iterative partitions, UTF-16 output/parts, resolved/supported locales |
| `Intl.NumberFormat` | Native decimal/percent/currency/unit formatting, standard/scientific/engineering/compact notation, decimal rounding options, grouping/signs, bound `format`, parts and resolved/supported locales |
| `Intl.RelativeTimeFormat` | CLDR past/future and numeric-auto patterns, styles, cardinal plurals, signed zero, localized numeric parts with units and resolved/supported locales |
| Locale String case conversion | `toLocaleLowerCase`/`toLocaleUpperCase`, checked first-locale selection, existing V Unicode contextual mappings and UTF-16 preservation |
| `Number.prototype.toLocaleString` | Retained native NumberFormat intrinsic, receiver checks and formatter error propagation |
| `Intl.Collator` / String locale comparison | Native CLDR root order for English locales, canonical normalization, contractions/expansions, sensitivity/case settings, numeric runs, shifted punctuation, bound `compare`, resolved/supported locales and retained default intrinsic |

The formatter implementation is V. It uses the existing V TZif reader for IANA
time-zone rules and `vunicode` for Unicode properties. There is no formatter
bridge to JavaScriptCore, V8, system locale APIs or ICU. The source-only
`tools/check_unicode_dependency.py` scan passes; this is not a linked-binary
dependency audit.

The upstream implementation reference is
`~/code/3rd/ladybird/Libraries/LibJS/Runtime/Intl`. The data comes from
[Unicode CLDR JSON 48.2.0](https://github.com/unicode-org/cldr-json/tree/bb334e8d6250c9363e957e131bf7e6d08ec72f91),
pinned to commit `bb334e8d6250c9363e957e131bf7e6d08ec72f91`.
`libjs/intl_data/SOURCES` records each consumed input's SHA-256;
`libjs/intl_data/LICENSE` retains the Unicode license.

To regenerate from that exact source tree:

```sh
python3 tools/generate_libjs_intl_data.py /path/to/cldr-json
```

The generator uses official resolved JSON data, not host formatter output or
page fixtures. It emits an embedded core index and offset-addressed locale
records. The 766 locale records and default-content aliases cover 1,121 locale
identifiers. Locale records store differences from parent records, reducing the
embedded data; decoding one locale copies inherited maps before applying its
overrides. No VM startup decode of the complete locale table is required.
Core data and individual locale records are loaded lazily and retained in the
owning realm, outside temporary allocation arenas.
The number/relative-time extension includes CLDR symbols, grouping/patterns,
compact forms, currency names/fraction digits, sanctioned-unit patterns,
cardinal/ordinal rules and relative-time fields. The locale asset is now
21,477,685 bytes and the core index is 347,131 bytes; both remain generated
source data with per-input hashes, rather than measurements or host output.

Date/time patterns are parsed with CLDR quoting and field widths. Matching uses
the BasicFormatMatcher penalties over supported Gregorian patterns; best-fit
currently uses the same selection policy. Locale-required leading zeroes,
stand-alone versus contextual month names, localized digits and CLDR GMT-offset
patterns are preserved. Time-zone identifiers are validated against the pinned
CLDR alias data before loading their TZif rules. Rules come from the host's
zoneinfo data or the V loader's fallback, so their identity/version must be
pinned in future measurements. Unknown system-zone names use a consistent fixed
offset rather than reporting an offset identifier for changing DST rules.

A bound date-format function is a traced `FunctionObject` record with its own
callee context, not an escaping V closure retaining the formatter through the
global trampoline registry. It preserves formatter identity, realm, native
metadata and exception propagation. List formatting uses an explicit emission
stack, so large lists do not recurse through the native stack. The optional
Spanish/Hebrew contextual changes follow the
[Unicode list-pattern rules](https://unicode.org/reports/tr35/tr35-general.html).

Number formatting uses exact decimal coefficient/exponent arithmetic. Number
inputs start from the engine's shortest decimal spelling; BigInt inputs and
finite decimal String inputs preserve their original precision, following
[ToIntlMathematicalValue](https://tc39.es/ecma402/#sec-tointlmathematicalvalue).
Rounding supports all nine signed modes, fraction/significant priorities,
sanctioned increments and trailing-zero display. Decimal digit division keeps
rounding and plural modulo operations independent of binary64 precision. Plural
operands retain visible trailing zeroes. Number bound functions use traced
records and their own callee contexts, as date bound functions do. The legacy
injected Number/BigInt adapter surfaces remain available; BigInt's production
intrinsic graph is still pending.

Relative-time formatting retains the native NumberFormat intrinsic and uses
CLDR plural-specific past/future templates or numeric-auto literals. Negative
zero selects the past numeric template. Locale String casing uses the existing
`vunicode` tables, including Turkish/Azerbaijani, Lithuanian and Greek tailoring;
all requested locale entries are validated before using the first language.
Unknown first languages use default Unicode mappings, without selecting a
later locale request.

Collation uses a separate pinned
[CLDR release-48 root table](https://github.com/unicode-org/cldr/tree/acd6d88ae493633240e19a87a721076a8a75c310/common/uca)
with Unicode 17.0.0 data. Regenerate with
`python3 tools/generate_libjs_collation_data.py /path/to/cldr-collation-48`;
the source directory also needs the official Unicode 17 `UnicodeData.txt` and
`Blocks.txt`. The generator rejects changed input hashes and retains its license
and provenance under `libjs/intl_collation_data/`. The root trie has 39,762 nodes,
39,761 mappings and 45,860 collation elements; the principal asset is 1,529,016
bytes. Immutable tables use binary-search sibling spans and require no per-VM
JSON decode. Runtime comparison follows the
[UCA 17 algorithm](https://www.unicode.org/reports/tr10/tr10-53.html) and
[CLDR case parameters](https://www.unicode.org/reports/tr35/tr35-77/tr35-collation.html#Case_Parameters):
canonical normalization, longest contiguous/discontiguous contractions,
expansions, implicit weights and independent weight levels. Normalization reorder
work and contraction processing consume the VM budget.

Numeric comparison handles all 770 Unicode 17 decimal digit code points using
exact significant digit runs, including leading zeroes and different scripts.
Bound compare functions are traced records with callee contexts. String
localeCompare coerces both strings before locale/options effects and retains the
Collator intrinsic; only the default-options path caches a collator, keyed by
the realm's default locale. History rejects native Collator state before author
getters.

Available collation locales are currently `en`, `en-US` and `en-GB`, using their
root standard order. English regional requests can negotiate to `en`; other
languages negotiate to an implemented default. The supported-locales API uses
this smaller set. Locale-specific, alternate and search-specific tailorings,
Han radical/stroke ordering and a full collation corpus remain pending. Search
usage currently uses the root comparison and variant sensitivity. This does not
establish ICU/Brave collation equality or full ECMA-402 conformance.

Remaining work includes public PluralRules,
other Intl constructors, additional Locale metadata methods, non-Gregorian
calendar algorithms, date ranges and NumberFormat ranges. Full number-pattern
conformance remains unverified, including compact accounting signs, complex
compound-unit grammar, non-ASCII currency boundary spacing and legacy chained
NumberFormat construction. Locale matching currently uses lookup for best-fit;
date best-fit shares the basic pattern matcher. Valid unsupported calendar or
numbering-system requests negotiate to supported data. Pattern matching is not
claimed identical to ICU or Brave. The embedding's default locale is currently
`Realm.intl_default_locale` (`en-US` unless changed by the embedding).

Compiler-only import checks pass in normal and production/preallocation GC-none
modes. They do not compile `_test.v` files or execute JavaScript. See the
[continuation record](LIBJS_GITHUB_RUNTIME_20261115.md#native-collation-and-url-continuation)
for exact commits, retained failed attempts, pending checks and production
source-witness gaps. Strict GitHub content and pixel acceptance gates remain
unchanged.
