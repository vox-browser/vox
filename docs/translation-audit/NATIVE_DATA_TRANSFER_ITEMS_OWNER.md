# Native Window DataTransfer items

Implementation: `e775be453c4d397d6712f6fc8aa07883acb1e4c0`. Immediate parent: `9b8881dfe6a230d27a5382cb49251826971b6dc0`.
Initial baseline/focused source: `34b02ae78b80ba796ba092a6a20bcebdabb444e5`.
Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and ownership

DataTransfer.items returns the actual cached HTML list. List and Item wrappers
cache by native pointer within one Runtime, preserving identity through removal,
reindexing and store replacement. Removed items remain branded but expose empty
kind/type and null File results. Disassociation also disables list indexing.
Protected stores retain length/kind/type metadata while hiding File payloads.

The Window-only illegal constructors follow InterfaceObject.cpp/ErrorTypes.h
call/new errors. Native readonly getters and methods retain source metadata.
The anonymous indexed getter installs Array.prototype.values as Symbol.iterator;
no public item(), add(), array convenience methods or string/entry callbacks are
invented. Supported indices have readonly enumerable/configurable descriptors.
Any canonical numeric definition fails, supported deletion fails and extension
prevention fails. Unsupported indices preserve inherited setters and distinct
ordinary receivers. Enumeration uses native records and numeric loops without
calling author Array iterators. Private factories/installer intrinsics survive
later global replacements and retain prototypes through late Window attachment.

remove brands first, checks required arity, converts unsigned long with genuine
number-hint/wrapping semantics, then applies the source mode gate. It throws a
fresh typed InvalidStateError DOMException (code 11) outside read/write mode,
including for out-of-range indices. Original author conversion errors survive.
clear is silent outside read/write mode. Pinned ItemList.cpp delegates clear to
DataTransfer.clear_data(), which removes only text items; files survive despite
the nearby source comment describing all items. This source quirk is retained.

The typed HTML getter preserves raw UTF-16 type units, including NUL and lone
surrogates, without changing the compatibility string getter. getAsFile returns
null for text, protected, removed and disassociated items before FileHost lookup.
Live file items use the existing relevant-owner FileAPI chain and produce fresh
copied File/Blob records on every call, preserving raw names/bytes and the source
current-clock lastModified default. No competing File host is installed.

Runtime close clears item/list registries and releases its existing protected
engine roots. Independent native records and other runtime registries remain
usable. This remains strong owner-local caching; weak WrapperWorld ownership and
foreign engine/WindowProxy conversion remain pending.

## Actual verification

| Run | Outcome |
| --- | --- |
| Parent baseline | One MAIN file compiles; two initial availability guards fail; later assertions unexecuted |
| Final focused | Four files / fourteen cases pass, including all nine new cases |
| Default / GC disabled | Seventeen selected files / fifty cases pass in each mode |
| Optimized | Three new files / nine cases pass with -prod -gc none |
| Production | Signed startup, two pixel-exact text-item pages and all eleven screenshot smoke cases pass |

The new browser tests cover native metadata, late attachment, pointer identities,
live indices/iteration, platform reflection, brands/conversion order, typed mode
errors, raw metadata, File gates/copies/tasks, retained factories and close.
Two real document fixtures carry mixed text/file native stores through parsed
video and created audio DragEvents, cancellation, redispatch, inherited reset,
disabled items, File copies and the owning document's file-reading tasks.

Only the MAIN file runs on the parent: browser/core fixtures call newly added
typed V APIs and would not compile there. The initial focused run passes three
files but fails a File fixture using V value inequality for pointer identity.
Its original freeze, sources, log, manifest and actual exit remain preserved;
the corrected assertion compares voidptr identities. Source review independently
corrects author iterator exposure, retains installer intrinsics and matches
constructor errors. Final passing tests use the fourth frozen revision.

An optional isolated Node model verifies only the JavaScript factory with a stub
callback. Its first metadata assumption fails on Node's sloppy-function property
behavior and earns no passing model credit. The corrected exited model preserves
that failure and earns no native V/WebIDL/parity credit. The separately reported
formatter failure also earns no test credit.

Final GC/optimized/production runs verify the exact committed private checkout,
including recorded intervening CSS/performance commits. The isolated source is
`Build/audit-fixes/native-data-transfer-items-validation-source`, with 5,042 exact
Git inputs and 2,662 preserved prior hashes. Production checks all ten stages
and actual prepare/build/provenance child exits, strict signature, exact recipes,
isolated source markers and all artifact hashes. Test compiler identities have
two inputs; production additionally authenticates the stable V_BIN wrapper.

Production pages use genuine nonempty TEXT items created by public setData;
getAsFile returns null. Nonempty FILE payloads and protected/disabled modes are
native V/real-owner coverage. No GUI file producer or test host is introduced.
The frozen recipes retain the historical Ladybird bundle name; canonical Vox
branding edits remain independently preserved. Only the verified owned scratch
volume is detached; persistent source, signed images and old evidence remain.

## Evidence and remaining work

Consolidated evidence: `Build/audit-fixes/native-data-transfer-items-evidence.json`
(SHA256 `96744137979d0e5726bc5816628aac05a14790a39a667b2e0d8cfe93f8b6cfbe`). It links actual terminal receipts, manifests, original
failed fixtures, frozen inputs, production provenance and cleanup. The audit and
inventory commits preserve foreign working/index entries through scoped merges.

Independent physical recount: `Build/audit-fixes/native-data-transfer-items-inventory-current.json`
(SHA256 `7b5ad87afb6c18b8529c2fce174a96e9ef9e863926ffaaa3618d1dde0ba3dfed`). At the code pin, 78 owners have 2,223 assigned
files, 433,216 implementation and 160,217 test V LOC. This feature contributes
only +10 HTML implementation / +74 test lines and one assigned test file.
Nine intervening assigned slices are accounted for separately; earlier b335958e
and older inventory artifacts remain unchanged. Physical LOC includes comments
and blank lines and establishes no behavioral parity.

Public add/getAsString/webkitGetAsEntry/setDragImage, physical Cocoa/Page drag
delivery, automatic store transitions/default actions, media ondrag handlers and
weak/foreign wrappers remain pending. JavaScriptCore remains this browser path's
engine. This slice establishes no full LibJS, FileAPI or drag/drop parity; the
historical ledger remains 32 fixed / 25 partial / 9 open.
