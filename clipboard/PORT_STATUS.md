# Clipboard module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Clipboard`

Translation workspace: `~/code/libweb_v/clipboard`
Audited: 2026-08-16

All four upstream Clipboard `.cpp` implementation units have an audited V
implementation mapping. The associated headers and IDL dictionaries are
represented by typed V records and constructors.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Clipboard.cpp` | `clipboard.v` |
| `ClipboardEvent.cpp` | `clipboard_event.v` |
| `ClipboardItem.cpp` | `clipboard_item.v` |
| `SystemClipboard.cpp` | `system_clipboard.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Clipboard/` | 4 | 892 | 948 | 332 | Complete |

The port covers MIME normalization and duplicate detection, mandatory-format
support, custom-format identity, string/Blob promise reactions, ClipboardEvent,
system-record encoding/decoding, transient-activation permission checks,
asynchronous read/readText/write/writeText processing, presentation styles,
and filtering of unknown native formats.

Ladybird reaches the native clipboard through Page IPC and uses LibJS/WebIDL
promises. The V translation exposes an owning `SystemClipboardBackend` as that
embedder boundary and uses typed observable promises. Clipboard work is queued
on the translated HTML permissions and clipboard task sources; writes with
pending representation data resume only after those promises settle.

## Verification

```text
$ /Users/alex/code/v/v test clipboard
Summary for all V _test.v files: 2 passed, 2 total.

$ /Users/alex/code/v/v test .
Summary for all V _test.v files: 195 passed, 195 total.
```
