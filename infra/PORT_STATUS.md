# Infra translation status

Status: **Complete** (2026-08-17)

## Upstream inventory and mapping

The current `Libraries/LibWeb/Infra` inventory is 8 files and 556 physical
lines: 3 `.cpp` files / 405 lines and 5 adjacent `.h` files / 151 lines. The
module has no IDL files. `CharacterTypes.h` and `Types.h` were audited alongside
the implementation units.

| Upstream implementation | C++ LOC | V translation |
| --- | ---: | --- |
| `ByteSequences.cpp` | 57 | `infra.v` |
| `JSON.cpp` | 174 | `infra.v` |
| `Strings.cpp` | 174 | `infra.v` |
| **Total** | **405** | **193 implementation LOC** |

The translation covers byte case conversion, prefix and lexicographic order,
ASCII character classification, newline normalization, whitespace collapse,
UTF-16 code-unit prefix/order, scalar-value conversion, all declared integer
types, JavaScript-style JSON parse/stringify operations, and Infra-value JSON
serialization. JSON byte parsing explicitly uses the translated Encoding
UTF-8 decoder so malformed input receives the required replacement decoding.

## Representation boundary

V's `json2.Any` is the dynamic JSON-compatible value boundary used in place of
LibJS `JS::Value`. It preserves JSON scalars, arrays, objects and null while
keeping parse/stringify failure explicit through V result types.
`Unsigned128BitInteger` is an exact high/low `u64` representation because the
configured V backends do not uniformly expose a native `u128`.

## Tests and physical LOC

- Implementation: **193 LOC** (`infra.v`).
- Tests: **61 LOC**, **5 focused tests** (`infra_test.v`).
- Implementation and test counts are disjoint physical LOC; this file is
  excluded.
- Focused verification: `v test infra`.
