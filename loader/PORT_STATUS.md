# Loader module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Loader`

Translation workspace: `~/code/vox2/loader`
Audited: 2026-09-12

All six current upstream `.cpp` units and the nine associated headers are
mapped. The port includes the ContentBlocker network/cosmetic rule engine,
download-filename sanitization, file/load request records and fetch metadata,
generated error/directory pages, site-compatibility URL patterns and UA
transformations, frozen UA platform tokens, bad-port/filter checks, HSTS policy
processing, scheme dispatch, response metadata, and active network-load
accounting. The removed ContentFilter, ProxyMappings, and generated version-page
paths have also been removed from the V translation.

Network and embedded-resource I/O are deterministic injected stores in V;
filesystem loads use V's typed OS API. This isolates the translated loader
state machine from Ladybird's process IPC while preserving its observable
dispatch and callback results.

| Upstream implementation unit | V implementation |
| --- | --- |
| `ContentBlocker.cpp` | `content_filter.v` |
| `DownloadFilename.cpp` | `download_filename.v` |
| `FileRequest.cpp` | `load_request.v` |
| `GeneratedPagesLoader.cpp` | `generated_pages_loader.v` |
| `ResourceLoader.cpp` | `resource_loader.v` |
| `SiteCompatibility.cpp` | `site_compatibility.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Loader/` | 6 | 1,291 | 1,921 | 664 | Complete |

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test loader
Summary for all V _test.v files: 6 passed, 6 total.

$ python3 tools/upstream_function_delta.py [...] --json
Loader unmatched added functions: 0
```
