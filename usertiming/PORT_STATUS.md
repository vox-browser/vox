# UserTiming module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/UserTiming`

Both `.cpp` files, both headers, and both WebIDL files were audited. The package
implements immutable mark/measure entries, entry types, infinite buffers,
timeline eligibility, reserved Window timing-name rejection, negative start
validation, default high-resolution time injection, duration, and cloned detail
values represented as owned V strings.

| Upstream source | V implementation |
| --- | --- |
| `PerformanceMark.cpp` | `user_timing.v` |
| `PerformanceMeasure.cpp` | `user_timing.v` |

| Upstream area | `.cpp` files | Upstream `.cpp` LOC | V implementation LOC | V test LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `UserTiming/` | 2 | 164 | 89 | 29 | Complete |

The associated declarations comprise 2 headers / 114 LOC and 2 IDL files / 29
LOC. Mapping completeness is 2/2 implementation units, 2/2 headers, and 2/2
IDL definitions audited.

JS structured serialization and realm/GC ownership remain the binding boundary;
the translated values preserve independent owned detail data.

Verification: `v test usertiming` passes 1/1; formatting and diff checks pass.
