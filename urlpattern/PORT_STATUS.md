# URLPattern translation status

Upstream references:

- `Libraries/LibWeb/URLPattern`
- `Libraries/LibURL/Pattern`

The Web-facing wrapper and the LibURL pattern engine are translated. The V
package now contains the upstream-shaped tokenizer, constructor-string state
machine, pattern-part parser, component canonicalizers, regexp/name-list
generator, init processor, and match/result construction. URL parsing uses the
translated `url.URL` record; the former `net.urllib` boundary and handwritten
literal/glob matcher have been removed.

| Upstream implementation | V implementation |
| --- | --- |
| `LibWeb/URLPattern/URLPattern.cpp` and `LibURL/Pattern/Pattern.cpp` | `url_pattern.v` |
| `LibURL/Pattern/Tokenizer.cpp` | `pattern_tokenizer.v` |
| `LibURL/Pattern/PatternParser.cpp`, `String.cpp` | `pattern_parser.v` |
| `LibURL/Pattern/Component.cpp` | `pattern_component.v` |
| `LibURL/Pattern/ConstructorStringParser.cpp` | `constructor_string_parser.v` |
| `LibURL/Pattern/Canonicalization.cpp` | `pattern_canonicalization.v` |
| `LibURL/Pattern/Init.cpp` | `pattern_init.v` |
| `LibURL/Pattern/Options.cpp`, `Part.cpp` | `pattern_types.v` |

The regexp execution backend is V's `regex.pcre` VM. URLPattern performs the
Unicode-mode identity-escape validation that this backend does not enforce by
itself. More complete ECMAScript Unicode-sets conformance remains coupled to
the host regexp engine and must be measured with the full URLPattern WPT data;
it is not represented as a separate handwritten matching algorithm.

Verification:

```text
$ /Users/alex/code/v/v -enable-globals test urlpattern
Summary for all V _test.v files: 2 passed, 2 total.
```

The tests include all cases from
`Tests/LibURL/TestURLPatternConstructorStringParser.cpp` and focused WPT cases
for named/custom regexp groups, modifiers, canonicalization, opaque paths,
default ports, duplicate names, and invalid regexp escapes.
