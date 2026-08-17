# RequestIdleCallback translation status

Upstream: `Libraries/LibWeb/RequestIdleCallback`

| Upstream unit | V implementation |
| --- | --- |
| `IdleDeadline.cpp` | `idle_deadline.v` |

- Upstream: 1 `.cpp` file, 55 physical LOC.
- V implementation: 36 LOC.
- V tests: 10 LOC in 1 file.
- Status: complete.

The event-loop deadline and relevant-global current time are explicit typed
inputs. Negative remaining time is clamped and positive time is coarsened with
the upstream ceiling behavior.

Verification: `v test requestidlecallback`, `v fmt -verify
requestidlecallback`, and scoped `git diff --check` pass.
