# Bindings module V translation — source records and native boundaries

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Bindings`

Translation workspace: `~/code/vox2/bindings`
Historical mapping audit: 2026-08-16
Native-value follow-up: 2026-10-04, Source `963d46a829f3e1b79f44dba9d02afb70654300fa`

The original nine implementation units have V source-record mappings. The
current pinned source also contains InterfaceObject, WrapperWorld and Wrappable
units, mapped below. These mappings do not establish complete native wrapper or
constructor parity. Header-only contracts have translated records as well.

| Upstream implementation unit | V implementation |
| --- | --- |
| `AudioConstructor.cpp` | `audio_constructor.v` |
| `HostDefined.cpp` | `host_defined.v` |
| `ImageConstructor.cpp` | `image_constructor.v` |
| `InterfaceObject.cpp` | `interface_object.v` |
| `Intrinsics.cpp` | `intrinsics.v` |
| `MainThreadVM.cpp` | `main_thread_vm.v` |
| `OptionConstructor.cpp` | `option_constructor.v` |
| `PlatformObject.cpp` | `platform_object.v` |
| `PrincipalHostDefined.cpp` | `principal_host_defined.v` |
| `SyntheticHostDefined.cpp` | `synthetic_host_defined.v` |
| `WrapperWorld.cpp` | `wrapper_world.v` |
| `Wrappable.cpp` | `wrapper_world.v` |

Header-only `AgentType.h`, `ExceptionOrUtils.h`, `Serializable.h`, and
`Transferable.h` map to `main_thread_vm.v`, `exception_or_utils.v`,
`serializable.v`, and `transferable.v` respectively.

The historical 2026-08 mapping counted nine units, 1,718 upstream lines,
1,639 translated lines and 488 test lines. Those counts and the old verification
below are historical evidence, not measurements of current parity.

The port covers the `Audio`, `Image`, and `Option` constructor algorithms;
lazy realm intrinsic and unforgeable-function identity; principal and synthetic
host-defined state; Serializable and Transferable contracts;
legacy platform-object internal-method records; main-thread agent setup; callback,
promise, finalization, mutation-observer, and custom-element job dispatch;
import-meta and imported-module validation; synthetic realms; and resizable
buffer host hooks.

LibWeb's C++ layer embeds LibJS objects and generated IDL classes. The V
translation uses `dom.JSValue`, named intrinsic records, and typed host
callbacks. Module fetching, CSP decisions, and actual JavaScript evaluation
remain explicit host boundaries, while their Bindings-side validation,
bookkeeping, ordering, and error behavior are implemented here.

## Source native-value consumers, 2026-10-04

Image's genuine native width/height values now delegate actual ToNumber through
the existing runtime/WebIDL owner before the translated ToUint32 steps. This
maps ImageConstructor.cpp's argument conversions and Value.cpp's throwing
ToNumber path: width precedes height, and original thrown values propagate.
Focused checks cover object coercion, modulo/truncation, native string parsing,
non-finite/negative-zero values, and actual BigInt/Symbol TypeErrors.

Option's genuine native defaultSelected/selected values now use the owning
engine's ToBoolean, with no author coercion. Native text/value use the existing
throwing ToString owner rather than the DOM diagnostic string adapter. This
preserves Source OptionConstructor.cpp's text/value order and original thrown
values; Symbol string conversion throws, while Symbols and objects remain
truthy in the boolean positions. Existing standalone scalar behavior is retained.

PlatformObject's ordinary fixed data-property validation now uses the actual
native SameValue owner for native/native values, existing LibJS SameValue for
scalar Number NaN/signed-zero behavior, and raw scalar UTF-16 units for strings.
Source SameValue is a nonthrowing internal comparison: unavailable ownership
hooks fail the internal invariant rather than reporting invented equality.
Focused checks cover object and Symbol identity, arbitrary-precision BigInts,
NaN, signed zero, lone UTF-16 units and poisoned author Object.is/coercion methods.
No LibJS implementation changed.

The three focused native fixtures plus existing constructor/platform regressions
pass **5/5** in both default and GC-none modes with
`v -old-compiler -enable-globals [ -gc none ] test ...`. Logs are
`Build/audit-fixes/source-bindings-native-values-{default,gc-none}.log`.

Older standalone gaps remain: unowned object numeric/string conversion is not
the engine ToPrimitive path; native-versus-standalone representation comparisons
are not normalized into one engine value; property descriptor/accessor storage
and receiver/prototype traversal are partial typed records. The legacy factory
APIs take an explicit document instead of implementing Source current-window
lookup, genuine returned engine wrappers, and newTarget/foreign-realm prototype
selection. Option's DOM string storage also retains its existing UTF-8 boundary.
The older standalone constructor-without-new diagnostics do not match Source's
current error wording. Those boundaries must not be described as full parity.

The shared `dom.Element.take_custom_element_reactions()` boundary lets
`MainThreadVM` consume reaction queues without exposing DOM storage internals.

## Verification

```text
$ /Users/alex/code/v/v test bindings
Summary for all V _test.v files: 5 passed, 5 total.

$ /Users/alex/code/v/v test .
Summary for all V _test.v files: 193 passed, 193 total.
```
