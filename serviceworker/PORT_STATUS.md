# ServiceWorker module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/ServiceWorker`

Translation workspace: `~/code/vox2/serviceworker`
Audited: 2026-09-12

All eleven upstream implementation units, their headers, and all five IDL files
are represented. The user-agent-owned registration map and job queues live in
`ServiceWorkerAgent`; fetch completion is injected as a typed
`ScriptFetchResult`, preserving the asynchronous host boundary. Wrapper-world
ready promises use the same weak-cache lifecycle boundary as upstream.

| Upstream implementation | V implementation |
| --- | --- |
| `EventNames.cpp`, `ServiceWorkerRecord.cpp`, `ServiceWorker.cpp`, `ServiceWorkerRegistration.cpp` | `types.v` |
| `Registration.cpp` | `registration.v` |
| `Job.cpp` | `jobs.v` |
| `ServiceWorkerContainer.cpp` | `container.v` |
| `ServiceWorkerGlobalScope.cpp` | `global_scope.v` |
| `Cache.cpp`, `CacheStorage.cpp`, `NameToCacheMap.cpp` | `cache_storage.v` |
| `ServiceWorker*.idl`, `Cache.idl`, `CacheStorage.idl` | `types.v`, `container.v`, `global_scope.v`, `cache_storage.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ServiceWorker/` | 11 | 2,608 | 1,562 | 513 | Complete |

The port covers registration keying without fragments, replacement and
unregistration identity, longest-prefix scope matching, newest-worker priority,
24-hour staleness, platform-object snapshots and event handlers, FIFO job
queues, equivalent-job coalescing and shared settlement, origin/trustworthiness
checks, JavaScript MIME, response-origin and `Service-Worker-Allowed` maximum
scope checks, cache-mode timestamps, register/default-scope URL validation,
same-origin `getRegistration`, ordered `getRegistrations`, per-wrapper-world
stable pending `ready`, global-scope event attributes and SameObject cookie-store
identity. Cache and CacheStorage cover ordered named caches, cloned request and
response boundaries, query options, fetch-backed add/addAll, put/delete/keys,
Vary matching, and atomic batch rollback.

Current upstream incomplete behavior remains visible: changed/new scripts reject
at `Run Service Worker`, unregistration rejects as not implemented, and the
IDL-marked controller, messaging, navigation preload, update/unregister and
skipWaiting surfaces are not fabricated. Upstream's FIXME for byte-for-byte
script body comparison is likewise preserved: unchanged URL/type updates resolve
without comparing bodies. A native embedder supplies script
fetch results and can advance activation before polling `ready`.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test serviceworker
Summary for all V _test.v files: 4 passed, 4 total.
```

The March-to-current function delta audit reports zero unmatched added
ServiceWorker definitions.
