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

Remaining work includes NumberFormat, RelativeTimeFormat, Collator, PluralRules,
other Intl constructors, additional Locale metadata methods, non-Gregorian
calendar algorithms and date-range formatting. Valid unsupported calendar or
numbering-system requests negotiate to supported data. Pattern matching is not
claimed identical to ICU or Brave. The embedding's default locale is currently
`Realm.intl_default_locale` (`en-US` unless changed by the embedding).

Compiler-only import checks pass in normal and production/preallocation GC-none
modes. They do not compile `_test.v` files or execute JavaScript. See the
[continuation record](LIBJS_GITHUB_RUNTIME_20261115.md#native-intl-locale-date-and-list-continuation)
for exact commits, retained failed attempts, pending checks and production
source-witness gaps. Strict GitHub content and pixel acceptance gates remain
unchanged.
