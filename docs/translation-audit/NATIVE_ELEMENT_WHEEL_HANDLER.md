# Native compact Element onwheel

Feature: `d86d5ac20fa3ab0cfb636e2e8daff0163a2d9a17`; immediate parent:
`23fd9c3588e580339141142cd49d0f2e07861f02`. Upstream reference:
`963d46a829f3e1b79f44dba9d02afb70654300fa`. Verification date: 2026-10-14 UTC.

The compact HTML, SVG and MathML facades expose an own native `onwheel` accessor that
uses the actual owner's EventTarget handler map. Null and foreign namespace elements
retain native wheel listeners without this accessor. Created elements preserve
null/empty namespaces. Media retains its existing handler prototype; images retain their
specialized prototype and lazy facade identity.

Receiver branding precedes replay and callback conversion. Nullable legacy conversion
retains object identity, clears primitive values without coercion, and leaves
noncallable objects silent without reading `handleEvent`. Callable functions and proxies
use the existing callback path with the current facade as `this`, the same Event
wrapper, owner settings, exception reporting and Page gates. Replacement retains the
existing listener position; null clears the slot and a later assignment activates it
again. Ordinary listener removal or signal abort does not remove the independent handler
slot.

An exact Boolean `false` return sets the canceled flag directly, matching the pinned
source even for noncancelable or passive delivery. Zero and boxed false do not cancel.
`preventDefault()` retains its separate cancelable/passive gates.

The replay hook flushes queued DOM writes before a getter and after a setter captures
the callback settings. Explicit HTML `onwheel` content writes retain their semantics
even when text is unchanged; removing an absent attribute is a no-op. Drained operations
and equal-text bulk guards preserve subsequent IDL assignments across repeated
finalization. Raw Element handler source remains uncompiled; reading a raw HTML slot
returns null without executing it. SVG and MathML content-hook behavior remains the
pinned source boundary.

Compiler corrections are `0a0a4008` (shadowed replay local) and `3a3aa08a` (native
pointer/optional callback typing). `29aab226` changes only two focused fixture
declarations: mutable heap alias and `CallbackType.handle_event`. Earlier
compiler/fixture failures executed zero test bodies. A later private checkout lacked its
native regex archive and was stopped after failed linking; its failures and interrupted
compilation retain no pass credit. The first production build failed compilation. The
next passed build/sign/startup but captured zero handler images because its path did not
match the existing reftest routing rule. The fresh render continuation relocates
identical quoted fixture bytes and leaves the original whole attempt failed.

Focused binding and BrowserApp owner fixtures cover descriptor metadata, branding,
conversion, slot order, raw/IDL ordering, namespace eligibility, native software wheel
delivery, cancellation before scrolling, DOM paint updates, exceptions, owner scripting
gates and runtime close. Composed verification passes all seven files /17 cases in each
GC mode, including six new cases. Three browser files /nine cases completed before the
CLI turn interrupted the batch; four remaining root files /eight cases subsequently
completed with actual exit 0 in persistent runs. The interrupted batch exit is
unavailable and receives no whole-batch pass credit. Production and screenshot
verification: Passed build/sign/startup at 3a3aa08a plus a fresh render continuation
using the unchanged signed binary: two exact handler pages, all 11 smoke cases (eight
exact /three retained tolerance), and eight exact SVG regressions. Public handler pages
use untrusted author dispatch; existing startup software GG checks inject six events.
Source pin and any retained working overrides: Production source 3a3aa08a and test
source 29aab226 retain exact Git inputs plus the six recorded preexisting working
overrides. The three implementation files are identical between these pins. The native
regex archive is an authenticated static-link prerequisite from the successful
production build. Software input checks do not establish operating-system or hardware
injection.

Evidence: `Build/audit-fixes/native-element-wheel-handler-evidence-v1.json` (SHA256
`2d549e18bf87afa7458ffea51129f54348303478a7ac876cc0c6746d75bd8842`) Frozen source and
focused tests: `Build/audit-fixes/native-element-wheel-handler-frozen-v3.json`;
`Build/audit-fixes/native-element-wheel-handler-tests-composed-v1.json` Production:
`Build/audit-fixes/native-element-wheel-handler-production-composed-v1.json` Scoped
inventory: `Build/audit-fixes/native-element-wheel-handler-inventory-scoped-v1.json`
(SHA256 `e9b99ef0d72ed5fe2595c7a02c3bc59fa17c1851853fffd8e03b67189e8ae507`) Prior
evidence preservation and cleanup:
`Build/audit-fixes/native-element-wheel-handler-final-closure.json`

The six owned browser/root paths are excluded from assigned translation counts. Each
owned commit has zero assigned-file, implementation-LOC and test-LOC delta against its
own parent. Current global inventory tables, pins, references and all historical ledgers
remain intact; this note reports only the verified slice.

Raw Element compilation, complete HTMLElement/SVGElement/MathMLElement prototype
hierarchies, general non-wheel listener migration, weak/foreign-realm ownership, zoom,
nested navigable forwarding, snap/compositor orchestration and physical device
automation remain outside this slice. JavaScriptCore remains the browser backend.
