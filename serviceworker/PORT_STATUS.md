# ServiceWorker module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/ServiceWorker`

Translation workspace: `~/code/libweb_v/serviceworker`
Audited: 2026-08-16

All nine upstream implementation units, their headers, and all five IDL files
are represented. The user-agent-owned registration map and job queues live in
`ServiceWorkerAgent`; fetch completion is injected as a typed
`ScriptFetchResult`, preserving the asynchronous host boundary without network
or event-loop globals.

| Upstream implementation | V implementation |
| --- | --- |
| `EventNames.cpp`, `ServiceWorkerRecord.cpp`, `ServiceWorker.cpp`, `ServiceWorkerRegistration.cpp` | `types.v` |
| `Registration.cpp` | `registration.v` |
| `Job.cpp` | `jobs.v` |
| `ServiceWorkerContainer.cpp` | `container.v` |
| `ServiceWorkerGlobalScope.cpp` | `global_scope.v` |
| `CacheStorage.cpp` | `cache_storage.v` |
| `ServiceWorker*.idl`, `CacheStorage.idl` | `types.v`, `container.v`, `global_scope.v`, `cache_storage.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ServiceWorker/` | 9 | 1,365 | 842 | 248 | Complete |

The port covers registration keying without fragments, replacement and
unregistration identity, longest-prefix scope matching, newest-worker priority,
24-hour staleness, platform-object snapshots and event handlers, FIFO job
queues, equivalent-job coalescing and shared settlement, origin/trustworthiness
checks, JavaScript MIME, response-origin and `Service-Worker-Allowed` maximum
scope checks, cache-mode timestamps, register/default-scope URL validation, same-origin
`getRegistration`, stable pending `ready`, global-scope event attributes and
SameObject cookie-store identity.

Current upstream incomplete behavior remains visible: changed/new scripts reject
at `Run Service Worker`, unregistration rejects as not implemented,
`CacheStorage.open()`/`has()` reject, and the IDL-marked controller,
getRegistrations, messaging, navigation preload, update/unregister and
skipWaiting surfaces are not fabricated. Upstream's FIXME for byte-for-byte
script body comparison is likewise preserved: unchanged URL/type updates resolve
without comparing bodies. A native embedder supplies script
fetch results and can advance activation before polling `ready`.

## Verification

```text
$ /Users/alex/code/v/v test serviceworker
Summary for all V _test.v files: 3 passed, 3 total.
```
