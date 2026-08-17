# Loader module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Loader`

Translation workspace: `~/code/libweb_v/loader`
Audited: 2026-08-16

All five upstream `.cpp` units and the eight associated headers are mapped.
The port includes the compact ASCII matcher and content-filter lifecycle,
file/load request records, generated error/directory/version pages, ordered
proxy wildcard selection, user-agent and navigator compatibility constants,
bad-port/filter checks, scheme dispatch, response metadata, proxy use, and
active network-load accounting.

Network and embedded-resource I/O are deterministic injected stores in V;
filesystem loads use V's typed OS API. This isolates the translated loader
state machine from Ladybird's process IPC while preserving its observable
dispatch and callback results.

| Upstream implementation unit | V implementation |
| --- | --- |
| `ContentFilter.cpp` | `content_filter.v` |
| `FileRequest.cpp` | `load_request.v` |
| `GeneratedPagesLoader.cpp` | `generated_pages_loader.v` |
| `ProxyMappings.cpp` | `proxy_mappings.v` |
| `ResourceLoader.cpp` | `resource_loader.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Loader/` | 5 | 887 | 830 | 292 | Complete |

## Verification

```text
$ /Users/alex/code/v/v test loader
Summary for all V _test.v files: 4 passed, 4 total.

$ /Users/alex/code/v/v fmt -verify loader
(no output; exit status 0)
```
