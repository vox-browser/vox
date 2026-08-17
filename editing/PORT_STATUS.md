# Editing module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Editing`

Translation workspace: `~/code/libweb_v/editing`
Audited: 2026-08-16

All four upstream Editing `.cpp` implementation units have an audited V
implementation mapping. The declarations from `CommandNames.h`, `Commands.h`,
and `Internal/Algorithms.h` are represented by the typed command registry,
editing-host model, range records, command APIs, and reusable algorithms.

| Upstream implementation unit | V implementation |
| --- | --- |
| `CommandNames.cpp` | `command_names.v` |
| `Commands.cpp` | `commands.v` |
| `ExecCommand.cpp` | `exec_command.v` |
| `Internal/Algorithms.cpp` | `internal_algorithms.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Editing/` | 4 | 7,980 | 2,019 | 660 | Complete |

The port contains all 41 upstream command names and all 36 command definitions,
including the intentionally actionless `preserveWhitespace` definition. It
implements the legacy `execCommand` support/enabled/state/indeterminate/value
queries; recursion and non-HTML guards; plaintext-only restrictions; linked
background-color overrides; input-type mapping; selection replacement;
backward and forward deletion; paragraphs and line breaks; ordered and
unordered lists; indentation; justification; inline formatting; script
position; colors, fonts, links, images, horizontal rules, and HTML fragments;
format removal; and selection-wide actions.

The internal algorithm mapping covers normalized selection boundaries,
effective command values, record/restore of overrides and node values, list
state, canonical whitespace runs, legacy font-size conversion, equivalent and
loosely equivalent values (including CSS color component equivalence), and the
upstream element-name classification sets.

Ladybird implements Editing directly on GC-managed DOM nodes. Importing the V
`dom` package from this package would create a package cycle because translated
`Document` already owns editing entry points. The translation therefore keeps
the same observable editing algorithms behind `EditingDocument`, a typed
editing-host adapter made of block containers, inline/replaced items, and
normalized range boundaries. It is not a placeholder: mutations, command
state, markup serialization, overrides, and input records are concrete and
covered end to end. A future package-boundary refactor can make DOM's adapter
delegate here without changing these algorithms.

## Verification

```text
$ /Users/alex/code/v/v test editing
Summary for all V _test.v files: 4 passed, 4 total.

$ /Users/alex/code/v/v fmt -verify editing
(no output; exit status 0)
```
