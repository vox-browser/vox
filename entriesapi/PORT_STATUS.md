# EntriesAPI module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/EntriesAPI`

Translation workspace: `~/code/vox2/entriesapi`
Audited: 2026-08-16

The sole upstream EntriesAPI `.cpp` implementation unit has an audited V
implementation mapping. Its header enum and the implemented Web IDL attributes
are represented by typed V APIs.

| Upstream implementation unit | V implementation |
| --- | --- |
| `FileSystemEntry.cpp` | `file_system_entry.v` |

## Historical mapping inventory (2026-08-16)

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `EntriesAPI/` | 1 | 55 | 44 | 32 | Complete |

The port covers creation of file and directory entries, the mutually exclusive
`isFile`/`isDirectory` getters, and owned names including empty and Unicode
values. The IDL's `fullPath`, `filesystem`, and `getParent` members are marked
`FIXME` upstream and have no corresponding C++ implementation, so the V port
does not invent behavior for them.

## Historical verification (2026-08-16)

```text
$ /Users/alex/code/v/v test entriesapi
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify entriesapi
(no output; exit status 0)
```

## Native FileSystemEntry and DataTransfer entries

Current canonical workspace: `~/code/vox2/entriesapi`. Exact committed inventory
at `fdc13cca` records 65 implementation V LOC and
59 test V LOC across 3 assigned EntriesAPI files.
The dated 2026-08-16 mapping table and verification transcript above remain historical.
The independent counter is `Build/audit-fixes/native-data-transfer-entry-inventory-current.json` (SHA256 `f3062da8a0c0354822688a690594c6497ce8771933ef566068f0229a61e35a26`).
Physical counts include comments and blank lines and establish no parity credit.

Native Window FileSystemEntry exposes readonly isFile/isDirectory/name metadata
through an actual-record owner registry. Typed file and directory records retain
their identity, native names and stable wrappers; DataTransferItem.webkitGetAsEntry
creates a new file entry per successful read. Names preserve raw stored UTF-16,
including lone surrogates and NUL, matching the pinned C++ conversion round trip
and generated USVString return wrapper. The compatibility V name() byte view
remains intact. Protected/non-file/removed/disassociated items return null.
Directory-looking DataTransfer filenames still produce file entries, as upstream.

Native construction is unavailable. Brand checks reject prototype spoofs, proxies
and foreign owner wrappers without public metadata access; captured intrinsic
errors survive late author TypeError replacement. Runtime close clears record and
wrapper maps before released contexts can be used. Direct typed directory entries
exercise isDirectory, without claiming directory traversal or hardware production.

12 new / 21 focused cases pass; 15 files /
49 cases pass in each GC mode and 12 optimized cases pass.
Signed startup, two pixel-exact entry pages and eleven smoke cases pass
(8 exact, 3 at established tolerances). Public owner tests use actual
Page/video/audio native drag dispatch and balanced settings/VM contexts.
Upstream FIXME fullPath/filesystem/getParent properties remain absent, with
undefined reads and no invented throwing stubs. Generic entry callbacks, paths,
filesystem operations, directory traversal, weak/foreign WindowProxy ownership
and physical drag delivery remain unimplemented.
See [native entry evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ENTRY_OWNER.md).
