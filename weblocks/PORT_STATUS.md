# WebLocks port status

| Upstream implementation | V translation |
| --- | --- |
| `AbstractOperations.cpp` | `web_locks.v` |
| `Lock.cpp` | `web_locks.v` |
| `LockManager.cpp` | `web_locks.v` |
| `LockRequest.cpp` | `web_locks.v` |
| `NavigatorLocks.cpp` | `web_locks.v` |

The translated task model keeps the lock task queue distinct from callback
event-loop tasks. Focused tests cover validation, exclusive and shared ordering,
`ifAvailable`, lock stealing, abort signals, state snapshots, callback rejection,
and the per-environment `NavigatorLocks` identity contract.
