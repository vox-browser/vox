# Owned DOM URL records and actual settings parsing

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `d1531756`, following the separately committed
[actual settings and snapshot](BLOB_URL_SETTINGS_SNAPSHOT_OWNER.md) and
[partition authorization](BLOB_URL_PARTITION_ACTUAL_ENVIRONMENT.md) slices.

Source `DOMURL/DOMURL.cpp:439–486` finishes a LibWeb URL parse by resolving
its live Blob store entry and copying bytes/type or the empty MediaSource tag,
plus the creator settings' current Origin. `LibURL/URL.h:158–173` retains that
entry when copying URL data and changing components. A shared cache keyed by
serialization cannot represent two independent parses of the same address
whose Blob or creator origin changed between calls.

The actual DOM URL now owns its typed value record. HTML settings creation
installs the existing DOMURL finish function through a function hook across
the DOM/FileAPI/HTML import cycle. Actual settings and DOM resource parsing
therefore receive the genuine store snapshot. Component updates and getters
copy the record and its Blob bytes. The public serialized compatibility
constructor keeps its basic-parser cache and cannot borrow another URL's
snapshot; a direct public value edit rejects a mismatching retained record.
Public DOMURL API parsing still uses the Source basic-parser boundary.

Adding the private field requires named V initializers. The implementation
commit includes 509 mechanically converted literals across 210 files; their
expressions are unchanged. The migration records pre/post SHA256 values in
`Build/audit-fixes/source-owned-dom-url-literal-migration.json`. The before
values were compared with the baseline commit, and mechanical-only after
values with the reviewed implementation.

The old V C generator initially assigned a captured navigation URL before
its heap-local declaration. Declaring the URL before optional selection in
`html/window.v` preserves the previous fallback and selection behavior and
allows the actual Window navigation code to compile. Both diagnostic runs
are retained. The initial eight-file run crossed that correction: its first
two files failed compilation and six later files passed. It is not a clean
verification of one unchanged snapshot.

## Focused verification

The original actual settings parse test executed and failed because the
request URL had no copied entry. The final two-case test exercises genuine
Page, Document, Window/settings and Blob owners: repeated parses after Blob
mutation and Document origin changes, independent byte/path copies, component
retention, revocation followed by a new parse, raw-string separation and a
direct serialized-value edit.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original actual settings parse, GC-none | Executed missing-entry failure | 64.319 |
| Initial three files, default GC | Two compiler failures; one passes | 177.867 |
| Initial eight files, GC-none | Two compiler failures; six pass across the correction | 507.656 |
| Final default GC | 3/3 PASS | 122.499 |
| Final GC-none | 4/4 PASS | 245.569 |

Final default files: `html/blob_url_dom_record_owner_test.v`,
`dom/resource_url_origin_owner_test.v`, `html/file_origin_policy_owner_test.v`.
Final GC-none files: the new owner test, `html/blob_url_partition_owner_test.v`,
`html/window_context_test.v` and the 66-case `main_test.v`. Commands use
`VJOBS=2 v -old-compiler -enable-globals test`, adding `-gc none` for that row.
The 215 implementation/test file hashes matched the frozen feature record
before committing. Logs have the `source-blob-dom-record-` prefix under
`Build/audit-fixes/`; exact argv, original probe hash, implementation hashes,
log hashes and summaries are in `source-blob-dom-record-manifest.json`, SHA256
`2a8a9be0c38fd4b0afbc393245bfdd0d3dcbeddd843fe2d3163f87f5f9df68b8`.

This completes the bounded owned DOM parsing prerequisite. Fetch and media
still use their Legacy store bodies at this commit. Public native URL WebIDL
conversion/exposure, encoding-aware parser boundaries, remote IPC, physical
allocation and complete GC/WrapperWorld ownership remain separate. The main
regression is focused browser-engine proof, not a new production bundle or
screenshot run. The ledger remains **32 fixed / 25 partial / 9 open**.
