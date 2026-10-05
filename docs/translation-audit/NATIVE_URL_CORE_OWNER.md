# Native URL core records and page caller

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `a893f4ec`, with implementation, the actual page caller and
three focused test files committed together.

Source `DOMURL/DOMURL.{cpp,h,idl}` supplies the actual translated URL record.
The pinned binding generators supply constructor, USVString argument,
attribute, stringifier and static-operation behavior. The original native
context exposes no URL global. Page-script startup now installs URL after its
actual URLSearchParams host. The two hosts must share the same HTML settings
object; the lookup accessor lives with the query-host registry.

The core includes constructor/base resolution, parse/canParse, all twelve
attributes, href stringification and toJSON. Native accessors and operations
have engine function metadata. Window settings also expose webkitURL.
Receiver validation precedes conversion; input converts before optional base,
and undefined base stays absent. Actual engine UTF-16 becomes USVString before
entering the typed parser. Thrown conversion values retain their identity.
newTarget.prototype is observed before argument validation/conversion;
same-realm subclass and fallback-prototype behavior are covered.

Protected engine wrappers hold genuine V DOMURL owners. Typed and JavaScript
mutations share that owner. searchParams wraps the URL's actual lazy query
record through the previously installed native query host, preserving identity,
writeback and iterator position across href replacement. Runtime close removes
both registries. These APIs use Source's basic URL parser; the separate LibWeb
finish hook that resolves Blob-store snapshots is not called here.

The page-script caller exercises explicit relative base, a literal leading
question mark, query writeback, document text replay, load ordering and final
HTML/VM context cleanup. A fixture runner executes the unmodified script bodies
from Source url.html and search-params-with-no-query.html and compares complete
output with their expected files. Only the external test harness is replaced.
The output logger preserves raw UTF-16 surrogate labels; actual URL USVString
conversion independently normalizes those units. No URL cases or expected
outputs are overridden.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original native global | Executed URL-absence assertion fails | 203.078 |
| First two-file binding run | Both fail to compile; no assertions executed | 169.969 |
| Final host, Source fixtures and page caller, default GC | 3/3 files PASS; two exact Source outputs | 377.284 |
| Combined focused/neighbor batch, GC-none | 6/6 files PASS; two exact Source outputs | 417.509 |

The first compiler run could not resolve a direct cross-file query-registry
reference. Moving the lookup behind an accessor in its owning file fixes that
compile boundary without removing settings identity validation. Those original
compiler diagnostics remain distinct from the executed baseline failure.
The GC-none batch uses `VJOBS=3` and adds the query-host neighbor, actual
script-environment owner and existing 66-case browser regression to the three
new files. Both Source outputs contain 377 lines total (375 plus two).

Exact argv/environment overrides, log hashes, output hashes and final feature
hashes are recorded in
`Build/audit-fixes/source-url-host-manifest.json`, SHA256
`5269ced8029eb4817a381f2da117122b2f69ca707b0e86e3f4aac81c3ce80873`.
The recorded code snapshot has SHA256
`9963e0dd02b159d16647584385e96180bf9390e516acb390fe1f8808e6a01a8e`.
It was captured during the corrected default compilation, before GC-none.
After both passing commands, all **3,168 recorded V/native-helper files**,
**23 selected Source references** and both compiler executables remain
unchanged. External native libraries and the whole toolchain are outside this
scoped record.

At this feature snapshot, public createObjectURL/revokeObjectURL,
native MediaSource exposure, foreign
realm/world behavior, Worker startup, complete parser UTF-16/encoding behavior,
full generated diagnostic text, allocation limits, physical GC edges and IPC
remained separate. The subsequent [Blob/File object-URL slice](NATIVE_URL_BLOB_OBJECT_OWNER.md)
records its own implementation and checks; the native MediaSource branch remains
pending. Browser JavaScript execution still uses JavaScriptCore.
The [previous frozen production bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md)
predates this work. No new production or screenshot verification is claimed.
The audit remains **32 fixed / 25 partial / 9 open**.
