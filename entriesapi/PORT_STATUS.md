# EntriesAPI module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/EntriesAPI`

Translation workspace: `~/code/libweb_v/entriesapi`
Audited: 2026-08-16

The sole upstream EntriesAPI `.cpp` implementation unit has an audited V
implementation mapping. Its header enum and the implemented Web IDL attributes
are represented by typed V APIs.

| Upstream implementation unit | V implementation |
| --- | --- |
| `FileSystemEntry.cpp` | `file_system_entry.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `EntriesAPI/` | 1 | 55 | 44 | 32 | Complete |

The port covers creation of file and directory entries, the mutually exclusive
`isFile`/`isDirectory` getters, and owned names including empty and Unicode
values. The IDL's `fullPath`, `filesystem`, and `getParent` members are marked
`FIXME` upstream and have no corresponding C++ implementation, so the V port
does not invent behavior for them.

## Verification

```text
$ /Users/alex/code/v/v test entriesapi
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify entriesapi
(no output; exit status 0)
```
