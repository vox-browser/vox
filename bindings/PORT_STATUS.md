# Bindings module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Bindings`

Translation workspace: `~/code/libweb_v/bindings`
Audited: 2026-08-16

All nine upstream Bindings `.cpp` implementation units have an audited V
implementation mapping. Header-only contracts are translated as well.

| Upstream implementation unit | V implementation |
| --- | --- |
| `AudioConstructor.cpp` | `audio_constructor.v` |
| `HostDefined.cpp` | `host_defined.v` |
| `ImageConstructor.cpp` | `image_constructor.v` |
| `Intrinsics.cpp` | `intrinsics.v` |
| `MainThreadVM.cpp` | `main_thread_vm.v` |
| `OptionConstructor.cpp` | `option_constructor.v` |
| `PlatformObject.cpp` | `platform_object.v` |
| `PrincipalHostDefined.cpp` | `principal_host_defined.v` |
| `SyntheticHostDefined.cpp` | `synthetic_host_defined.v` |

Header-only `AgentType.h`, `ExceptionOrUtils.h`, `Serializable.h`, and
`Transferable.h` map to `main_thread_vm.v`, `exception_or_utils.v`,
`serializable.v`, and `transferable.v` respectively.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Bindings/` | 9 | 1,718 | 1,639 | 488 | Complete |

The port covers the `Audio`, `Image`, and `Option` constructor algorithms;
lazy realm intrinsic and unforgeable-function identity; principal and synthetic
host-defined state; Serializable and Transferable contracts; the complete
legacy platform-object property algorithms; main-thread agent setup; callback,
promise, finalization, mutation-observer, and custom-element job dispatch;
import-meta and imported-module validation; synthetic realms; and resizable
buffer host hooks.

LibWeb's C++ layer embeds LibJS objects and generated IDL classes. The V
translation uses `dom.JSValue`, named intrinsic records, and typed host
callbacks. Module fetching, CSP decisions, and actual JavaScript evaluation
remain explicit host boundaries, while their Bindings-side validation,
bookkeeping, ordering, and error behavior are implemented here.

The shared `dom.Element.take_custom_element_reactions()` boundary lets
`MainThreadVM` consume reaction queues without exposing DOM storage internals.

## Verification

```text
$ /Users/alex/code/v/v test bindings
Summary for all V _test.v files: 5 passed, 5 total.

$ /Users/alex/code/v/v test .
Summary for all V _test.v files: 193 passed, 193 total.
```
