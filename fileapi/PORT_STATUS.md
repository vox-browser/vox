# FileAPI module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/FileAPI`

Translation workspace: `~/code/libweb_v/fileapi`
Audited: 2026-08-17

| Upstream `.cpp` | LOC | V mapping |
| --- | ---: | --- |
| `Blob.cpp` | 457 | `blob.v`, `file_reader.v` |
| `BlobURLStore.cpp` | 161 | `blob_url_store.v` |
| `File.cpp` | 133 | `file.v` |
| `FileList.cpp` | 81 | `filelist.v` |
| `FileReader.cpp` | 421 | `file_reader.v` |
| `FileReaderSync.cpp` | 106 | `file_reader.v` |

- Upstream inventory: **6 `.cpp` / 1,359 LOC**, **6 `.h` / 391 LOC**,
  **5 `.idl` / 99 LOC**.
- V implementation: **943 LOC** in 5 `.v` files.
- Focused tests: **448 LOC** in 5 `_test.v` files (37 tests).
- Mapping completeness: **6/6 implementation units**, **6/6 headers**, and
  **5/5 IDL definitions** audited.

The port covers immutable owned Blob bytes, MIME normalization, line-ending and
blob-part processing, slicing, byte streams, UTF-8 text, fresh ArrayBuffer and
Uint8Array-equivalent byte results, typed structured serialization, File name /
type / last-modified state, FileList ordering and indexed access, UUID blob URL
generation, partition authorization, fragment-insensitive resolution, removal
and environment cleanup, all four FileReader packaging modes, encoding-label /
MIME-charset/BOM handling, queued state transitions, abort semantics and event
ordering, handler attributes, and all four synchronous reader methods.

The independent cross-audit added read-generation checks after `loadstart` and
`progress` dispatch. If an event handler aborts or replaces a read, the stale
read now terminates without firing progress/load/loadend for the old operation;
both re-entrant abort points have focused regressions.

## Boundaries

WebIDL Promise and JavaScript ArrayBuffer/Uint8Array wrappers are LibJS-owned;
Blob's standalone accessors return the same deterministically settled text or a
fresh typed byte buffer. `process_pending_tasks()` is the explicit HTML file-
reading task-source boundary, allowing callers to observe LOADING and abort a
pending read before completion. It dispatches trusted FileReader events through
the inherited DOM EventTarget in spec order. The browser owns the process-wide
Blob URL store and current settings
object, so V exposes an owned `BlobURLStore` and requires a typed environment.
MediaSource storage uses its stable host identity until that external object is
wired. HTML owns the final structured-serialization wire encoder; the complete
FileAPI payload fields and reconstruction steps are typed here.

## Verification

```text
$ /Users/alex/code/v/v test fileapi
Summary for all V _test.v files: 5 passed, 5 total.

$ /Users/alex/code/v/v fmt -verify fileapi
(no output; exit status 0)
```
