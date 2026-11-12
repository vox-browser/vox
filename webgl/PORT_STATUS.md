# WebGL module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebGL`

Reference audit: 2026-09-12
Latest native focused verification: 2026-10-05

Direct Metal migration started on 2026-11-12 in the independent `webgl.metal`
package. Its device/queue/private drawing-buffer, GPU clear and bounded pixel
transfer slice passes native ARC/MRC/sanitizer checks and three V cases per GC
mode without ANGLE dependencies. ESSL 1.00/3.00 shader pairs now validate/link,
lower through SPIR-V/MSL, and compile as actual Metal functions; resource names
and uniform/matrix layouts have focused coverage in both GC modes. Browser
dispatch is not migrated. Initialized GPU buffers, bounded vertex streams,
float/matrix uniforms and array/instanced draws now have exact Metal pixel
coverage, including asymmetric GL row orientation. Base-level RGBA8 textures,
nearest/linear samplers, wrapping and offscreen color targets have exact-pixel
and feedback/ownership checks. Indexed draws/restart, viewport/scissor, color
masks/blending, depth and separate stencil faces now have focused exact-pixel
coverage in both GC modes. Typed/normalized/constant vertex fetch is covered;
the standalone suite passes six native fixtures in three ownership/sanitizer
modes and 27 V cases in both GC modes. Explicit attribute locations, matrix columns
and inactive resource reflection are covered. Typed uniforms, packed readback, padded arrays
and external uniform-buffer ranges are included;
the production WebGL implementation still uses ANGLE. See the
[migration status and next slices](../docs/WEBGL_METAL_MIGRATION.md).

The [native getParameter string-cache correction](../docs/translation-audit/WEBGL_PARAMETER_STRING_CACHE.md)
(`b1b05829`) connects the Source per-GL-enum cache to the actual direct-driver
path. Standard strings and unmasked aliases share owned entries; warm reads
preserve the other current driver, cached strings survive loss, cold lost
queries return empty, and restore clears the cache. Genuine native/public
checks pass 6/6 files with GC disabled and 8/8 with default GC. These focused
results postdate the frozen native bundle and retain the documented remote
transport, string conversion and realm/wrapper/GC boundaries.

After the Source viewport/scissor, driver-receiver, blend/clear/raster/stencil,
generic-map and pixel-store slices, plus exceptional-number compatibility
transport, frozen private snapshot `4ef932b1ba72801a4eeec6102ccd97258552bf92`
passed all 109 tracked typed WebGL files (131.6 seconds) and all 79 tracked
public/mixed canvas files (713.0 seconds), with zero failures, GC disabled and
explicit private module paths. Both exact manifests, snapshot, TSV results,
sweep logs and individual logs are under
`Build/audit-fixes/webgl-final-4ef932b1/`. The public manifest includes every
browserjs/canvas_webgl test plus canvas_context_integration. Both groups checked
the clean tracked revision before and after execution, and no tracked state
changed while either ran.

This clean frozen result does not establish unexamined Source parity. The
read-only genuine inherited-discriminator probe after that snapshot reproduced
a further numeric adapter defect; it remains in
`Build/audit-fixes/source-number-discriminator-probe.{v,log}`. Its separately
reviewed followup is developed and focused-tested in another private worktree,
so the 109/79 sweep has only the original snapshot's scope. Other non-Source
vertex/capability mirrors, unexamined entry-point bodies, full Source GC and
WrapperWorld, remote transport and pinned Source TODOs remain explicit work.

After nullable/bitmap/readback continuation and actual-driver error-retention
repairs, frozen private snapshot `2355ee46` passed all 101 tracked typed WebGL
files (132.5 seconds) and all 70 public/mixed canvas files (1006.2 seconds) with
GC disabled and explicit private module paths. Both sweeps were clean; exact
snapshot, manifests, TSV results and per-file logs are under
`Build/audit-fixes/webgl-final-2355ee46/`. The public manifest contains every
browserjs/canvas_webgl test and canvas_context_integration. No tracked state
changed while either sweep ran. These passes cover the driver repair below;
they do not establish unexamined source-body parity. At that snapshot, a separate read-only
viewport/scissor probe observed wrong owner selection on negative sizes
and a native viewport cache retaining rejected dimensions. Its genuine-driver
source/log are `Build/audit-fixes/source-viewport-scissor-owner-probe.{v,log}`;
the subsequently completed Source raster slices below are covered by the
newer 4ef932b1 sweep. Full GC/WrapperWorld and remote transport remain separate
work.

After framebuffer/query/sync/actual-record and source draw/canvas callback
repairs, frozen private snapshot `2ad0138f` passed all 97 tracked typed WebGL
files (58.0 seconds) and all 66 public/mixed canvas files (353.4 seconds) with
GC disabled and explicit private module paths on 2026-10-04. The latter manifest
contains every browserjs/canvas_webgl test plus canvas_context_integration.
Exact manifests, snapshot hash, TSV results and per-file logs are under
`Build/audit-fixes/webgl-final-2ad0138f/`; no fixtures failed in either sweep.
Separate focused HTML canvas repaint/surface checks are documented below.
These complete test passes do not establish unexamined source-body parity.
A separate genuine two-native-error probe after the freeze reproduced a
adapter error loss/order mismatch: direct driver errors [1280,1281,0]
versus translated [1281,0,0]. Its source/log are retained as
`Build/audit-fixes/source-native-error-retention-probe.{v,log}`. The actual driver
error boundary was subsequently repaired at `2355ee46`: the identical probe
now returns [1280,1281,0] through both paths, recorded in
`source-native-error-retention-probe-fixed.log`. Non-source raster caches/gates,
full GC/WrapperWorld and remote transport remain work; the pinned source's
single m_error TODO is distinct from this repaired loss of actual GL errors.

After the shader/resource/uniform repairs, frozen private snapshot `ea1e2287`
passed all 50 public/mixed canvas files with GC disabled and explicit private
module paths. Its typed sweep passed 80/81 files; `native_uniform_test.v` alone
retained an obsolete assertion that transpose=true must report INVALID_VALUE.
The actual ANGLE command returned NO_ERROR, as permitted by the pinned source's
unconditional transpose forwarding. That fixture was migrated in a separate
test-only commit to compare the direct driver's error and matrix readback after
resetting both paths to zero. The failed file and new source matrix neighbor
then passed in `source-matrix-legacy-readback-gc-none.log` (two files). This is
the frozen 80-file pass plus the corrected focused file, not a new clean
81-file sweep. Original manifests, TSV results, per-file logs and the initial
failure remain under `Build/audit-fixes/webgl-final-ea1e2287/`; the public
50-file sweep used the unchanged implementation. Source TODO, remote transport
and full VM/WrapperWorld boundaries remain.

After source buffer/retained-slot/intrinsic and texture repairs, frozen private
snapshot `13d3c7d3` passed all 73 typed WebGL files and all 43 public/mixed canvas
files with GC disabled and explicit private module paths on 2026-10-04.
The exact manifests, TSV results and per-file logs are under
`Build/audit-fixes/webgl-final-13d3c7d3/`. No obsolete fixture failures occurred.
The initial V test runner removed shell quoting from the module path's pipe
separators and failed before compilation; its diagnostic is preserved there.
The completed sweeps use direct per-file argument-vector invocations, keeping
module-path separators out of shell interpretation. These tests preserve the
remaining source TODO, remote transport and full VM/WrapperWorld boundaries.

After the shared native query/reflection repairs, the full typed package passed
58/58 files and the complete public/mixed canvas group passed 29/29 files with
GC disabled against snapshot `69881821`. Exact manifests, results, and per-file
logs are under `Build/audit-fixes/webgl-final-69881821/`. The sweep required no
further fixture changes; the deliberate source migrations described below are
included in that snapshot.

After the XR Promise/owning-context installation changes, all 24 public
`browserjs/canvas_webgl*_test.v` files plus the mixed 2D/WebGL context file
passed with GC disabled against snapshot `70dbaa51` (25/25 files). The exact
manifest, individual logs, and results are under
`Build/audit-fixes/webgl-xr-70dbaa51/`. This supplements the prior complete
53-file typed-package and 22-file public sweep; no obsolete fixtures were found.

All 42 upstream `.cpp` implementation units, 46 headers, and 37 WebIDL files
were audited. The package implements the renderer-independent WebGL 1/2 model:
context attributes and loss, drawing-buffer lifecycle, first-error retention,
context-bound resource ownership, buffer target compatibility and byte ranges,
shader/program/link state, uniform ownership, extension filtering/caching,
compressed formats, WebGL2 queries/samplers/sync/transform-feedback/VAOs,
instanced drawing, checked BufferSource offsets, timestamped context events,
framebuffer attachments, remote-context restoration, aligned command encoding,
shared-buffer batching, bitmap uploads, readback, and synchronous proxy queries.
The complete 53-entry upstream extension registry is retained, including
experimental entries whose factories are not implemented; those names are
filtered by version/native support and correctly remain non-instantiable.

| Upstream area | `.cpp` files | Upstream `.cpp` LOC | V implementation LOC | V test LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `WebGL/` | 42 | 7,846 | 6,205 | 1,470 | Source mapping retained; native direct backend connected; remote transport open |

The associated declarations comprise 46 headers / 2,473 LOC and 37 IDL files /
1,403 LOC. Mapping completeness is 42/42 implementation units, 46/46 headers,
and 37/37 IDL definitions audited.

## Implementation-unit mapping

| Upstream implementation | V implementation |
| --- | --- |
| `EventNames.cpp`, `WebGLContextAttributes.cpp`, `WebGLContextEvent.cpp`, `WebGLActiveInfo.cpp`, `WebGLShaderPrecisionFormat.cpp` | `types.v` |
| `WebGLObject.cpp`, `WebGLBuffer.cpp`, `WebGLFramebuffer.cpp`, `WebGLProgram.cpp`, `WebGLQuery.cpp`, `WebGLRenderbuffer.cpp`, `WebGLSampler.cpp`, `WebGLShader.cpp`, `WebGLSync.cpp`, `WebGLTexture.cpp`, `WebGLTransformFeedback.cpp`, `WebGLUniformLocation.cpp`, `WebGLVertexArrayObject.cpp` | `objects.v`, `object_factories.v`, owning context file |
| `TextureUpload.cpp` | `texture_upload.v` |
| `WebGLCommandList.cpp` | `command_list.v` |
| `WebGLContextProxyBase.cpp` | `context_proxy.v`, `shared_command_buffer.v` |
| `WebGLRenderingContext.cpp`, `WebGLRenderingContextBase.cpp`, `WebGLRenderingContextImpl.cpp`, `WebGLRenderingContextOverloads.cpp` | `buffer_source.v`, `context.v`, `context_operations.v`, `extensions.v`, `native_context.v`, `overload_operations.v`, `remote_context.v`, `texture_image_source.v` |
| `WebGL2RenderingContext.cpp`, `WebGL2RenderingContextImpl.cpp`, `WebGL2RenderingContextOverloads.cpp` | `context2.v`, `context.v`, `context_operations.v`, `native_context.v`, `overload_operations.v` |
| `Extensions/ANGLEInstancedArrays.cpp`, `EXTBlendMinMax.cpp`, `EXTColorBufferFloat.cpp`, `EXTRenderSnorm.cpp`, `EXTTextureFilterAnisotropic.cpp`, `EXTTextureNorm16.cpp`, `OESElementIndexUint.cpp`, `OESStandardDerivatives.cpp`, `OESVertexArrayObject.cpp`, `WebGLCompressedTextureS3tc.cpp`, `WebGLCompressedTextureS3tcSrgb.cpp`, `WebGLDebugRendererInfo.cpp`, `WebGLDrawBuffers.cpp`, `WebGLVertexArrayObjectOES.cpp` | `extensions.v`, `context2.v`, `objects.v` |

## Native backend and remaining work

The new full typed regression at frozen canonical snapshot
`e93aaa7b72e56a90f71636efb2be6c3c58113b56` passed 120/121 tracked WebGL files
in 238.198 seconds with GC disabled and explicit frozen module paths. All
4,444 tracked files, HEAD/tree, index records, content/modes and diffs were
hashed before/after and unchanged. Exact manifest, per-file logs, TSV results,
snapshots and summary are under `Build/audit-fixes/webgl-final-e93aaa7b/` in
the separate clean `08-webgl-e93aaa7b` checkout. The sole failure was the old
native_query_owner_selection fixture's blanket native-owner expectation after
getRenderbufferParameter's correct unknown-name early return. The same fixture
also held that obsolete expectation for getTexParameter(unknown) and
getAttribLocation(foreign).

Only those three separately Source-reviewed expectations were migrated in a
test-only commit in `08-protocol-followup`; the failed file then passed with
GC disabled in `Build/audit-fixes/source-query-owner-legacy-reviewed-gc-none.log`
(2.2 seconds). Other historical cases remain scoped to their separate Source
method reviews. This is frozen 120/121 plus one corrected focused file; the
original sweep remains 120/121 and is not relabeled a clean 121-file pass.
The same unchanged frozen checkout passed all 91 public/mixed canvas files in
720.444 seconds. Exact manifests, result/log hashes, whole-checkout identity,
the archived missing-libregex attempt and copied dependency provenance are
recorded in [the frozen regression record](../docs/translation-audit/WEBGL_FROZEN_E93AAA7B.md).
This public pass retains the frozen canonical revision regardless of subsequent
private fixes.

getUniformLocation now suppresses its generated synchronous driver call after
loss and preserves the exact Source scalar default and fresh owned record.
GLFunctions.json:2576-2590 identifies a GLint sync return; generated proxy
calls send_sync_call, then returns GLint{} when is_lost. ProxyBase.cpp:168-176
does not send while lost. Impl.cpp:2018-2023 tests only location == -1, so that
generated zero produces a new actual parent-program location record even for
missing/reserved names after loss. V guards only the C query and chooses zero
on the lost branch, then runs that existing exact null gate/fresh constructor.
The read-only generated sync witness is
`Build/audit-fixes/source-uniform-location-generated-boundary.txt`, SHA-256
`5e7d412496bb517eb5d4e31f7999dd873b9f2ab0da9c09c64d1721cda21e55e7`.
This matches the pinned upstream boundary; null or -1 would invent a loss rule.

The genuine pre-fix EGL probe queried Other's coinciding native program and
returned its actual positive location 1 through lost Owner, retained in
source-uniform-location-unfixed-probe_test.v and
source-uniform-location-unfixed-probe-gc-none.log. New two-version typed/public
cases use independently queried active locations and actual uniform values in
Other's compiled/bound program. Original and owned SourceID2/native0 programs
now yield different records/public wrappers storing zero for active, missing
and reserved names, with the actual parent retained. Existing context-identity
relevant-global adaptation continues through that actual parent. Deleting
that parent still leaves earlier location records retaining its pointer and
exact optional-pointer handle validation. Foreign/deleted program gates and
public arity/nonnullable/forged-brand/Symbol errors still return before the
sync/factory path; name author conversion still executes before the body.
These records consume compact host wrapper IDs and do not consume Source proxy
object IDs: the next generated owned program remains SourceID3/native0.

Two typed files pass in
`Build/audit-fixes/source-uniform-location-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-uniform-location-lost-public-gc-none.log`, with GC
disabled and explicit private paths, including live/CPU-order/driver-location
neighbors. Other's actual current binding, viewport, linked/live/attachment
state, uniform values and pending INVALID_ENUM remain intact, with no extra
zero-name native error; context-loss reporting stays one-shot. This is only
the Source getter/default/record boundary, not a new uniform-read algorithm.
Other getter and uniform-setter lost outputs, retained getter owner order,
other families, full remote transport and GC/WrapperWorld remain separate.
Historical full-sweep and canonical bundle evidence are unchanged.

getUniformLocation now preserves its Source owned-program handle gate before
actual native owner selection, with the exact location == -1 null-return gate.
Impl.cpp:2003-2023 has an empty Proxy make_current prefix, validates the handle,
then obtains the exact native location and creates a fresh record for any
result other than -1. V moves native selection below that handle gate and
matches the exact comparison while keeping native-name forwarding and existing
actual parent-program/fresh-record construction. UniformLocation.cpp:21-35
and :41-51 retain the parent and derive the relevant global/handle validation
from that actual pointer; no link-status, current-binding or name cache gate
is added.

The genuine pre-fix foreign-program probe selected Owner rather than current
Other, retained in source-uniform-location-unfixed-probe_test.v and
source-uniform-location-unfixed-probe-gc-none.log. New two-version typed/public
cases preserve Other's selected viewport and pending INVALID_ENUM on foreign/
invalidated program gates. Public arity/nonnullable/forged-brand/Symbol errors
stay before body dispatch; name author conversion still occurs before a valid
foreign wrapper's Source handle gate. Real compiled programs supply exact
active uniform locations, including embedded-NUL name truncation. Repeated
queries yield different actual records/public wrappers sharing the driver
value and actual owning parent/global. Missing and reserved names return null
through the real -1 result, while a directly queried unlinked program supplies
an independent driver-error baseline; no invented eager link check is used.

The initial typed attempt failed before execution on an immutable V array
literal in the new fixture; its complete log remains in
`Build/audit-fixes/source-uniform-location-owner-native-gc-none.log`.
After correcting only that fixture declaration, both typed files pass in
`Build/audit-fixes/source-uniform-location-owner-native-corrected-gc-none.log`.
Both public files pass unchanged in
`Build/audit-fixes/source-uniform-location-owner-public-gc-none.log`, with GC
disabled and explicit private paths, including existing fresh location/link
neighbors. No historical owner assertion required migration. Generated lost
scalar/default and fresh location construction are separately reviewed above;
retained getter order, other families, full remote transport and GC/WrapperWorld
remain boundaries. Frozen full-sweep and canonical bundle evidence are unchanged.

bindAttribLocation now suppresses its generated native command after loss,
separately from the program-handle CPU gate repair. Impl.cpp:180-192 and
GLFunctions.json:58-76 record the actual index/null-terminated name and Source
program ID; record_bytes:57-60 drops the generated record after loss. V keeps
its handle gate, then returns before its direct C command when native owner
selection is unavailable. The exact read-only generated proxy/replay witness
is `Build/audit-fixes/source-bind-attrib-generated-boundary.txt`, SHA-256
`3a2f81f6ed8eaf6ff3c56adf3f8e4f8954583351a34ec328a65c34fe65b414ea`.

The genuine pre-fix EGL probe changed Other's pending attribute binding from
2 to 6 through a lost Owner with coinciding native program names, retained in
source-bind-attrib-unfixed-probe_test.v and
source-bind-attrib-unfixed-probe-gc-none.log. New two-version typed/public
cases relink Other's genuinely compiled program after every lost binding and
query its actual location, so a later rebind cannot hide transient wrong GL
work. The location remains 2, both real attachments remain and the actual
program stays linked/live in Other's unchanged viewport. Original and owned
SourceID2/native0 records retain identity; foreign/deleted handles and public
arity/nonnullable/forged-brand/Symbol gates retain Source behavior. Public
index/name author conversions still execute in order before the dropped body
command. Embedded-NUL and reserved-prefix names cannot mutate Other; its
pending INVALID_ENUM survives without extra native errors, public setters
remain undefined, and context-loss reporting remains one-shot.

Two typed files pass in
`Build/audit-fixes/source-bind-attrib-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-bind-attrib-lost-public-gc-none.log`, with GC disabled
and explicit private paths, including the prior live/CPU-order/actual driver
location neighbors. This is only the reviewed bindAttribLocation loss slice;
getUniformLocation and retained getter owner order, other families, full
remote transport and GC/WrapperWorld remain separate. Frozen full-sweep and
canonical bundle evidence remain unchanged.

bindAttribLocation now preserves its Source owned-program handle gate before
actual native owner selection. Impl.cpp:180-192 begins with an empty Proxy
make_current, validates the handle, converts its already-converted name to
null-terminated UTF-8, and records the exact GLuint-index/name command. V moves
only native selection below the Source gate and retains native-name forwarding
and the actual driver call, without adding a reserved-name or index-error gate.

The genuine pre-fix foreign-program probe switched current Other to Owner,
retained in source-bind-attrib-unfixed-probe_test.v and
source-bind-attrib-unfixed-probe-gc-none.log. New two-version typed/public
cases keep Other selected and preserve pending INVALID_ENUM on foreign/deleted
programs. Public arity, nonnullable, forged-brand and Symbol conversion errors
stay before body dispatch; actual index/name author conversions remain ordered
before a valid wrapper's foreign-handle body gate. Compiled shader programs
linked in the real driver expose requested attribute locations 3 and 5,
including a name truncated at its embedded NUL exactly as the Source C string.
Direct driver calls supply independent invalid-index/reserved-name errors;
translated valid-handle calls select Owner and preserve those actual errors,
with retained shader identities unchanged.

Only one typed and one public historical foreign binding owner expectation
were migrated. The typed independent baseline now explicitly selects its
actual owner before its direct GL call instead of depending on that incorrect
foreign-gate side effect. Two typed files pass in
`Build/audit-fixes/source-bind-attrib-owner-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-bind-attrib-owner-public-gc-none.log`, with GC disabled
and explicit private paths, including the aggregate shader/program neighbors.
Lost binding is separately reviewed above; location/retained getter and other
object families, full remote transport and GC/WrapperWorld remain distinct
scopes. Historical full-sweep and canonical bundle evidence are unchanged.

detachShader now drops its generated native command after loss and still
clears Source's corresponding actual retained shader slot. Impl.cpp:669-679
performs that CPU clear after the proxy call, even when record_bytes:57-60
discards the command. GLFunctions.json:1205-1219 and generated proxy/replay
carry program/shader Source IDs and resolve both live native names. V guards
only the C detach call after valid CPU gates/owner selection, then always
performs the pinned type-slot clear. The exact generated read-only witness is
`Build/audit-fixes/source-detach-shader-generated-boundary.txt`, SHA-256
`feab6f1218c40c338b562dd5dc27ce0515ab0b0d2151d88d932afdd9f215b072`.

The genuine pre-fix EGL probe removed Other's actual shader attachment through
a lost Owner (one to zero attachments), retained in
source-detach-shader-unfixed-probe_test.v and
source-detach-shader-unfixed-probe-gc-none.log. New two-version typed/public
cases preserve both of Other's real attachments, viewport, shader compile/
delete state, program delete state and pending INVALID_ENUM after every call.
Original and post-loss SourceID5/6/7-native0 records retain their actual identity;
valid dropped detach commands clear only the matching Source slot, including
an owned shader that was never attached and repeated calls on empty slots.
Foreign/invalidated handles and public arity/nonnullable/forged-brand gates
keep prior slots unchanged. In particular, invalidating a retained shader
keeps its actual reference/wrapper in the Source collection until a different
valid typed shader clears that slot. Public arrays remain fresh and retain the
remaining fragment wrapper. No invented driver-success or retained-slot gate
is added; context-loss reporting stays one-shot without extra native errors.

Two typed files pass in
`Build/audit-fixes/source-detach-shader-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-detach-shader-lost-public-gc-none.log`, with GC disabled
and explicit private paths, including the prior live/CPU-order/native rejection
neighbors. This is detachShader's exact command-drop/retained-clear boundary;
bind/location, other bodies/object families, full remote transport and
GC/WrapperWorld remain independent scopes. Frozen full-sweep and canonical
bundle verification are unchanged.

detachShader now keeps its exact Source program/shader handle gates ahead of
actual native owner selection. Impl.cpp:651-680 prefixes the body with an
empty Proxy make_current, validates both handles, records the command, and
then clears the shader-type retained slot unconditionally. V now selects the
owner only at that genuine command boundary. Native-name forwarding, lack of
an added retained-slot/attachment success gate, and the post-command clear
remain unchanged.

The genuine pre-fix foreign-shader probe selected Owner rather than current
Other, retained in source-detach-shader-unfixed-probe_test.v and
source-detach-shader-unfixed-probe-gc-none.log. New two-version typed/public
cases keep Other selected with its pending INVALID_ENUM on foreign/deleted
shader and foreign/deleted program gates. Public arity, nonnullable and
forged-brand conversion errors likewise stay before body dispatch. An owned
unattached shader supplies an independent actual driver rejection baseline:
translated detach selects Owner, preserves that driver error and actual two
attachments, yet clears Source's corresponding vertex slot. The genuinely
attached vertex can subsequently detach despite that already-cleared Source
slot. Successful calls preserve actual attachment counts and the remaining
fragment's public wrapper identity until both attachments are removed.

Two typed files pass in
`Build/audit-fixes/source-detach-shader-owner-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-detach-shader-owner-public-gc-none.log`, with GC disabled
and explicit private paths, including existing rejection/order neighbors.
No historical fixture required migration. Lost detachment is separately reviewed
above; bind/location, other bodies/object families,
full remote transport and GC/WrapperWorld remain source-reviewed scopes.
Frozen full-sweep and canonical bundle evidence remain unchanged.

attachShader now suppresses its generated native command after context loss
while still assigning the actual retained shader slot after that command.
Impl.cpp:166-177 calls the proxy and then writes the type-specific actual
pointer. GLFunctions.json:14-28 and generated proxy/replay carry separate
Source program/shader object IDs; record_bytes:57-60 drops the record after
loss. V conditionally performs only its native C attach call, then runs the
existing exact retained assignment. It must not return early after detecting
lost native selection. The generated read-only witness is
`Build/audit-fixes/source-attach-shader-generated-boundary.txt`, SHA-256
`e4fa7cb703222b0336371c32a543ca72911bf81e99c62bb6e37824b39753e652`.

A genuine pre-fix EGL probe attached Other's shader to Other's program through
a lost Owner with coinciding native names (actual count zero to one), retained
in source-attach-shader-lost-unfixed-probe_test.v and
source-attach-shader-lost-unfixed-probe-gc-none.log. New two-version typed/
public cases check Other's actual ATTACHED_SHADERS, zero current program,
viewport, shader compile/delete state and program delete state after every
lost call. Original and owned unmapped SourceID4/5/6 records retain ordered
actual shader pointers and public wrapper identities after the dropped calls;
Source IDs remain distinct from native zero mapping. Duplicate/type-slot,
foreign/deleted-handle and public arity/nonnullable/forged-brand gates remain
before dispatch. Deleting a retained shader after loss still leaves its actual
reference and public wrapper accessible through the retained collection.
Other's pending INVALID_ENUM survives without an extra native error, setters
remain undefined, and context-loss reporting stays one-shot.

Two typed files pass in
`Build/audit-fixes/source-attach-shader-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-attach-shader-lost-public-gc-none.log`, with GC disabled
and explicit private paths, including the preceding live CPU-order/native
rejection neighbors. This is attachShader's exact command-drop/retention
slice. Detach/bind/location and other program bodies, object families, full
remote transport and GC/WrapperWorld remain separately source-reviewed work.
Historical full sweeps and canonical bundle evidence remain unchanged.

attachShader now preserves the exact Source program/shader handle, actual
retained-pointer duplicate, and occupied shader-type gates before selecting
its native owner. Impl.cpp:129-178 begins with an empty Proxy make_current;
only the generated attachment command reaches the actual owning host driver.
The previously missing actual duplicate-pointer gate is restored in its
Source position before the per-type occupied-slot checks. Program.h:25-29
retains actual shader pointers, Program.cpp:32-37 visits both slots, and
Impl.cpp:867-888 returns a fresh rooted vector in vertex/fragment order.
Existing V actual references and public pointer-to-wrapper identity are
preserved; no fabricated attachment cache or native success gate is added.

The genuine pre-fix duplicate attachment probe switched current Other to
Owner, retained in source-attach-shader-owner-unfixed-probe_test.v and
source-attach-shader-owner-unfixed-probe-gc-none.log. New two-version typed/
public cases preserve Other and its pending INVALID_ENUM on foreign/deleted
handles, duplicate pointers and occupied shader types. Public arity, nonnullable
and forged-brand errors remain before body dispatch. Live calls select Owner
and produce two actual glGetAttachedShaders names while Source returns fresh
arrays of the original ordered shader wrappers. A real Program.h setter record
retaining a fragment pointer in the vertex slot checks the distinct duplicate
gate against an actual driver with zero attachments. Native program deletion
outside V supplies an independent driver rejection baseline: Source still
retains the actual shader after that rejected attachment command.

Only two typed and two public historical attachment-owner assertions were
migrated. Three typed files pass in
`Build/audit-fixes/source-attach-shader-owner-native-gc-none.log`; three public
files pass in
`Build/audit-fixes/source-attach-shader-owner-public-gc-none.log`, with GC disabled
and explicit private paths, including existing actual retained/deleted shader
and wrapper identity neighbors. This supersedes only the reviewed owner
assumptions and does not replace frozen full-sweep evidence. Lost attachment
is separately reviewed above; other
program bodies, object families, full remote transport and GC/WrapperWorld
remain separate. Canonical bundle evidence is unchanged.

useProgram now drops its native command after loss while still assigning
Source's retained current-program pointer. Impl.cpp:2482-2483 calls the proxy
and then assigns m_current_program even when record_bytes:57-60 drops that
command. GLFunctions.json:4393-4402 and generated proxy/replay resolve the
Source object ID for the live call. V conditionally executes only the C call
when actual owner selection succeeds, then performs its existing retained
assignment/metadata path. An early function return would lose the required
null and owned-record assignments after a dropped command. CPU invalid-handle
gates remain before that path. The exact read-only generated witness is
`Build/audit-fixes/source-use-program-generated-boundary.txt`, SHA-256
`dc4975d70715f0350249e56581443e2e42c752c00f6373ab036315d530638289`.

A genuine pre-fix EGL probe unbound Other's active native program through a
lost Owner's useProgram(null), retained in
source-use-program-lost-unfixed-probe_test.v and
source-use-program-lost-unfixed-probe-gc-none.log. New two-version typed/public
cases check Other's real CURRENT_PROGRAM, viewport, linked/live state and
DELETE_STATUS after every lost call so a later rebind cannot hide transient
wrong driver work. Null/undefined still assign Source null; original and owned
SourceID2/native0 records still become Source current records. Foreign,
invalidated, public arity and forged-brand gates preserve the prior retained
record. Public CURRENT_PROGRAM returns the same actual wrapper identities
through the pinned CPU retained-pointer branch. Other's pending INVALID_ENUM
survives without additional native errors, public setters stay undefined and
loss reporting remains one-shot.

Two typed files pass in
`Build/audit-fixes/source-use-program-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-use-program-lost-public-gc-none.log`, using GC disabled
and explicit private paths, including the live/CPU-order/driver-rejection
neighbors. Source identity and zero native mapping stay distinct. This is only
useProgram's loss/retained-assignment boundary; attach/detach/bind/location,
other object families, retained getter owner order, full remote transport and
GC/WrapperWorld remain separate. Frozen full-sweep and canonical bundle
evidence are unchanged.

useProgram now keeps its optional Source owned-handle validation ahead of
actual native owner selection. Pinned Impl.cpp:2468-2484 prefixes the body
with an empty Proxy make_current, validates a present program, then records
use_program and assigns its retained current pointer. Null has no early body
return: it dispatches native program zero and clears the retained slot. V now
selects its native owner only after validating a present handle, preserving
that exact null/live order, native-name forwarding and post-command assignment.

The genuine pre-fix foreign-program probe switched current Other to Owner,
retained in source-use-program-owner-unfixed-probe_test.v and
source-use-program-owner-unfixed-probe-gc-none.log. New two-version typed/public
cases preserve Other's current viewport and pending actual INVALID_ENUM for
foreign and invalidated records, while Source's prior current pointer remains
unchanged. Public arity/forged-brand errors remain before dispatch. Actual
null/undefined calls still select Owner, unbind its real current program and
return a null retained query. Live linked programs still bind their actual
native names. A directly rejected unlinked driver program supplies an
independent error baseline: the translated call preserves that real error and
actual previous native binding, yet assigns Source's rejected record exactly
as pinned. No fabricated link-status success gate is added.

Two typed files pass in
`Build/audit-fixes/source-use-program-owner-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-use-program-owner-public-gc-none.log`, using GC disabled
and explicit private paths, including existing retained-current-program
neighbors. No legacy assertion required migration in this slice. Lost use is separately reviewed above;
other program bodies/object families, the separate retained getter's native
owner order, full remote transport and GC/WrapperWorld remain distinct scopes.
Historical full regressions and canonical bundle evidence remain unchanged.

validateProgram now suppresses its generated native command after loss,
separately from the CPU owned-handle order repair. Impl.cpp:2486-2497 and
GLFunctions.json:4405-4414 record ValidateProgram with its Source object ID;
record_bytes:57-60 drops the command after loss. V preserves validation,
then returns before direct C work when actual owner selection is unavailable.
The exact live call and native-name ABI remain unchanged. The read-only
generated proxy/replay witness is
`Build/audit-fixes/source-validate-program-generated-boundary.txt`, SHA-256
`a653eb475a7e05b71ee91098eaa52882d8f09a5bd77abebec4dcbfe7c9843f0a`.

A genuine pre-fix EGL probe validated Other's matching native program through
a lost Owner (VALIDATE_STATUS=0 to 1), retained in
source-validate-program-lost-unfixed-probe_test.v and
source-validate-program-lost-unfixed-probe-gc-none.log. New two-version native/
public tests use a separate actual program validated directly in the driver
as a working baseline, while Other's sentinel remains unvalidated after loss.
Other keeps LINK_STATUS=1, its two compiled attachments, native current program
zero, current viewport and pending INVALID_ENUM without an extra zero-name
error. Owner's original and owned SourceID2/native0 records stay valid with
identity fields unchanged. Public arity/nonnullable/forged-brand and foreign
handle gates retain their Source behavior, setters stay undefined, and loss
reporting remains one-shot.

Two typed files pass in
`Build/audit-fixes/source-validate-program-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-validate-program-lost-public-gc-none.log`, using GC
disabled and explicit private paths, including the independent live/CPU-order
neighbors. This is validateProgram's reviewed command-drop boundary, not an
invented validation algorithm or broader generic loss policy. Other program
bodies, object families, full remote transport and GC/WrapperWorld remain
separate scopes; no frozen full-sweep or canonical bundle claim is added.

validateProgram now keeps its Source owned-handle gate before actual native
owner selection. Impl.cpp:2486-2497 has an empty proxy make_current prefix,
then validates program->handle(this) before the exact validate command.
V now selects its actual owner only after that gate, retaining the original
unsigned native name ABI and direct driver validation operation. Foreign and
invalidated records do not switch current Other or consume its pending errors.
Public arity, nonnullable and forged-brand errors remain before Source entry.

New two-version typed/public checks compare a separately linked actual program
validated directly through C with the translated program's genuine
VALIDATE_STATUS=0 to 1 transition. Successful Source calls select Owner and
match that independent driver baseline. A native program deleted outside V
also confirms valid Source records still select Owner, forward the actual
native name, and preserve the real driver rejection. No fabricated CPU
validation status or eager cache supplies these results.

Only the old typed foreign validateProgram owner expectation and its matching
public aggregate entry were migrated. Two typed files pass in
`Build/audit-fixes/source-validate-program-owner-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-validate-program-owner-public-gc-none.log`, using
GC disabled and explicit private paths. This supersedes only those historical
owner assumptions and does not replace frozen full regression evidence.
Lost validation and useProgram CPU gates are separately reviewed above;
attach/detach/bind/location and other program bodies, object families and full remote transport/
GC/WrapperWorld remain independent source-reviewed scopes.

linkProgram now drops its generated native command after loss, separately
from its CPU owned-handle ordering correction. Pinned Impl.cpp:2233-2244
records only the exact link command; GLFunctions.json:2885-2894 identifies
its program object ID, generated proxy record and compositor native lookup.
record_bytes:57-60 suppresses that command after loss. V retains CPU validation,
then returns before C linking/metadata dispatch when actual owner selection is
unavailable. No fabricated link status/cache or error algorithm is introduced.
The read-only generated proxy/replay witness is
`Build/audit-fixes/source-link-program-generated-boundary.txt`, SHA-256
`a2a5fdf5c191288f7bc5df30f2d2fb5e480c69814877e9dd3a05200a8d21739a`.

A genuine pre-fix EGL probe linked Other's matching native program through a
lost Owner (LINK_STATUS=0 to 1), retained in
source-link-program-lost-unfixed-probe_test.v and
source-link-program-lost-unfixed-probe-gc-none.log. Corrected two-version typed/
public tests keep Other's program genuinely unlinked, while its two compiled
attachments remain intact. Lost Owner's original and owned SourceID2/native0
records stay valid with their identity fields unchanged; foreign handle and
public arity/nonnullable/forged-brand gates stay effective. Other's native
CURRENT_PROGRAM=0, viewport and pending INVALID_ENUM survive without an extra
zero-name error; loss reporting remains one-shot and public setters undefined.

Two typed files pass in
`Build/audit-fixes/source-link-program-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-link-program-lost-public-gc-none.log`, with GC disabled
and explicit private paths. Existing live linking, CPU-order and actual native
rejection neighbors remain included. This method-specific command drop does
not establish remaining program mutation/is-object/getParameter parity, full
remote transport or GC/WrapperWorld, and does not replace frozen sweep proof.

linkProgram now keeps its Source owned-handle gate ahead of actual native
owner selection. Impl.cpp:2233-2244 prefixes the body with an empty proxy
make_current, validates program->handle(this), and only then records its GL
command. V no longer switches driver owner for foreign or invalidated program
records. Valid owned calls retain the exact native-name link operation and
metadata order, with no fabricated status/error/cache gates.

The genuine pre-fix foreign-owner probe selected Owner rather than current
Other, retained in source-link-program-owner-unfixed-probe_test.v and
source-link-program-owner-unfixed-probe-gc-none.log. New two-version native/
public cases preserve Other's current viewport and pending actual INVALID_ENUM
for foreign and invalidated records; public arity, nonnullable and forged-brand
errors also remain before Source body dispatch. Genuine compiled attachments
link successfully in Owner, and a native program removed outside V reproduces
the direct driver's real link error after valid Source handle selection.

Only the two old typed foreign/deleted linkProgram owner expectations and the
matching public aggregate entry were migrated. Two typed files pass in
`Build/audit-fixes/source-link-program-owner-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-link-program-owner-public-gc-none.log`, with GC disabled
and explicit private paths. This focused evidence supersedes only those
historical owner assumptions and is not a clean replacement full sweep.
Lost linking is separately reviewed above; other program mutations/object
families, full remote transport and GC/WrapperWorld remain separate work.

deleteProgram now drops its native deletion command after loss while still
clearing the Source current-program slot by actual record identity. Pinned
Impl.cpp:560-562 executes that CPU clear after calling the proxy, even when
record_bytes:57-60 drops the generated DeleteProgram command. V conditionally
calls C deletion only after actual owner selection succeeds, then always
performs the existing retained-slot clear. An early function return at the
lost driver boundary would leave that Source slot incorrect. Record
invalidation and compact bookkeeping removal still precede dispatch; Source
proxy ID and native name stay separate.

The genuine pre-fix EGL probe deleted Other's matching native program through
a lost Owner (glIsProgram 1 to 0), retained in
source-delete-program-lost-unfixed-probe_test.v and
source-delete-program-lost-unfixed-probe-gc-none.log. A read-only generated
command/replay witness records objects.take followed by live GL deletion:
`Build/audit-fixes/source-delete-program-generated-boundary.txt`, SHA-256
`bceeff669d0701f016cbc1b524e00d3ba276807daa3e2686ccb999e5f36f5c96`.

New two-version native/public tests retain an original Source current-program
record, then invalidate that record and an owned SourceID2/native0 record
after genuine EGL loss. Null/foreign/distinct-record deletion keeps the
original slot; deleting its actual record clears it even though GL dispatch
is dropped. Source/native identity fields survive, and Other's genuinely
linked/current program remains live with DELETE_STATUS=0, two attachments,
unchanged native CURRENT_PROGRAM/viewport and pending INVALID_ENUM. Public
nullable, arity, brand, repeat and foreign cases retain undefined results and
one-shot loss reporting. CURRENT_PROGRAM's Source retained pointer branch
(Impl.cpp:1046-1050) provides public identity verification without reading
private V fields.

Two typed files pass in
`Build/audit-fixes/source-delete-program-lost-native-gc-none.log`. An initial
public-only fixture compile failed on private current_program access; its
log remains `source-delete-program-lost-public-gc-none.log`. After replacing
only that fixture access with existing Source parameter queries, two public
files pass in
`Build/audit-fixes/source-delete-program-lost-public-corrected-gc-none.log`.
Implementation and typed tests were unchanged between these public attempts;
all checks use GC disabled and explicit private paths. This is method-specific
Source loss ordering, not a generic driver suppression policy or a new clean
full sweep. Remaining program mutations/object families and full remote
transport/GC/WrapperWorld remain separate work.

deleteProgram now preserves Source CPU gates before actual native owner
selection. Impl.cpp:544-563 handles null, owner errors and an absent deletion
handle before the generated command; the source Proxy make_current prefix is
empty. V selects its actual driver only after those gates, preserving record
invalidation, native-name forwarding and the current retained program pointer
clear after the call. The genuine pre-fix two-owner null/foreign probe selected
Owner instead of current Other, archived as
source-delete-program-owner-unfixed-probe_test.v and
source-delete-program-owner-unfixed-probe-gc-none.log.

New two-version native/public cases preserve Other's current viewport and
pending actual INVALID_ENUM for nullable, foreign, repeat and public arity/
forged-brand returns. Actual linked/current program deletion still selects
Owner, invalidates its record and preserves Source/native identity fields.
GL keeps the deleted active program live with DELETE_STATUS=1 and the same
native CURRENT_PROGRAM until an actual unbind retires it; Source independently
clears its current pointer by actual record identity. A real program removed
outside V confirms record invalidation still precedes driver rejection and
retains the genuine driver error.

Only the three old typed deleteProgram null/foreign/repeat owner assertions
and the two corresponding public aggregate entries were migrated; all other
method assumptions await separate source review. Three typed files pass in
`Build/audit-fixes/source-delete-program-owner-native-gc-none.log`; three public
files pass in
`Build/audit-fixes/source-delete-program-owner-public-gc-none.log`, including
aggregate and current-record neighbors. All use GC disabled and explicit
private paths. These independently replace the old deletion owner evidence;
they do not relabel either frozen full sweep. Lost deletion is separately
reviewed above; remaining program mutations, other object families, full remote transport and
GC/WrapperWorld remain separate boundaries.

deleteShader now retains Source CPU record invalidation while dropping its
native command after loss. Impl.cpp:585-602 handles null, owner errors and an
absent deletion handle before dispatch. WebGLObject.cpp:50-59 invalidates the
owned record before returning its Source proxy ID. GLFunctions.json:1070-1080
records an object-deleting command; lost record_bytes:57-60 drops that command,
so the compositor performs neither objects.take nor its native deleteShader.
V keeps existing invalidation/bookkeeping removal and retained attachments,
then returns after unavailable actual current selection before direct C work.
Its live deletion and nullable/invalid-handle CPU order remain unchanged.

A genuine EGL pre-fix probe deleted Other's matching native shader through a
lost Owner (actual glIsShader 1 to 0). Its corrected observational source/log
are source-delete-shader-lost-unfixed-real-probe_test.v and
source-delete-shader-lost-unfixed-real-probe-gc-none.log; two preceding ignored
probe attempts retain only V Result-propagation compile failures and provide
no runtime evidence. The read-only generated proxy/replay witness is
`Build/audit-fixes/source-delete-shader-generated-boundary.txt`, SHA-256
`ac1ed0daf3bb1090627c07da268889a5bbe4587845ec7b8617236e308a128835`.

New two-version typed/public cases invalidate Owner's original and owned
SourceID3/native0 shader records after loss, preserve Source/native identity
fields and retain the deleted original through its program attachment.
Other's actual shader stays live with DELETE_STATUS=0 and unchanged compiled
source, viewport and pending INVALID_ENUM. Nullable, repeat, foreign and public
arity/forged-brand cases preserve their Source behavior; public deletion stays
undefined, retained attachment wrapper identity survives, and loss reporting
remains one-shot. Existing live deletion tests retain deferred actual shader
lifetime while attached and genuine driver rejection order.

Two typed files pass in
`Build/audit-fixes/source-delete-shader-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-delete-shader-lost-public-gc-none.log`, with GC disabled
and explicit private paths. This method-specific loss correction supplies no
invented driver or algorithm; program mutation/loss, other is-object methods,
remote transport and full GC/WrapperWorld remain separately reviewed work.
Historical full-sweep evidence and canonical bundle claims are unchanged.

compileShader now drops only its generated native command after loss. Pinned
Impl.cpp:414-426 keeps the owned shader handle gate; GLFunctions.json:626-635
marks glCompileShader as a command carrying an object ID. The source generator
records CompileShader, record_bytes:57-60 suppresses its bytes after loss,
and the compositor resolves objects.lookup(command.shader) before its live
GL call. V now returns after unavailable actual owner selection and before
its direct C call/metadata dispatch. Valid live compilation and CPU invalid
handle order remain unchanged. The read-only generated proxy/replay witness is
`Build/audit-fixes/source-compile-shader-generated-boundary.txt`, SHA-256
`f4c43883d03a737888bf5a13f2b2f32d75ae805552cabb7427ef685dba272016`.

The genuine pre-fix EGL probe compiled Other's matching native shader from
GL_COMPILE_STATUS=0 to 1 through a lost Owner, recorded in
source-shader-compile-lost-unfixed-probe-gc-none.log and its ignored test source.
New two-version native/public cases retain Owner's original and owned
SourceID2/native0 records while Other remains current. Other's valid shader
source stays uncompiled, its text and viewport remain intact, and its pending
INVALID_ENUM survives without an extra zero-name error. Public arity,
nonnullable, forged-brand and foreign handle gates remain effective after loss;
setter results stay undefined and loss reporting remains one-shot.

Two typed files pass in
`Build/audit-fixes/source-compile-shader-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-compile-shader-lost-public-gc-none.log`, including
existing genuine live/CPU-order neighbors. All use GC disabled and explicit
private paths. This feature is only compileShader's reviewed command drop;
other lost commands, remote transport, full GC/WrapperWorld and unrelated
creation/query output rules remain separate. No new full-sweep or canonical
browser bundle claim is added.

shaderSource now suppresses only its actual custom driver command after loss.
Impl.cpp:2312-2330 preserves its owned handle gate and explicit UTF-8 string
length. The custom ProxyBase.cpp:332-343 packs one source payload and records
ShaderSource; record_bytes:57-60 drops that record after loss. Its compositor
receiver (HostWebGLContext.cpp:243-250) then has no command to replay. V now
returns after unavailable actual current selection before the C shaderSource
call, preserving the existing CPU validation and live one-string/length call.
Public DOMString conversion remains before Source body entry.

A genuine pre-fix EGL probe overwrote Other's matching native shader with a
lost Owner's replacement source, retained in
source-shader-source-lost-unfixed-probe-gc-none.log and its test source. The
corrected native/public two-version cases retain an original record and owned
SourceID2/native0 record after loss. Other's actual shader text and successful
compile status remain unchanged, its viewport stays current and its pending
INVALID_ENUM survives without an extra zero-name driver error. Public ToString
runs once or throws before dispatch; nonnullable/forged-brand and foreign
handle gates retain their Source behavior. One-shot loss reporting is preserved.

Two typed files pass in
`Build/audit-fixes/source-shader-source-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-shader-source-lost-public-gc-none.log`, including the
existing source/compile CPU-owner neighbors. All use GC disabled and explicit
private paths. This is the shaderSource method alone; compileShader is separately reviewed
below, while program mutations and other lost commands remain work.
No fake driver or Source algorithm supplies this command drop, and no full
regression, remote map/GC/WrapperWorld or canonical bundle claim is added.

Program diagnostic/parameter queries now retain their initialized Source
outputs after loss. Impl.cpp:1789 initializes the robust parameter result to
zero; :1828 initializes regular log length to zero. The exact generated void
sync proxies return immediately when lost, before copying any output, and
ProxyBase.cpp:168-176 suppresses an already-lost send. The direct regular and
robust programiv helpers now return zero after unavailable current selection,
preventing queries into Other's current driver. This yields an empty owned
program log, zero supported numeric results and false supported Boolean results.
CPU handle gates, eager pname switch order, live regular/robust ABIs and actual
native names remain unchanged; no fallback algorithm supplies these values.

A genuine EGL pre-fix probe returned Other's linked=true and its 21-byte failed
program log after Owner loss. Source and output are retained as
`Build/audit-fixes/source-program-query-lost-unfixed-probe_test.v` and
source-program-query-lost-unfixed-probe-gc-none.log. Corrected two-version
native/public cases match actual program names in independent EGL contexts,
retain two original records and create a third owned SourceID3/native0 record.
They verify 21 WebGL1 and 30 WebGL2 supported getter calls over those records,
while Other's actual linked program, failed-link diagnostic, viewport and
pending native error stay intact. Public pname conversion still runs once or
throws before the body; Source one-shot context-loss reporting is preserved.
These are real driver witnesses, without a substitute backend.

Three typed files pass in
`Build/audit-fixes/source-program-query-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-program-query-lost-public-gc-none.log`, including regular
diagnostic CPU-owner and robust parameter comparisons. All use GC disabled and
explicit private paths. Exact generated regular/robust/log proxy/compositor
bodies remain in source-program-query-generated-boundary.txt (SHA-256
`d1b6674386836dc479f96872545624f4412bef63303a50b8c5328201d41eede3`).
Broader loss command suppression, program mutation CPU gates, other getters,
remote transport/maps and GC/WrapperWorld remain separate Source-reviewed
features. This focused native/JSC result supplies no new full regression or
canonical production-bundle/capture claim.

getProgramParameter now uses the Source one-element ANGLE robust ABI through
a separate native helper. Impl.cpp:1789-1790 initializes GLint result to zero
and invokes get_programiv_robust_angle(program,pname,1,nullptr,&result) before
its return switch. The new C/V bridge forwards that operation; regular
programiv remains separate for getProgramInfoLog length, matching its distinct
Source body. Existing actual owner selection, native names, eager query and
pname/error ordering are preserved. This ABI feature adds no lost-output rule.

Focused two-version native/public cases compare all Source numeric/Boolean
pname categories and unsupported values with independent real
glGetProgramivRobustANGLE calls using capacity1 and null length. A failed actual
link outside V supplies a genuine nonempty diagnostic. WebGL1 rejection of
WebGL2 pnames retains its fallback after the actual native query. A Source-owned
record whose program is deleted directly through GL still reaches the robust
driver query and matches its rejected result/error, without a CPU mirror.

Three typed files pass in
`Build/audit-fixes/source-program-parameter-robust-native-gc-none.log`; two
public files pass in
`Build/audit-fixes/source-program-parameter-robust-public-gc-none.log`, including
CPU-owner and existing shader/program parameter neighbors. All use GC disabled
and explicit private paths. Exact generated regular/robust/log proxy and
compositor evidence is retained in
`Build/audit-fixes/source-program-query-generated-boundary.txt` (SHA-256
`d1b6674386836dc479f96872545624f4412bef63303a50b8c5328201d41eede3`).
The subsequent initialized lost program output repair is documented above.
Mutations, remote maps and GC/WrapperWorld remain separate features. No full
regression or canonical bundle evidence is
claimed by this focused actual native/JSC ABI result.

getProgramParameter now validates its Source handle before selecting the
actual sync driver. Impl.cpp:1781-1815 returns null and INVALID_OPERATION for
foreign/deleted programs before any native query. Its Proxy prefix is empty;
V now relies on the native parameter helper's valid-handle current selection
rather than an unconditional prefix. The genuine eager driver query remains
before Source's pname switch, including unsupported and WebGL1-only rejection
paths. Return shapes, stored native name and actual-error-before-local-fallback
order are preserved. This CPU feature does not yet change the helper's regular
versus Source robust ABI or lost outputs.

The two-version native/public cases verify Other viewport/error preservation
on early returns, valid queries selecting Owner, public pname conversion once
before the foreign gate and conversion throws before any native selection.
Unknown native pnames retain driver plus local INVALID_ENUM; a valid native
pname outside Source's switch retains only the local fallback after a pending
actual driver error. An owned record whose native program was deleted outside
V still reaches the driver and retains its actual failure/Boolean return.

The initial typed group had a new-test enum spelling error and a legacy
foreign-program owner expectation. The corrected test uses existing .none,
and only that Source-reviewed legacy assertion now compares Other's actual
GL_CURRENT_PROGRAM before/after the early return. Its real live retained
program/delete-status and eager-query assertions remain intact. Two corrected
typed files pass in
`Build/audit-fixes/source-program-parameter-owner-native-corrected-gc-none.log`;
two unchanged public files pass in
`Build/audit-fixes/source-program-parameter-owner-public-gc-none.log`. The initial
typed failure remains in the native log without -corrected. Implementation was
unchanged after the public proof. All checks use GC disabled and explicit
private paths; this is corrected focused evidence, not a relabeled full sweep.

The subsequent separate program robust ABI and initialized lost-output repairs
are documented above. Other mutations, remote maps and GC/WrapperWorld remain
separate scopes. No canonical bundle claim follows from
these focused actual native/JSC tests.

getProgramInfoLog now keeps actual owner selection after its Source handle
gate. Impl.cpp:1817-1836 validates the program handle and returns nullable
failure with INVALID_OPERATION before issuing a query. Its Proxy prefix is
empty; the V regular native programiv length/log helper already selects its
actual driver at sync dispatch. The unconditional native prefix is removed,
while the existing regular length query, empty-string return, bytes excluding
the terminating null, and stored native name remain unchanged.

The two-version native/public cases preserve Other's viewport and pending
native error for foreign/deleted early returns, distinguish null failure from
an owned empty string, and validate public nonnullable/forged-brand TypeErrors
before any owner change. A failed native link outside V supplies a nonempty
actual program log, read independently through direct driver calls and matched
exactly by the Source getter. Thus this owner repair retains real diagnostic
readback rather than a status/log mirror.

Two typed files pass in
`Build/audit-fixes/source-program-diagnostic-owner-native-gc-none.log`; two
public files pass in
`Build/audit-fixes/source-program-diagnostic-owner-public-gc-none.log`, including
existing shader/program diagnostic neighbors. All use GC disabled and explicit
private paths. The subsequent parameter CPU gates, distinct robust ABI and
lost initialized program outputs are documented above. The regular diagnostic
query is deliberately preserved. Remote maps, GC/WrapperWorld and canonical
bundle/full-sweep evidence remain outside this focused native/JSC result.

isProgram now preserves the generated GLboolean false default after loss.
GLFunctions.json:2802-2813 classifies glIsProgram as sync; its exact generated
Proxy sends the request then returns {} if lost before decoding the return
value. ProxyBase.cpp:168-176 skips an already-lost transport call. The direct
adapter now stops after unavailable actual owner selection, after the unchanged
nullable/context/optional gates, rather than querying Other's current driver.
Live queries still select Owner and call glIsProgram with the stored native
name; no CPU program status cache supplies a result.

The genuine earlier EGL loss probe returned true for Owner's old native name
from Other's live program, retained in source-program-lost-unfixed-probe-gc-none.log.
Corrected two-version native/public cases match the actual Owner/Other program
names, retain an original record and create a new owned proxy program after
loss, then require both Source queries to return false. Other's real program,
viewport and pending native error survive; null/foreign early gates and public
brand/arity checks remain Source ordered. Live external native deletion still
changes the query to false while its Source record remains owned. One-shot
context-loss reporting is retained. No fake backend supplies the lost return.

Three typed files pass in
`Build/audit-fixes/source-is-program-lost-native-gc-none.log`; two public files
pass in
`Build/audit-fixes/source-is-program-lost-public-gc-none.log`, including CPU-owner,
lost program creation and nullable adapter neighbors. All use GC disabled and
explicit private paths. The exact generated program gen/sync/compositor witness
is source-program-generated-boundary.txt (SHA-256
`f95243942ce74f2665121b832e129fc382858e88fe92e869decfac6ce234b2dd`).
Program diagnostic/parameter owner gates, robust ABI and lost initialized outputs,
other Boolean queries and broader commands remain separate features. Remote
transport/maps, GC/WrapperWorld, full regression and production bundle evidence
remain distinct from these focused native/JSC checks.

createProgram now suppresses its actual native creation command after loss
while retaining the Source-owned program record and allocated proxy ID.
Impl.cpp:457-461 returns WebGLProgram::create for the generated create_program
result. GLFunctions.json:939-943 marks this call gen; the actual generator
allocates an ID, records CreateProgram and returns that ID. ProxyBase.cpp:57-60
drops record_bytes after loss, so the compositor cannot create a native program
mapping. The direct V adapter now skips native selection/creation once lost
and keeps native_name zero as the absent mapping, separately from the Source
u32 ID and compact wrapper key. It preserves live creation and never turns
this non-null Source record into null or invents a zero Source proxy ID.

The genuine unfixed two-version EGL probe created native name2 in Other after
Owner loss; its actual driver isProgram query returned true. That unwanted
creation evidence is retained in source-program-lost-unfixed-probe-gc-none.log.
Corrected native/public cases preserve Other's live program, viewport and
pending error while returning three distinct owned lost records with Source
IDs2-4 and native mapping0. Restoration invalidates the old generation and
resumes actual driver creation with Source ID5. This matches the allocator's
postincrement and the pinned Proxy restore body, which does not reset its
counter (ProxyBase.h:74, ProxyBase.cpp:31-40). No fake backend or fabricated
native-name sequence supplies the result.

Three typed files pass in
`Build/audit-fixes/source-program-creation-lost-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-program-creation-lost-public-gc-none.log`, including
shader creation and actual resource-handle neighbors. All use GC disabled and
explicit private paths. Exact generated program proxy/compositor bodies are
retained in source-program-generated-boundary.txt (SHA-256
`f95243942ce74f2665121b832e129fc382858e88fe92e869decfac6ce234b2dd`).
The separate generated isProgram Boolean loss repair is documented above.
Other creation families and broader lost commands remain separate features,
alongside remote maps and GC/WrapperWorld.
This is focused native/JSC evidence, not a full sweep or canonical bundle build.

The isProgram nullable host adapter now explicitly invokes is_program(None)
for an absent nullable map entry. Base.idl:132 accepts WebGLProgram?, and
Impl.cpp:2159-2160 returns false without a native sync request. Actual pre-fix
host null calls returned empty-message TypeError because the compatibility
compiler propagated inline map none into the enclosing Result. As for the
separate isShader adapter correction, the explicit arm preserves the translated
Source call rather than fabricating a Boolean or changing validation order.
The fixed emitted C in source-is-program-nullable-fixed-generated.c constructs
optional none, calls the typed method and returns successful json2 Boolean;
valid host records still forward their actual retained pointer.

The actual JavaScriptCore two-version nullable test and program CPU-owner
neighbor pass with GC disabled and explicit private paths in
`Build/audit-fixes/source-is-program-nullable-public-gc-none.log` (two files).
They cover public null/undefined false, preserved Other viewport and pending
driver error, direct host null false, valid native program true and unchanged
brand/arity TypeErrors. The prior raw host failure remains in the pre-fix
observational log. The subsequent separate program gen and Boolean loss
repairs are documented above. Other is-object nullable adapters, remote maps
and GC/WrapperWorld remain separate scopes. No new full regression
or canonical browser build is claimed by this compatibility repair.

isProgram now preserves Source CPU optional-query gates before actual owner
selection. Impl.cpp:2155-2170 returns false for null and absent invalidated or
stale optional handles; foreign records report INVALID_OPERATION after context
validation. ProxyBase.h:44's prefix is empty. The V adapter now selects its real
driver only once a live owned optional handle reaches glIsProgram, using the
separate stored native name. This changes no Source handle validator or native
program query algorithm.

The actual unfixed two-version native probe selected Owner's viewport for null
and foreign queries with Other already current; a host foreign query did the
same. Its observational assertions and log are retained as
`Build/audit-fixes/source-is-program-unfixed-probe_test.v` and
source-is-program-unfixed-probe-gc-none.log. The focused corrected native/public
cases preserve Other's viewport and pending native error on early returns.
Eight actual program names are reserved, then native name1 deleted, so Source
ID1's valid query demonstrably uses native name9. A genuinely compiled, linked
and current program remains a live GL object after Source deletion, while
isProgram returns false from its invalidated optional before selecting Other.
The existing aggregate fixture migrates only the reviewed isProgram(null)
expectation; other historical method assumptions remain independently scoped.

Three typed files pass in
`Build/audit-fixes/source-is-program-owner-native-gc-none.log`; two public files
pass in
`Build/audit-fixes/source-is-program-owner-public-gc-none.log`, including aggregate
and actual object-handle regressions. All use GC disabled and explicit private
paths. Public null/undefined are excluded from this CPU feature: the separate
raw host probe returned an empty-message TypeError from its inline map-or-none
compatibility expression, before reaching the Source nullable method.

The subsequent nullable host adapter, generated creation loss suppression and
Boolean lost default repairs are documented above. A real observational EGL
loss probe confirmed lost isProgram true and lost createProgram creating
an actual native program in Other; its source/log are retained under
source-program-lost-unfixed-probe*. These are unwanted direct-driver evidence,
not parity. Remote maps, GC/WrapperWorld and a newly built canonical bundle
remain outside this focused CPU-owner result.

isShader now preserves the generated GLboolean default after actual owner loss.
GLFunctions.json:2826-2837 classifies glIsShader as sync; the pinned generated
Proxy sends the request, then returns {} if lost before decoding a reply.
ProxyBase.cpp:168-176 suppresses an already-lost send. The direct adapter now
returns false if actual current selection is unavailable, after the unchanged
Source nullable/optional handle gates, without querying Other's current driver.
Live calls still query the stored native shader name, independently of wrapper
state. Exact generated proxy/compositor evidence is retained in
`Build/audit-fixes/source-is-shader-generated-boundary.txt` (SHA-256
`33f79cbda7aa087b1ccf3c965ab0b62267cfa776065d564137774ea41204fda8`).

A genuine unfixed EGL probe returned true for a lost owner's shader whose native
name equaled Other's live shader name; the actual evidence remains in
source-is-shader-lost-unfixed-probe-gc-none.log. The corrected two-version
native/public cases retain an original owned shader, lose real EGL and create
another owned proxy shader with absent native mapping. Both queries return
false beside Other's live matching shader, unchanged viewport and pending
native error. Null/foreign gates, public nullable and brand/arity conversion,
and one-shot Source loss reporting remain intact. A live shader deleted outside
V still queries the actual driver and returns false without invalidating its
owned Source record. No fabricated backend supplies loss or native-name results.

Three typed files pass in
`Build/audit-fixes/source-is-shader-lost-native-gc-none.log`; three public files
pass in
`Build/audit-fixes/source-is-shader-lost-public-gc-none.log`, including the CPU
owner and nullable adapter neighbors. All checks use GC disabled and explicit
private paths. Program and other GLboolean queries, broader lost commands,
remote transport/maps and GC/WrapperWorld remain separate features. This is
focused native/JSC evidence, not a new full sweep or canonical bundle build.

The nullable isShader public host call now explicitly invokes the translated
optional-none method when no host shader record exists. Source Base.idl:134
accepts WebGLShader?, and Impl.cpp:2195-2196 returns false for null before a
sync query. The old compatibility compiler instead emitted an enclosing Result
error for the inline map-or-none argument; an actual host.call([null]) produced
an empty-message TypeError. The explicit map arm fixes that adapter expression
without substituting a fabricated Boolean or changing Source logic. Generated
C now constructs an optional-none value, calls is_shader and returns a successful
Boolean result. The before/after emitted C is retained privately as
source-is-shader-public-generated.c and
source-is-shader-nullable-fixed-generated.c.

The actual native JavaScriptCore two-version nullable case checks null and
undefined false returns, preserved Other viewport and pending driver error,
the direct host null request, valid native shader success, and unchanged
missing-argument/forged-brand TypeErrors. It and the CPU-owner neighbor pass
with GC disabled and explicit private paths in
`Build/audit-fixes/source-is-shader-nullable-public-gc-none.log` (two files).
The earlier public null failure remains historical evidence rather than a
passing CPU-fixture claim. Other is-object host branches still use the same
inline optional expression and require separate Source/adapter review; the
subsequent isShader Boolean lost sync feature is recorded above. Remote maps
and GC/WrapperWorld remain independent scopes.
This is focused compatibility adapter evidence, not a native bundle build.

isShader now keeps Source optional handle gates before actual driver owner
selection. WebGLRenderingContextImpl.cpp:2191-2208 returns false for null or an
absent invalidated/generation-stale optional; a foreign-context query returns
false with INVALID_OPERATION after context validation. The empty Proxy prefix
selects no driver. V now selects its actual owner only before a valid live GL
query, preserving the Source optional validator and separate native name.

The typed two-version case checks null/foreign/deleted-foreign and repeated
query returns with Other current. An attached shader remains a genuine live GL
shader after Source deletion while isShader returns false before querying it.
Real native shaders reserve eight names; deleting native name 1 before Source
ID 1's live query verifies that the separate stored native name supplies GL,
not the Source ID. Public foreign/deleted/valid and brand cases preserve actual
owner/error/identity evidence. Only isShader(null) was migrated in the existing
aggregate query-owner fixture; other historical methods retain their separate
review boundaries.

Three typed files pass in
`Build/audit-fixes/source-is-shader-owner-native-gc-none.log`; two public files
pass in
`Build/audit-fixes/source-is-shader-owner-public-final-gc-none.log`, including
aggregate/object and Source ID/native-name regressions. All use GC disabled
and explicit private paths. The public null/undefined case is explicitly not
part of this CPU feature's final public scope: it exposed a compatibility C
adapter issue, independently of the correct typed Source body.

The generated old-compiler C in source-is-shader-public-generated.c emits an
early error result with err:_const_none__ for an absent map entry in the host's
inline return-sumtype argument expression, before invoking is_shader(None).
Direct host.call([null]) returned TypeError with an empty message, preserved in
source-is-shader-owner-public-host-diagnostic-gc-none.log; the initial/diagnostic
public failures are retained. The subsequent separate explicit null host-call
adapter repair and generated Boolean lost result are documented above. Other
is-object families,
remote maps, GC/WrapperWorld and current bundle/captures remain independently
scoped; this is no clean full-sweep or production-bundle claim.

Shader diagnostic/parameter sync queries now preserve exact initialized Source
outputs after loss. GLFunctions.json:2348-2400 classifies regular/robust shaderiv
as void sync. generate_libweb_webgl_proxy.py:153-158 returns before copying any
output once is_lost, and ProxyBase.cpp:168-176 skips dispatch when already lost.
Source Impl.cpp:1877/:1911/:1931 initializes result and diagnostic lengths to 0.
Thus getShaderSource/getShaderInfoLog return empty strings, shader type returns
numeric 0, and compile/delete status return false for an otherwise owned/live
record after loss. The two direct native helpers now stop at unavailable actual
current selection, retaining those Source outputs without querying Other.
Live owner selection and exact regular/robust Driver calls are unchanged.

The real unfixed probe had owner/Other native names both 1: a lost Source getter
returned Other's shader text, type 35633 and successful compilation. That unwanted
actual driver evidence remains in
`Build/audit-fixes/source-shader-query-lost-unfixed-probe-gc-none.log`.
The corrected native/public two-version tests lose genuine EGL, retain two
original records and create a third owned proxy record after loss. They verify
15 Source queries per version beside Other's actual successful shader and
nonempty failing compiler log, with untouched viewport and pending native
error. Public conversions still run once or throw before body entry; Source
one-shot context-loss reporting stays intact. No fake backend supplies a result.

Three typed files pass in
`Build/audit-fixes/source-shader-query-lost-native-gc-none.log`; three public
files pass in
`Build/audit-fixes/source-shader-query-lost-public-final-gc-none.log`, including
live diagnostic and robust query neighbors. The initial public GLSL newline
literal failure and subsequent formatter-added JSON option incompatibility are
preserved in the logs without `-final`. All checks use GC disabled and explicit
private paths. Exact generated regular/robust proxy/compositor evidence remains
in source-shader-query-generated-boundary.txt with the SHA-256 recorded below.

This repairs only these shader sync outputs. The separate isShader Boolean
sync repair is documented above. Broader lost commands, program queries, actual
bundle/capture validation, full remote
maps and GC/WrapperWorld remain independent scopes. These focused private native
and JavaScriptCore checks make no claim about a newly built canonical bundle.

getShaderParameter now invokes the exact Source ANGLE robust query.
WebGLRenderingContextImpl.cpp:1877 initializes GLint result to 0, then calls
get_shaderiv_robust_angle(shader,pname,1,nullptr,&result) before its pname switch.
The native C bridge now forwards that exact one-element call through a separate
robust helper. getShaderSource/getShaderInfoLog length queries retain regular
get_shaderiv, matching their distinct Source bodies; no broad helper replacement
changes those diagnostics. Actual native names remain separate from Source IDs.

Focused native/public cases compare values and errors against direct actual
glGetShaderivRobustANGLE calls with capacity 1 and a null length pointer. They
cover Source number/boolean/null shapes, real compiler failure, unsupported
Source/native names and native driver rejection after outside deletion of a
shader whose Source record remains owned/live. Owner selection and driver-before-
Source-fallback order remain intact, and no status cache supplies a result.
Three typed files pass in
`Build/audit-fixes/source-shader-parameter-robust-native-gc-none.log`; three
public files pass in
`Build/audit-fixes/source-shader-parameter-robust-public-gc-none.log`, including
CPU-owner and existing parameter regressions. All use GC disabled and explicit
private paths.

The exact regular/robust proxy and compositor snippets are generated read-only
into `Build/audit-fixes/source-shader-query-generated-boundary.txt` (SHA-256
`864ec67312c6b7d0de9231d0db6dc4816e25092d2d3bd4a6015d0887709e73a5`).
Lost shader sync suppression is supplied by the subsequent independent feature
above. The separately regular-versus-robust program getter helper remains open;
this ABI feature adds no loss policy or full remote transport/map/GC/WrapperWorld
claim.

getShaderParameter now validates its Source handle before actual native sync
owner selection. WebGLRenderingContextImpl.cpp:1864-1889 returns a nullable
failure for foreign/deleted records before its native query. Its empty Source
Proxy make_current supplies no owner switch; the V native parameter helper
selects the driver only after the handle passes. The valid-handle driver query
still precedes the Source pname switch, including unsupported names. This
Source eager query is genuine and must not be removed.

Two-version native/public cases distinguish foreign/deleted early returns
(Other current) from valid and unknown-pname queries (Owner current). They
verify a genuine pending Other error remains untouched, native unsupported-name
errors precede the Source fallback, and a valid native pname outside Source's
return switch adds only the local fallback. Public pname conversion runs once
before the Source handle gate; conversion and brand throws precede body entry.
Two typed files pass in
`Build/audit-fixes/source-shader-parameter-owner-native-gc-none.log`; two public
files pass in
`Build/audit-fixes/source-shader-parameter-owner-public-gc-none.log`, including
the existing actual shader/program parameter tests. All use GC disabled and
explicit private module paths.

This is only the Source CPU-owner correction. The exact ANGLE robust query ABI
is corrected by its subsequent independent feature above, as is shader sync
lost-output suppression. Program methods, full remote maps and GC/WrapperWorld
remain separate scopes.

deleteShader now leaves actual native owner selection after Source nullable
and optional-handle deletion gates. WebGLRenderingContextImpl.cpp:585-603
returns for null, foreign handle errors and absent repeated/stale deletion
handles before recording any driver command; ProxyBase.h:44 supplies no native
prefix selection. The direct V adapter therefore selects its owner only before
a valid actual deletion. Context validation still precedes invalidation, and
the first owned deletion retains Source proxy ID/native name while invalidating
exactly once. Compact registry removal remains separate bookkeeping.

The native two-version case verifies null/foreign/repeated returns with Other
current and checks a real pending Other driver error. An attached shader stays
alive in GL with DELETE_STATUS true and remains the same actual Source retained
attachment record. A separately externally deleted native shader verifies
Source invalidation remains after genuine native driver rejection. Public cases
cover null/undefined, brand errors, foreign/repeated/deleted-foreign paths,
actual GL deletion status and retained wrapper identity. Only deleteShader
expectations in the historical mutation fixtures were migrated.

Three typed files pass in
`Build/audit-fixes/source-shader-delete-owner-native-gc-none.log`; three public
files pass in
`Build/audit-fixes/source-shader-delete-owner-public-gc-none.log`, including
Source handle/registry and public label/interface neighbors. All use GC
disabled and explicit private module paths. This supersedes historical
unconditional shader deletion owner-prefix assertions; broader lost-command
suppression, program methods, full remote transport/maps and GC/WrapperWorld
remain separately scoped Source work.

getShaderSource and getShaderInfoLog now preserve Source handle validation
before actual sync owner selection. WebGLRenderingContextImpl.cpp:1900-1940
returns a nullable failure for foreign/deleted records before issuing any
get_shaderiv operation. ProxyBase.h:44 leaves the current owner untouched;
HostWebGLContext.cpp:145-150 selects the actual owner only when the valid query
reaches the sync receiver. The V native length/readback helpers already select
that owner, so the two invented unconditional entry prefixes were removed.
Valid empty strings still require the genuine owning driver's length query.

Focused two-version native/public tests distinguish nullable failures from
owned empty strings, preserve the current other driver and its pending error
on CPU returns, and verify valid owner selection. Both compare exact shader
source and compiler-log bytes after direct native mutation, without relying on
a V shader cache; public brand failures likewise occur before native dispatch.
Two typed files pass in
`Build/audit-fixes/source-shader-diagnostic-owner-native-gc-none.log` and two
public files pass in
`Build/audit-fixes/source-shader-diagnostic-owner-public-gc-none.log`, including
the existing diagnostic result/identity neighbors. All use GC disabled and
explicit private paths.

This supersedes earlier unconditional owner-prefix descriptions specifically
for these two getters. Their native helper's subsequent lost-query suppression
and shader parameter getter owner/ABI order are recorded above; program
diagnostics/deletion, full remote maps and GC/WrapperWorld remain independent
Source slices. Native source
and log lengths, terminator exclusion and public nullable/string shapes remain
as translated from the pinned source.

shaderSource and compileShader now keep Source handle validation ahead of
actual native owner selection. WebGLRenderingContextImpl.cpp:414-426 and
:2312-2330 validate each shader before recording its command. The preceding
ProxyBase.h:44 make_current is empty; HostWebGLContext.cpp:54-56 selects the
actual driver when a recorded command executes. The V direct adapter therefore
leaves an already-current other context unchanged on foreign/deleted handle
returns and selects its real owner only before a valid native command. Shader
Source proxy IDs, separate native names, exact UTF-8 byte lengths and actual
compilation remain intact.

The new native two-version case preserves genuine foreign source/compile state,
checks Source local errors after a pending owner-driver error, then reads actual
owned source and successful driver compilation. The public case additionally
checks once-only DOMString conversion and an author conversion throw before body
entry. Only the shaderSource/compileShader cases in the historical aggregate
mutation fixtures were migrated; the remaining methods await their own reviews.
Three typed files pass in
`Build/audit-fixes/source-shader-command-owner-native-corrected-gc-none.log`;
three public files pass in
`Build/audit-fixes/source-shader-command-owner-public-corrected-gc-none.log`.
Initial fixture-only failures (unsupported V default parameter syntax and an
unescaped JavaScript string newline) remain in the corresponding logs without
`-corrected`. All checks use GC disabled and explicit private module paths.

This supersedes historical unconditional owner-prefix assertions only for
these two Source commands. General lost-command suppression, shader diagnostic
getters/deletion, full remote transport/maps and GC/WrapperWorld remain separate
scopes. No native-driver shader algorithm was replaced by a V mirror.

clientWaitSync now applies the exact generated compositor timeout override.
GLFunctions.json:595-597 gives the wire timeout `host_override: "0"`, and
generate_compositor_webgl_replayer.py:185-188 substitutes that literal in the
actual gl.client_wait_sync call. The proxy and Source Impl.cpp:939-950 still
carry the converted original timeout. The V method likewise keeps public IDL
conversion and the original Source argument, while its actual native receiver
now passes timeout 0 to GL. This is the pinned compositor policy, not a new
WebGL argument gate or a fabricated fence completion result.

The native case compares real timeout-0 driver state/error observations across
16 flag/requested-timeout pairs and two owners. Genuine GPU progress can occur
between independent observations, so successful statuses use the actual allowed
native completion states; competing invalid flags retain exact driver errors.
The historical GPU fixture's nonzero-wait completion assumption was migrated
in this same feature: it now permits a real timeout result and uses genuine
finish() before asserting native signaled state. It does not infer GPU completion
from a V timeout mirror. Three typed timeout/GPU/loss files pass in
`source-sync-host-timeout-native-gc-none.log`. Three public timeout/loss/owner
files pass in `source-sync-host-timeout-public-gc-none.log`, verifying original
timeout valueOf runs exactly once before actual owner selection and throws before
body entry, along with real native result/error and lost-default neighbors.
All checks use GC disabled and explicit private module paths.

A separately discovered affected legacy case in webgl2_state_test.v also
assumed a nonzero clientWaitSync request guarantees completion. Its test-only
migration accepts the actual timeout-0 completion statuses and calls genuine
finish() before the signaled assertion. The complete affected file passes with
GC disabled in `Build/audit-fixes/source-sync-host-timeout-legacy-state-gc-none.log`.
This supplements the focused timeout feature evidence; it does not reclassify
any earlier frozen full sweep or add a production behavior change.

The complete actual generated proxy and compositor snippets remain in
`Build/audit-fixes/source-client-wait-generated-boundary.txt`. No fake driver or
inferred timer policy supplies this override. Broader method loss suppression,
remote transport/map execution and full GC/WrapperWorld remain independent work.

clientWaitSync now preserves the actual generated sync loss result.
WebGL2RenderingContextImpl.cpp:939-950 first validates its owned sync record,
then invokes the proxy operation. generate_libweb_webgl_proxy.py:153-158 returns
a default GLenum (0) after send_sync_call if the proxy is lost;
ProxyBase.cpp:168-176 skips transport dispatch when already lost. V previously
substituted WAIT_FAILED at its unavailable native receiver guard. That guard now
returns the Source default 0, preserving WAIT_FAILED for genuine Source handle
errors and live native-driver failures. No native query runs against an already
current other owner after actual loss.

The focused native case loses real EGL, retains an earlier owned sync, creates
a second Source proxy record after loss, and keeps another context's real fence,
viewport and pending driver error untouched through 18 lost waits. The existing
native fence helper already suppresses creation after real loss; its owned
post-loss proxy ID and absent native mapping are now witnessed directly. A live
rejected native fence still has a nonzero Source proxy pointer and the real
native WAIT_FAILED/error result, verified against direct driver calls. Three
typed loss/GPU/owner files pass in
`source-sync-lost-default-native-gc-none.log`. Two public loss/creation files
pass in `source-sync-lost-default-public-gc-none.log`, covering original and
post-loss branded records, varied converted flags/timeouts, Source one-shot
context-loss error and untouched other driver state. All use GC disabled.

Exact generated proxy/compositor snippets are preserved in
`Build/audit-fixes/source-client-wait-generated-boundary.txt`, produced read-only
from the pinned generators without writing upstream. The compositor's separate
clientWaitSync host timeout override0 is corrected by the subsequent separately
scoped feature above. This default-result repair does not change general resource loss
policy or claim full remote transport/map, GC or WrapperWorld execution.

clientWaitSync, waitSync, deleteSync and getSyncParameter now preserve the
Source CPU early-return ownership boundary. WebGL2RenderingContextImpl.cpp:920-
980 validates context/generation/invalidation before reaching any native sync
query/command; nullable or repeated deletion also returns early. The Source
make_current prefix is empty (ProxyBase.h:44). Actual commands/sync calls select
their host in HostWebGLContext.cpp:54-56 and :145-150, so the V methods no longer
select a native owner before these CPU gates. Existing dispatch/native helpers
select the actual owner only after Source validation succeeds. Stored Source
proxy pointers, real native mappings and Source return/error shapes stay intact.

Native tests cover foreign, null and deleted branches with the other context
current; pending actual errors from both driver owners; genuine native wait,
query and deletion; and owned records whose actual native fence result is null.
Both Source and native pointers remain retained after deletion. Four typed
owner/pointer/GPU/query-owner files pass in
`source-sync-owner-boundary-native-gc-none.log`. Three public owner/creation/host
files pass in `source-sync-owner-boundary-public-gc-none.log`, including public
brand/conversion throws before body entry and actual owner selection on valid
dispatch. Only getSyncParameter(foreign) was added to the separately reviewed
early-return branches in the historical aggregate query-owner fixture. All
checks use GC disabled and explicit private module paths.

This supersedes the earlier sync owner fixture's unconditional prefix assumption.
The genuine earlier driver/pointer/retention evidence remains, but its early
branch owner assertions do not describe the empty Source proxy. The separately generated clientWaitSync lost default0 is corrected in the later
slice above; the compositor timeout override0 has its own subsequent feature.
This owner slice supplies neither behavior.
Full remote transport/map execution and GC/WrapperWorld remain open.

WebGLSync sync_handle and sync_handle_for_deletion now retain the Source
m_sync_handle independently of the actual native GLsync mapping. At this pin,
GLFunctions.json:1492-1504 categorizes fenceSync as `gen`;
generate_libweb_webgl_proxy.py:94-99 returns its allocated u32 ID through
uintptr_t and reinterpret_cast<GLsync>. WebGLSync.cpp:26-29 stores that proxy
pointer, with base GLuint 0, and cpp:39-58 returns it after context validation
and generation/invalidation handling. The V source_handle_ stores the same
pointer-width conversion. The first deletion invalidates once and preserves
both stored Source and native values; repeats return an absent optional.

The compositor generator separately add_sync maps the ID to the actual
fence result and lookup_sync/take_sync resolves it for queries/commands. The
four actual direct wait/get/delete bridges therefore validate Source handles
but pass the separate native_handle_ to the driver. Typed native_pointer() is
an explicit adapter accessor and adds no public WebGL IDL operation. Genuine
invalid-condition/flag fences can have a nonzero Source proxy pointer and a
null native mapping; no null-driver result is substituted into Source storage.

The first native fixture incorrectly assumed that different identity domains
always have unequal numeric values. Actual ANGLE returned native GLsync 1,
which coincided with the first Source ID. The corrected fixture reserves eight
real driver fences before Source creation, forcing tested proxy/native values
apart and verifying those independent fences survive native deletion. It also
covers the real null driver result, optional deletion, foreign owner checks
before invalidation, stale-generation returns and retained values. Six typed
files pass in `source-sync-proxy-pointer-native-corrected-gc-none.log`; the
initial assertion remains in `source-sync-proxy-pointer-native-gc-none.log`.
Three public creation/owner/host files pass in
`source-sync-proxy-pointer-public-gc-none.log`, checking Source ID values beside
actual null/successful native mappings, native queries/waits/deletion, brands
and driver errors. All use GC disabled and explicit private module paths.

This supersedes historical descriptions of sync_handle as returning the actual
native pointer, and of a rejected fence supplying a Source null proxy pointer.
Those earlier real native-pointer/error observations remain driver evidence.
The separate later actual-owner early-return correction is recorded above.
Loss command/sync suppression, full remote map/transport execution and full
GC/WrapperWorld remain separate scopes.

WebGLObject handle, handle_for_query and handle_for_deletion now preserve the
exact Source m_handle independently of native driver names and compact wrapper
IDs. WebGLObject.cpp:38-66 validates context before generation/invalidation and
returns m_handle, or its optional form; that order remains unchanged. For
normal named-resource creation, the generated proxy returns a WebGLObjectId,
not the compositor GLuint. The eleven named resource families now retain that
proxy ID in source_handle_. The compositor-side native_handle_ continues to
store the actual driver name. Typed native_name() is an explicit direct-adapter
accessor for genuine GL verification; it is not exposed in JavaScript WebGL IDL.

The creation-only allocator translates ProxyBase.h:74/111 and Types.h:32: an
unsigned 32-bit counter starts at 1 and returns then increments. It adds no
zero/collision/exhaustion policy; unsigned wrap follows the Source type.
ProxyBase.restore() at cpp:29-38 does not reset this counter, and neither does
this adaptation. Every generated GLuint family and GLsync uses the same
counter. Sync consumes/stores its generated proxy ID while retaining the exact
Source base GLuint 0 (WebGLSync.cpp:26-29). The separate subsequent GLsync proxy
pointer API repair is documented above.

Fresh getVertexAttrib buffer and getParameter sampler records are different:
Source Impl.cpp:2061-2066 and :1673-1677 passes the actual numeric query reply
directly into the wrapper, including 0. They preserve that raw Source handle
without advancing the generated creation allocator. Compact wrappers still
receive unique independent IDs for host identity and registry removal. Named
resource deleters validate the optional Source handle, then use the separately
stored native name at the direct driver boundary and the wrapper ID for adapter
map removal. This preserves actual deletion and retained/public identity while
correcting the Source handle API value.

Genuine driver preallocation and three fresh binding queries force all three
identities apart, check Source creation ID 1, and verify the intended native
buffer is deleted while independent native buffers survive. Further cases
cover eleven named-resource families, raw 0/nonzero getter-created records,
Sync consuming the shared counter with base handle 0, and shader IDs continuing
through real loss/restoration. Driver-only fixtures now pass native_name() to
GL rather than interpreting a Source proxy ID as a native name. Nine typed
files pass in `source-object-proxy-id-native-corrected-gc-none.log` and seven
public files pass in `source-object-proxy-id-public-gc-none.log`. An initial
new-fixture compile error used `float` instead of the existing `gl_float`
constant; that diagnostic remains in `source-object-proxy-id-native-gc-none.log`.
The exact allocate-before-native-fence ordering then passed both affected
object/sync files in `source-object-proxy-id-sync-order-gc-none.log`. All use GC
disabled and explicit private module paths.

This Source record/allocator repair supersedes the historical native-name
interpretation of m_handle and lost-shader present-zero handle assertions.
The actual compositor replayer resolves object arguments through
WebGLObjectMap, including raw getter-created numeric handles. The current direct
adapter preserves its existing genuine native behavior and does not establish
full remote ID-map/command-dispatch equivalence, including that unusual getter
case. Broader lost dispatch suppression, GLsync API values, remote transport
and full GC/WrapperWorld remain independent scopes.

createShader now follows the generated command suppression boundary after real
context loss. GLFunctions.json:945 categorizes glCreateShader as `gen`, not
`sync`. generate_libweb_webgl_proxy.py:89-104 allocates a WebGLObjectId, records
CreateShader and returns that ID; ProxyBase.h:74 unconditionally increments
m_next_object_id, starting at 1. ProxyBase.cpp:57-60 discards the command when
lost. WebGLRenderingContextImpl.cpp:472-485 therefore still constructs its owned
shader record, with a nonzero proxy ID after the tested losses, while no host
shader creation runs. The V direct adapter now preserves its allocated ID and
owned record but skips native selection/creation when lost. Its native name 0
represents the absent compositor mapping, not a Source proxy ID of 0.

The compositor generator's emit_gen_body maps command.id independently to the
actual glCreateShader result; WebGLObjectMap.cpp:32-46 returns native 0 for an
absent map entry. This review supersedes the earlier description of
createShader as a synchronous lost-default0 operation and the probe's assumed
Source expected native name. The genuine earlier probe did demonstrate an
unwanted shader allocation in the already-current other context. Its corrected
Source scope is generated into
`Build/audit-fixes/source-create-shader-generated-boundary.txt` without changing
upstream files. The separate Source WebGLObject handle API repair must preserve
this proxy-ID/native-name distinction; existing historical zero-handle assertions
are not evidence for a Source proxy ID of 0.

Both-version native and public cases lose the real EGL owner, make another
actual context current, preserve its shader/source, viewport and pending driver
error, and check two new distinct owned IDs/brands. Three native creation/owner/
shader files pass in `source-shader-lost-command-native-gc-none.log`. The first
public attempt failed at compilation because my new fixture read a private
context registry; only the fixture was corrected to inspect the actual host
registry. All three public creation/owner/host files then pass in
`source-shader-lost-command-public-corrected-gc-none.log`, with the initial
compile diagnostic retained separately. All checks use GC disabled. Broader
lost dispatch suppression, GLsync proxy handles, remote command transport and
full GC/WrapperWorld remain separately scoped.

createShader now preserves the genuine invalid-type return from pinned
WebGLRenderingContextImpl.cpp:472-485 before actual native selection. Four
invalid GLuint type cases return null/INVALID_ENUM without changing the other
driver or allocating a shader record; V had selected its native context before
this CPU gate. Valid vertex/fragment types still reach the original native
createShader generated command boundary (GLFunctions.json:945), select the
actual host owner on dispatch and retain the native adapter result. The existing
valid-type zero-name ownership logic is unchanged by this focused gate repair.

Both-version typed/public cases verify invalid/valid type owners, real shader
type readback, native-before-Source pending errors and author conversion throws
before entry. Existing genuine ANGLE-zero loss/restore and public record-brand
fixtures remain intact. Only the invalid-type branch in the historical native/
public shader mutation owner fixtures was migrated to leave the other context
current; other mutation gates remain distinct pending Source reviews. All
three native shader-creation/mutation-owner/shader and three public shader-
creation/mutation-owner/host files passed with GC disabled. Logs are
`Build/audit-fixes/source-shader-create-owner-gc-none.log` and
`Build/audit-fixes/source-shader-create-owner-public/` in the second private
worktree. The former blanket native-before-body owner claim below is
superseded for this gate; no general prefix or loss-boundary parity is claimed.

getAttribLocation now preserves the handle-error return from pinned
WebGLRenderingContextImpl.cpp:891-904 before actual native selection. Foreign
or invalidated program handles report INVALID_OPERATION and return -1 while
the other driver remains current. Owned handles reach the existing original
glGetAttribLocation call with the null-terminated name; synchronous dispatch
at GLFunctions.json:1935 and the actual Host receiver select its owner. No
name/index validation or query result cache is introduced. Both public classes
keep the Source required program plus DOMString conversions before body entry.

Both-version native witnesses compare real unlinked-program results/errors,
successful/missing/reserved and embedded-NUL names, early foreign/deleted
handles and native-before-Source pending errors. Public tests verify linked
attribute results, the original C-string embedded-NUL boundary, distinct early
and driver owners, and DOMString conversion/author throws before the program
handle check. The two native attribute-location/active-info and corresponding
two public files passed with GC disabled. Logs are
`Build/audit-fixes/source-attrib-location-owner-gc-none.log` and
`Build/audit-fixes/source-attrib-location-owner-public/` in the second private
worktree. Other resource mutation/diagnostic handle gates remain separate
Source scopes; this does not claim complete string binding or remote parity.

getActiveAttrib/getActiveUniform now preserve the actual Source handle-error
boundary from pinned WebGLRenderingContextImpl.cpp:825-865. Foreign or
invalidated program handles return null/INVALID_OPERATION before selecting a
native driver. The existing native_active_info helper selects the owner at
the original query, preserving the fixed 256-byte name capacity, initialized
size/type/length and a fresh WebGLActiveInfo even when the driver rejects an
index. The removed V prefixes had treated the empty Proxy make_current as a
native switch. Source GLFunctions.json:1756/1797 synchronous operations and
the concrete Host receiver provide the actual owner selection. Both classes
keep the same required program/GLuint conversions through their shared IDL.

Extended both-version typed/public witnesses preserve early owners for
foreign/deleted handles, genuine query owners and pre-existing driver errors
before pending Source errors. Existing long-name, record identity and invalid-
index empty-record checks remain. Public author index conversions occur before
entry and keep the other driver current on a throw. The two native active-info/
attached-owner and two public active-info/attached-record files passed with
GC disabled. Logs are `Build/audit-fixes/source-active-info-owner-gc-none.log`
and `Build/audit-fixes/source-active-info-owner-public/` in the second private
worktree. getAttribLocation is verified above; other program/shader handle gates
remain separate Source slices and no general prefix rewrite is claimed.

getAttachedShaders now preserves the complete absence of a driver operation
in pinned WebGLRenderingContextImpl.cpp:867-889. After validating only the
program's Source handle, it returns the actual retained vertex/fragment shader
records; empty, populated, foreign-program and deleted-program paths all leave
the actual current driver unchanged. The non-source native selection prefix
is removed. Public wrapping still returns fresh arrays, reuses actual shader
identity through the platform cache and first-exposes invalidated typed shader
records. No retained record, cache, resource lifetime or return algorithm is
changed by this correction.

The prior retained-record fixture expected an owner switch after a successful
retained-only call. That historical assumption is superseded by the concrete
empty WebGLContextProxyBase.h:44 prefix and this Source body's lack of any
query; its assertion now checks that the other driver remains current. Added
both-version witnesses cover empty results, retained deleted shader identity,
foreign/deleted-program errors and a pre-existing native error without an
implicit query. All three native attached-owner/diagnostic/program-order and
all three public attached-record/diagnostic/program-order files passed with
GC disabled. Logs are `Build/audit-fixes/source-attached-shader-owner-gc-none.log`
and `Build/audit-fixes/source-attached-shader-owner-public/` in the second private
worktree. These passes correct owner evidence from the historical attached-
record checks below; their retained identity/deferred-deletion evidence remains
valid. Other resource handle early returns remain separate Source slices.

getTexParameter now preserves every early extension/version/pname return in
pinned WebGLRenderingContextImpl.cpp:1942-1995 before actual native owner
selection. Unknown names, disabled anisotropy and WebGL1's unsupported names
return null/INVALID_ENUM without issuing a driver query. Accepted names still
select the owning driver and use the original robust integer/float ANGLE
queries with initialized output, preserving target validation and return
shapes. In particular, the pinned MAX_LOD/MIN_LOD cases query IMMUTABLE_FORMAT
through the float getter and return a Boolean; that Source behavior is retained
exactly. GLFunctions.json:2455/2485 synchronous dispatch and the actual Host
receiver supply native selection, rather than the empty Proxy prefix.

Both-version typed/public witnesses cover thirteen genuine early branches and
thirty-eight actual valid/invalid-target query comparisons, including real
enabled anisotropy in both ANGLE contexts, native-only texture bindings and an
immutable texture with independently set LOD values. They preserve integer/
Boolean/null shapes, pending Source versus genuine driver error order, actual
owner selection and public author throws before entry. Both public getter/
setter files passed under `Build/audit-fixes/source-texture-getter-owner-public/`.
The typed setter neighbor passed in `source-texture-getter-owner-gc-none.log`,
which also retains the new fixture's missing experimental-flag argument compile
diagnostic. After correcting only that test call, the new typed getter passed
in `source-texture-getter-owner-corrected-gc-none.log`; both logs explicitly
record real enabled anisotropy. These focused checks used GC disabled in the
second private worktree; this is a clean two-file public group plus native
neighbor/corrected-file passes, not a new clean full sweep. Other resource
handle early-return owners and retained-only getters remain separate scopes.

getRenderbufferParameter now keeps the ten accepted Source pname cases from
pinned WebGLRenderingContextImpl.cpp:1838-1862 ahead of native owner selection.
Unknown names return null/INVALID_ENUM before a query, even with an invalid
target. Accepted names still select the actual owning driver and forward the
original target to glGetRenderbufferParameterivRobustANGLE, preserving the
initialized GLint result and native target/binding error. Source RENDERBUFFER_
SAMPLES remains accepted by this body in both versions; GL owns any underlying
version error. Its generated sync operation is GLFunctions.json:2237 and
Host execute_sync_call supplies the actual native owner, not the empty Proxy
make_current prefix. No retained binding validation or numeric cache is added.

Both-version native/public witnesses compare all ten names for valid and
invalid targets using actual driver-only renderbuffer bindings and output/error
baselines, early owner preservation and genuine driver error priority. Native
checks also compare an unbound query; public conversion throws precede entry.
The two native renderbuffer getter/storage and two corresponding public files
passed with GC disabled. Logs are
`Build/audit-fixes/source-renderbuffer-getter-owner-gc-none.log` and
`Build/audit-fixes/source-renderbuffer-getter-owner-public/` in the second
private worktree. Texture extension/version gates are verified above.

getBufferParameter now preserves the genuine pname gate in pinned
WebGLRenderingContextImpl.cpp:906-930 before actual driver selection. Unknown
names return null/INVALID_ENUM with another actual context still current,
even when target is also invalid. SIZE/USAGE still reach the existing
glGetBufferParameterivRobustANGLE delegate with its initialized GLint output;
native binding/target errors retain their Source numeric zero return and
driver ownership. The empty Proxy prefix, generated sync operation at
GLFunctions.json:1978 and Host execute_sync_call select the owning driver only
on these real query branches. No target/binding gate or value cache is added.

Both-version typed/public witnesses verify early versus driver owner order,
driver-error priority over pending Source INVALID_ENUM, actual native-only
buffer bindings, integer/null shapes and public conversion throws before
entry. The two native buffer/vertex-getter and two corresponding public files
passed with GC disabled. Logs are
`Build/audit-fixes/source-buffer-getter-owner-gc-none.log` and
`Build/audit-fixes/source-buffer-getter-owner-public/` in the second private
worktree. Renderbuffer and texture query gates are verified above.

getVertexAttrib now preserves the absence of a context-selection prefix in
pinned WebGLRenderingContextImpl.cpp:2026-2098. Unknown names, WebGL1's integer
attribute name and a WebGL1 divisor query without ANGLE_instanced_arrays return
null with INVALID_ENUM before any actual driver selection. Selection now
occurs only on the float or integer driver-query branches. All original Source
return shapes and resource creation are retained, including fresh Float32Array
storage and a new WebGLBuffer record for each queried native binding name.
The unchanged getVertexAttribOffset invalid-name branch likewise precedes its
actual query. Both public classes include these methods through the original
WebGLRenderingContextBase IDL; the genuine pname version/extension gates remain.

The receiver boundary is concrete: GLFunctions.json:2636/2666 classifies the
robust float/integer getters as synchronous calls; the generator emits
send_sync_call, ProxyBase.cpp:168-176 flushes pending commands and invokes the
transport, and HostWebGLContext.cpp:145-150 selects the owning native context
before executing that query. The pointer getter's custom sync path is retained
in ProxyBase.cpp:409-422. The existing C delegates already use the original
robust ANGLE calls and output sizes. This fix changes only the early-versus-
query native selection order, adding no new getter rule or remote transport.

Both-version native/public witnesses use another actual context current for
every genuine early branch and real queries. Native checks also preserve a
pre-existing driver error ahead of the Source INVALID_ENUM, actual boolean/
integer/vector/pointer state, and repeated binding records' distinct identity
with the same native name. Public checks retain null/zero, fresh typed-array
buffer identity, distinct WebGLBuffer wrappers, booleans and numeric results,
and author conversion throws before entry. The native divisor neighbor passed
in `Build/audit-fixes/source-vertex-getter-owner-gc-none.log`; that initial run
also records a new-fixture compile error from using the byte-data helper for a
size allocation. After correcting the fixture to buffer_data_size, the new
getter file and object-lifetime neighbor passed in
`source-vertex-getter-owner-corrected-gc-none.log`. All three public getter/host/
captured-intrinsic files passed under `source-vertex-getter-owner-public/` in
the second private worktree. These are focused native passes plus a clean
three-file public group, not a new full-module sweep.

Signed and unsigned integer vertex vectors now call exact glVertexAttribI4iv
and glVertexAttribI4uiv span-pointer delegates, matching pinned
WebGL2RenderingContextImpl.cpp:503-511 and 520-528. Existing native signed int
and unsigned GLuint pointer helpers are reused; scalar entry-point
substitution is removed. Both genuine four-element minimum gates still report
INVALID_VALUE before a native command, including a conflicting invalid index.
Empty Source Proxy make_current leaves another actual driver selected on these
short-span returns; a forwarded command selects its owning driver. GL reads
exactly four original integer components from longer spans, as specified by
GLFunctions.json's four-element command payloads. The unified typed V context's
existing WebGL2 availability behavior and public WebGL1 method absence remain.

Native witnesses cover all eight signed/unsigned below-minimum lengths and
sixteen four/longer-span driver cases with independently reset exact signed
INT_MIN/INT_MAX and unsigned high-bit/UINT_MAX readbacks, valid/invalid indices,
owner selection and native-before-Source pending errors. Public tests cover
every short ordinary/typed-array list, exact full-width native readback,
unsigned wrapping, conversion of trailing sequence values, iterator/index/item
order, author throws before entry and WebGL1 method absence. All three native
integer-vector/integer-scalar/float-vector and all three corresponding public
files passed with GC disabled. Exact logs are
`Build/audit-fixes/source-vertex-integer-vector-gc-none.log` and
`Build/audit-fixes/source-vertex-integer-vector-public/` in the second private
worktree. Native integer getters supply driver witnesses; no public integer
CURRENT_VERTEX_ATTRIB algorithm or complete generated-binding claim is added.

WebGL2 vertexAttribDivisor now follows the pure command body in pinned
WebGL2RenderingContextImpl.cpp:537-541. Its final fabricated vertex-attribute
state-map write is removed. Every repository reference was reviewed: after
the separately translated base and integer pointer bodies, only this divisor
write read that map. The unused map field and VertexAttribState record are
therefore removed together. Genuine Source retained resource references stay
separate. The original native GLuint/glVertexAttribDivisor delegate and
driver-before-Source-pending-error order remain; the typed V WebGL2 class
availability guard and existing ANGLE extension entry point are unchanged.
GLFunctions.json:4565 describes a command, so the empty Proxy prefix and owning
Host replay boundary supply the actual driver selection.

Twenty independently reset native cases compare actual divisor readback and
errors for zero, ordinary, high-bit and UINT_MAX divisors across first/last
valid, first-invalid and UINT_MAX attribute indices. Public checks use native
driver baselines for the full-width values and signed GLint getter results,
invalid-index owner selection, numeric conversion order, throw-before-entry
behavior and WebGL1 method absence. All three native divisor/instanced-draw/
integer-pointer and all three public divisor/host/integer-pointer files passed
with GC disabled. Exact logs are
`Build/audit-fixes/source-vertex-divisor-gc-none.log` and
`Build/audit-fixes/source-vertex-divisor-public/` in the second private
worktree. Integer vector entry points are verified above; no new public getter
algorithm or full generated binding parity is claimed.

WebGL2 vertexAttribIPointer now matches the pure driver forwarding body in
pinned WebGL2RenderingContextImpl.cpp:530-535. The extra V size, stride,
negative-offset and absent-buffer gates and integer-pointer state-map write
are removed. Unlike the base pointer method, this Source body has no retained
ARRAY_BUFFER gate. The existing native dispatch preserves the signed size and
stride, GLenum and intptr_t offset without changing the original GL entry
point. Empty Proxy make_current plus the generated command and owning Host
replay boundary select the actual driver for every forwarded call. The unified
typed V context retains its WebGL2 availability guard; the public WebGL1 class
does not expose this method, preserving the existing class/IDL distinction.

Eleven valid/invalid index, size, type, stride and offset cases, each with and
without a bound buffer, compare independent real driver state and error
baselines, actual owner selection and native-before-Source pending errors.
Public tests cover conflicting invalid arguments with no buffer, actual
integer flag/stride/offset state, numeric conversion order and an author
conversion throw before driver selection. All three native integer-pointer/
base-pointer/state and all three public integer-pointer/base-pointer/host
files passed with GC disabled. Logs are
`Build/audit-fixes/source-vertex-integer-pointer-gc-none.log` and
`Build/audit-fixes/source-vertex-integer-pointer-public/` in the second private
worktree. Divisor state-map cleanup and integer vector entry points are verified
above. No full generated wrapper or remote driver parity is
claimed by these focused witnesses.

Base vertexAttribPointer now preserves exactly the retained ARRAY_BUFFER
reference/nonzero-offset gate from pinned WebGLRenderingContextImpl.cpp:2571-
2581. An absent actual Source reference returns INVALID_OPERATION before any
GL command. Deleted but retained actual records still count as present. The
extra V size/stride/negative-offset validation and pointer-state map write are
removed; all remaining arguments reach the original native pointer call.
The legacy deletion fixture's CPU map assertion now checks the real driver's
attribute-buffer binding after deletion instead.

Owner order follows the concrete seam: ProxyBase.h:44 has an empty make_current
prefix, GLFunctions.json:4709 classifies this call as a command, generated
Proxy code records the offset as GLintptr from uintptr_t, generated replay
restores the pointer bits, and HostWebGLContext.cpp:54-83 selects the actual
owning driver before replay. Read-only generated evidence is retained in
`Build/audit-fixes/source-vertex-pointer-generated-boundary.txt`; Python bytecode
writing was disabled in the readonly upstream checkout. The existing Native
dispatch/C intptr_t delegate supplies that real command boundary; no remote
transport or new pointer algorithm is claimed.

Both-version witnesses compare eleven valid/invalid index, size, type, stride,
alignment and signed-offset cases with independent actual driver state/error
baselines, including both present and absent retained slots. Genuine Source
early returns keep the other actual driver selected and precede conflicting
size/stride validation. A deleted retained buffer still reaches GL. Public
checks preserve the same early-versus-driver distinction, numeric argument
order, hook-free Boolean conversion, actual pointer state and throw-before-
entry owner selection. The three public pointer/host/vector files passed under
`Build/audit-fixes/source-vertex-pointer-public/`. Native deletion/state
neighbors passed in `source-vertex-pointer-gc-none.log`; the new fixture's
initial optional-expression C compiler failure is retained there. Its explicit
branch correction is recorded in `source-vertex-pointer-final-gc-none.log`,
which then exposed a test-only assumed deleted-buffer error: the actual driver
returned NO_ERROR. The final fixture now uses independently reset real driver
error evidence for that retained-deleted-object command and passed in
`source-vertex-pointer-driver-oracle-final-gc-none.log`; the implementation did
not change during either fixture correction. This is two native neighbor passes
plus the corrected new file, not a rerun clean three-file native group.
The integer-pointer and divisor bodies are verified above; their fabricated
state mirror is removed.

WebGL2 integer scalar attributes now call exact glVertexAttribI4i and
glVertexAttribI4ui delegates from pinned WebGL2RenderingContextImpl.cpp:496-501
and 513-518. Native C signed int and unsigned GLuint widths are preserved
without float conversion or vector-entry-point substitution. The two final
write-only vertex-value map updates are removed, together with the unused
context field. The unified V context's existing WebGL2 availability gate is
unchanged; public WebGL1 exposes neither scalar method, matching the Source
class/IDL boundary. Integer list minimum gates and vector pointer calls are
verified above; the former pointer/divisor state mirror is removed above.

Focused typed checks compare exact signed INT_MIN/INT_MAX and large signed
values, UINT_MAX/high-bit unsigned values, independent driver resets, last
valid/first invalid real attribute slots, owner selection and native-before-
Source error order. Public native readback verifies the same complete values,
including WebIDL unsigned wrapping of -1, actual throw-before-entry behavior,
argument conversion order and WebGL1 method absence. All three native integer-scalar/
state/float-scalar and all three public integer-scalar/float-scalar/vector files
passed with GC disabled. Results are under `Build/audit-fixes/source-vertex-integer-scalar-gc-none.log` and
`Build/audit-fixes/source-vertex-integer-scalar-public/` in the second private
worktree. Actual native integer queries are driver witnesses; this supplies no
invented public integer CURRENT_VERTEX_ATTRIB getter. The pinned Source
Float32Array getter and full runtime/WrapperWorld boundaries remain unchanged.

The four floating vertex-vector methods now forward their span pointer to
exact glVertexAttrib1fv/2fv/3fv/4fv entry points, matching pinned
WebGLRenderingContextImpl.cpp:2523-2569. They preserve the actual Source
minimum lengths 1/2/3/4 and error-before-command returns. Source
WebGLContextProxyBase::make_current is empty; short spans leave the other
actual driver selected, while a dispatched GL command selects its owner.
The former vector-to-scalar method substitution is removed. The existing
native glVertexAttrib4fv helper is reused and three thin ABI delegates supply
the remaining Source calls. No synthesized default vector or CPU index gate
is added; GL reads only the Source operation's components from a longer span.
Integer vector and divisor parity are verified above.

Both-version native witnesses cover every below-minimum length, including an
invalid index that must still take the genuine Source minimum gate; direct
driver comparisons cover valid and invalid indices, trailing values, NaN,
both infinities and signed zero. Independent reset baselines preserve owner
selection, driver-before-Source error priority and actual Float32 readback.
Public sequence and native Float32Array paths retain all four short-span
returns, longer-input component behavior and index/iterator/item conversion
order. All three native vector/scalar/state and all three public vector/scalar/numeric
files passed with GC disabled. Their results are under `Build/audit-fixes/source-vertex-vector-gc-none.log` and
`Build/audit-fixes/source-vertex-vector-public/` in the second private worktree.
These focused tests supplement the earlier frozen 109/79 revision only.

The four scalar floating vertex-attribute bodies now call the exact
native glVertexAttrib1f/2f/3f/4f entry points from pinned
WebGLRenderingContextImpl.cpp:2499-2521. The previous implementation fabricated
four-component defaults in a CPU map and delegated every scalar operation to
glVertexAttrib4fv. Those scalar mirror writes and default-value construction
are removed; GL supplies its own scalar defaults. Four thin native ABI
wrappers carry the original f32 arguments directly. No scalar CPU index gate,
float-to-integer logger conversion or substitute default algorithm is added.
The genuine Source list minimum-length gates and current list entry points
remain a separate scope. Integer attribute and pointer-state mirrors also
remain separate slices.

Both versions are checked against independently reset direct-driver scalar
baselines at slot zero, the real maximum's last valid slot and its first invalid
slot for all four component counts. NaN, positive/negative infinity, signed
zero and finite fractions preserve actual driver readback, owner selection and
native-before-Source error priority. Public tests compare real driver results,
preserve all four argument-conversion/throw paths, and verify index-before-x/y/
z/w conversion order and genuine Float32Array replies. All three native scalar/state/
capability files and all three public scalar/numeric/protocol files passed with
GC disabled. Their focused results are under
`Build/audit-fixes/source-vertex-scalar-gc-none.log` and
`Build/audit-fixes/source-vertex-scalar-public/` in the second private worktree.
These focused checks supplement the original frozen 109/79 result; no new
full-package or native-bundle claim is made.

The write-only capability and enabled-vertex-attribute maps are removed.
Pinned WebGLRenderingContextImpl.cpp:681-692, 715-725 and 2131-2134 forwards
enable/disable/isEnabled operations to GL; no capability-state map exists in
the Source context declarations. The V constructor/restore dither-map writes
and four setter mirror writes had no production readers. Actual GL supplies
defaults, state and validation throughout these unchanged native entry points.
The two obsolete capability fixture cache assertions now compare genuine
native glIsEnabled state after direct driver commands.

The extended capability fixture compares attribute enable/disable at zero,
the real maximum's last valid slot, the first invalid slot and UINT_MAX with
independently reset direct driver baselines. Both versions retain actual owner
selection, native-before-Source error priority and real enabled attribute
readback; no hardcoded index bound or CPU cache is introduced. State and
actual parameter-query neighbors and the public host fixture also pass. The
initial native group had two neighbor passes and a new-fixture compile error
for a nonexistent V constant; the corrected direct GL_MAX_VERTEX_ATTRIBS enum
fixture passed separately. Logs are
`Build/audit-fixes/source-capability-maps-gc-none.log`,
`source-capability-maps-corrected-final-gc-none.log` and
`source-capability-maps-public-gc-none.log` in the second private worktree.
This bounded cleanup is focused coverage after the original frozen 109/79
snapshot; vertex value/pointer mirrors and other Source-body comparisons remain
separate slices.

A separate compact-adapter followup now checks every protocol discriminator
(error, undefined, numeric and resource handle) with captured native own-property
intrinsics before reading it. Primitive replies never undergo an inherited
property lookup through boxing. This removes author Object.prototype/Number
prototype getter calls that the source's direct JS::Value or Float32Array
wrapping does not perform. Actual error records, Source undefined replies and
retained platform-resource identity still take their existing adapter paths.
The check captures hasOwnProperty and Reflect.apply before author replacement.
No WebGL source body, driver validation or source conversion order changed.

The genuine prior failure witness is retained in the first private checkout at
`Build/audit-fixes/source-number-discriminator-probe.{v,log}`. In both WebGL
versions inherited error and webglUndefined getters intercepted finite/infinite
polygon-offset scalars and actual NaN attribute arrays; inherited handle also
intercepted the finite scalar. The followup's real-driver regression installs
all four inherited getters on Object and Number prototypes, checks NaN, both
infinities, negative zero, fresh Float32Array buffers and retained buffer
identity, and verifies the actual foreign-program getActiveUniforms WebGL2 undefined/error branch.
It also replaces the captured helper properties themselves. Initial validation
passed; the final numeric/intrinsic/host neighbors passed under the separate
`08-protocol-followup/Build/audit-fixes/source-reply-discriminator-final/`
private worktree. The new fixture initially used the wrong foreign-program
API (getActiveUniformBlockParameter returns null). After comparison with pinned
WebGL2RenderingContextImpl.cpp:1151-1161, it uses the actual getActiveUniforms
undefined branch and passed separately in
`source-reply-discriminator-corrected-final-gc-none.log`. The original fixture
failure is retained; this is three neighbor passes plus the corrected new file,
not a claim of a rerun clean four-file group. The first worktree's 4ef932b1 full sweep stays immutable and
has its original revision scope; this followup is separate focused coverage.

The compact JSON compatibility adapter now preserves exceptional numeric
values in both directions. Pinned `WebGLRenderingContextImpl.cpp:1194-1207`
returns queried polygon-offset GLfloat values through `JS::Value`, and
`:2026-2036` copies four actual CURRENT_VERTEX_ATTRIB floats into a new
`JS::Float32Array`. Those source algorithms are unchanged. Previously the
JSON encoder emitted invalid `nan`/`+inf` tokens for real driver replies, and
JSON.stringify converted scalar/list input negative zero to positive zero.
Actual failures are retained in
`Build/audit-fixes/source-nonfinite-parameter-probe.{v,log}` and
`source-nonfinite-vertex-probe.{v,log}`; both WebGL versions threw real JSC
JSON parse errors.

The adapter tags only NaN, positive/negative infinity and negative zero.
Canonical exceptional strings reuse the translated WebIDL/LibJS number
formatter; negative zero has an explicit transport spelling because Source
Number::toString intentionally returns "0". Reply decoding uses the engine's
unary-plus conversion of that primitive string, and captured Float32Array
construction receives the decoded numeric primitive. Scalar/list input keeps
negative zero before JSON serialization. The captured native own-property
check avoids author prototype getters when recognizing internal number tags.
No fabricated GL backend, getter clamping, alternate source getter algorithm,
or complete generated-wrapper/WrapperWorld parity is introduced.

`canvas_webgl_number_transport_test.v` first writes and reads real driver
vertex attributes containing NaN, both infinities and negative zero, then
checks the public fresh Float32Array/prototype/backing-buffer identities.
Scalar, sequence and native typed-array inputs preserve the same driver
values. Scalar polygon-offset replies are compared with direct driver queries,
including the driver's own NaN normalization. Replaced Number.isFinite,
String and Float32Array globals and an inherited number-tag getter are never
invoked. Initial focused validation passed; all four final new/intrinsic/raster/host
files passed with GC disabled, recorded under
`Build/audit-fixes/source-number-transport-final/`. This is a numeric
compatibility boundary repair, not a change to the GL Source implementation
or a claim about arbitrary NaN payload bits or full source runtime ownership.

`pixel_storei` now follows the exact switch and final GL call in
`WebGLRenderingContextImpl.cpp:2246-2282`. Only UNPACK_ALIGNMENT has source
early validation; nonnegative WebGL2 unpack row/skip values update the real
client bitmap-unpack state, while all remaining GL names/values reach the
driver. Browser-only flip/premultiply/colorspace branches return without a GL
command. The source prefix is the empty `WebGLContextProxyBase::make_current`,
so those returns and invalid UNPACK_ALIGNMENT leave the other actual driver
selected. Actual owner selection occurs at the final command. This corrects
the earlier browser-field fixture's assumed unconditional native switch.
The unused duplicate unpack alignment and fabricated pack-alignment cache were
removed. The latter's sole consumer was the existing non-IDL convenience
readback allocator; it now queries actual GL_PACK_ALIGNMENT and uses the same
unchanged allocation-size helper. The public source readback body remains
destination-view-length and robust-byte-count based; no new allocation
algorithm is claimed for it.

Both-version genuine Source early-return witnesses and thirty-one actual
driver name/value cases preserve native-before-source error priority. Real
1x2 RGBA readback after a direct Driver pack-alignment8 write verifies both
rows and the required padded capacity. Public author conversion precedes entry.
Original failures remain in `source-pixel-store-reproduction-gc-none.log`:
an early branch changed the actual owner, and invented pack validation returned
1282 instead of the driver's 1281. All four native new/browser/query/readback
files passed in `source-pixel-store-gc-none.log`; both public new/host files
passed in `source-pixel-store-public-gc-none.log`. This later source slice
supplements the unchanged frozen 101/70 sweep.

The unused generic parameter map, its invented default-state table, constructor
and restoration writes, final pixel-store write, and newly unused scalar
factory were removed in a separate bounded cleanup. Repository-wide references
showed initialization/write sites only; `get_parameter` already reads actual GL
or the distinct source retained-object/browser-only slots. The source Base/Impl
headers contain no such generic map. The source's real bitmap-unpack state
remains: focused witnesses write actual GL state independently and query those
driver values, while preserving the separately retained client alignment and
row length used by bitmap conversion, following source
`WebGLRenderingContextImpl.cpp:2246-2282`. The native query/browser-pixel-store/
state trio passed in `source-generic-state-map-gc-none.log`; both public stencil/
host neighbors passed in `source-generic-state-map-public-gc-none.log`. This
cleanup supplements the frozen 101/70 sweep without adding new reset/default
behavior or modifying the remaining pixel-store validation branches.

All six stencil setters now follow the plain GL calls in
`WebGLRenderingContextImpl.cpp:2332-2378`. Invented comparison/operation/face
prevalidation and retained scalar-map writes were removed, together with the
two validation helpers that then had no callers. Twenty direct-driver cases
start both commands from independent identical baselines and compare the real
front/back functions, signed reference clamps, full-width masks and operations.
Both versions cover two owners and native error flags before source `m_error`.
Real point draws verify that a zero write mask prevents a failed stencil test
from replacing the stored reference, while enabling the mask and fail-replace
operation allows the next equal-reference draw to change blue pixels to red.
Public witnesses cover all six IDL conversion paths, real getter state, and
Driver validation priority. The pre-fix owner failure remains in
`source-stencil-reproduction-gc-none.log`. All three native new/masked-rendering/
state files passed in `source-stencil-gc-none.log`; both public new/masked-
rendering files passed in `source-stencil-public-gc-none.log`. This subsequent
source slice supplements the unchanged frozen 101/70 sweep.

Depth-range, line-width, polygon-offset and sample-coverage setters now follow
the unrestricted float calls in
`WebGLRenderingContextImpl.cpp:645-649,2227-2231,2284-2288,2300-2304`.
The fabricated line-width early error, retained line/depth fields, CPU cache
clamps and generic polygon/sample writes were removed. Floats pass directly
to the native ABI without integer logging conversions; `depth_range` and its
public bridge now use the source float type. The now-unused CPU clamp helper
was removed. Seventeen native cases use independent identical driver baselines
before direct and translated commands, covering fractional and invalid sizes,
reversed depth endpoints, NaN and both infinities, native clamp/state/error
results, two owners and native-before-source error priority. Public non-finite
oracles and throwing numeric conversions retain source ordering, and sample
coverage's boolean argument does not invoke an author numeric hook. The initial
line-width owner failure remains in
`source-raster-float-reproduction-gc-none.log`. All three typed
new/rendering/state files passed in `source-raster-float-gc-none.log`; both
public new/host files passed in `source-raster-float-public-gc-none.log`.
These focused checks supplement the unchanged frozen 101/70 sweep.

Cull-face, depth-function, front-face and hint setters now follow the plain GL
calls in `WebGLRenderingContextImpl.cpp:495-499,633-637,813-817,2107-2111`.
Their invented CPU enum/extension gates and generic scalar-cache writes were
removed. Actual driver state and error flags own validation; the distinct
source derivative-hint getter gate remains intact. Fifteen direct-driver
oracles cover valid/invalid enum combinations in both versions, before and
after an actual WebGL1 derivative extension request, two owners and native
error priority over retained source errors. Public numeric conversion still
precedes body entry, and valid getters query actual driver state. The initial
owner failure remains in `source-raster-enum-reproduction-gc-none.log`. All
three typed new/rendering/state files passed in `source-raster-enum-gc-none.log`;
both public new/extension files passed in
`source-raster-enum-public-gc-none.log`. This focused slice follows the frozen
101/70 sweep and adds no new driver-validation algorithm. A subsequent focused
fixture improvement resets both direct and translated enum commands to
independent identical driver baselines; the strengthened file passed in
`source-raster-enum-baseline-final-gc-none.log`.

The clear-color/depth/stencil and color/depth-mask setters now contain the
source GL calls without five invented retained scalar fields, CPU cache clamps
or restoration writes. `clear_depth` and its public bridge now use the source
float ABI, following `WebGLRenderingContextImpl.cpp:390-412,639-643`,
`WebGLRenderingContextBase.idl:54` and unrestricted `GLclampf`. Actual getter
queries reflect direct driver writes. Two-version float/color/depth oracles
cover finite values, NaN and both infinities with native clamp/error behavior.
Real native and public point rendering verifies `[255,0,255,255]`: masked depth
and stencil clears preserve the values required by the draw tests, while the
color mask preserves the existing blue channel. Prior native errors remain
available after the actual native setters/clear/draw/readback. Public numeric
exceptions precede body entry, and boolean mask conversion does not invoke
author numeric hooks. The four native new/callback/framebuffer/state files
passed in `source-clear-setters-gc-none.log`; the public new/host pair passed in
`source-clear-setters-public-gc-none.log`. These checks supplement the frozen
101/70 sweep; the separately translated clear callback ordering remains intact.

All five blend setters now match the unconditional GL bodies in
`WebGLRenderingContextImpl.cpp:345-373`. Extra enum/extension/factor predicates,
the unused retained blend-color field and generic blend-cache writes were
removed. Unrestricted float colors reach the actual GLfloat ABI without a
fabricated integer logging conversion or CPU clamp, following
`Types.idl:10-11` and `GLFunctions.json:249-333`. Getter state remains the real GL
state; genuine extension/query gates elsewhere are unchanged. Direct-driver
oracles cover sixteen valid/invalid enum and factor cases in both versions,
before and after a real WebGL1 extension request, including independent RGB
and alpha factors, constant-factor errors, native-before-source error priority
and two owners. NaN and both infinities use actual driver color/error oracles.
Native and public real point draws verify the additive `[64,0,64,255]` pixel,
including native commands after a prior actual GL error. Public throwing IDL
conversion remains before all five source bodies. The meaningful pre-fix owner
failure remains in `source-blend-reproduction-gc-none.log`. All four native
new/state/parameter/extension files passed in `source-blend-gc-none.log`; all
three public new/extension/host files passed in `source-blend-public-gc-none.log`.
This later focused slice supplements the unchanged frozen 101/70 sweep.

Viewport and scissor now follow the actual GL commands in
`WebGLRenderingContextImpl.cpp:2306-2310,2584-2588`, without invented CPU
dimension rejection or retained scalar fields. The native viewport mirror and
its non-source getter were removed; the five surface-allocation fixtures now
query the actual GL viewport. Real allocation still sets the driver viewport,
while a size change alone does not fabricate new state. Direct-driver oracles
cover zero, negative and maximum dimensions in both versions, two owners,
native-error priority over source `m_error`, and the actual clear pixels after
a rejected scissor. Public witnesses also preserve throwing IDL conversion
before body entry. The initial oracle used different valid baselines and
failed; that diagnostic remains in `source-viewport-scissor-gc-none.log`, whose
three neighbors passed. The corrected new test and migrated surface fixture
passed in `source-viewport-scissor-final-gc-none.log`. The new public file passed
in `source-viewport-scissor-public-gc-none.log`; an incorrect neighbor filename
in that log is retained, and both actual integration/host neighbors passed in
`source-viewport-scissor-public-neighbors-final-gc-none.log`. This subsequent
focused slice supplements the unchanged frozen 101/70 sweep.

Actual GL errors now remain in the real ANGLE driver until `get_error_value()` asks
for them, following `WebGLRenderingContextBase.cpp:315-332` and
`WebGLRenderingContextImpl.cpp:1720-1724`. The eager collection helper and all
its call sites, four separate uniform/vector/matrix error queries, and the
dispatcher's fabricated boolean success facade were removed. GL's actual
native names, sync pointers, reflection values, robust read counts and surface
status results remain the source results. CPU presentation/readback retains
its actual allocation/backend/surface guards and no longer fails solely on an
unrelated earlier GL error, matching
`Services/Compositor/OpenGLContext.cpp:478-542` and
`HostWebGLContext.cpp:178-198`. The extension request is a void GL command in
`GLFunctions.json:3068`; it likewise has no source driver-error success gate.

Source local transport/allocation errors retain their separate pending slot
and priority. Actual GL flags are returned next in the driver's own order,
followed by the first source `m_error`; the source's one-error TODO is preserved
without an invented V queue. Genuine two-error direct-driver oracles cover both
versions, successful intervening queries/resource/log reads, extension
requests, real CPU pixels/presentation and public foreign-buffer validation
priority. The original failing native reproduction and public field-access
compilation diagnostic remain in the focused logs. Corrected focused native,
public and matrix checks passed; the final implementation then passed the
complete frozen 101-file typed and 70-file public sweeps above. No fake backend,
driver-error sorting, reinjection or new uniform read algorithm was supplied.
The named `get_error_value()` body was completed in a subsequent focused slice:
its former unused read-only peek was replaced by the exact mutable base body.
The initial focused named-body checks passed in
`source-base-error-value-gc-none.log` (three files) and
`source-base-error-value-public-gc-none.log` (two files), but subsequent review
identified the missing concrete proxy/host receiver boundary. Those checks did
not establish final receiver parity.

Pinned `WebGLRenderingContextBase.h:53` returns a `WebGLContextProxy`;
`WebGLContextProxyBase.h:44` defines its `make_current()` as empty. `glGetError`
is a sync operation in `GLFunctions.json:2008-2011`: the proxy generator sends
`SyncCalls::GetError`, `send_sync_call()` flushes and calls its transport, and
`HostWebGLContext.cpp:147-150` selects the owning actual GL context before the
generated replayer invokes `gl.get_error()`. The V native error receiver now
models that actual synchronous boundary. The base loss/local-error returns
precede it; `get_error()` delegates without an earlier native owner switch.
The source's lost-proxy zero result remains distinct from a live driver query.
No remote transport implementation is claimed for the direct native adapter.

Genuine two-owner witnesses seed independent INVALID_ENUM and INVALID_VALUE
flags, query the correct owning driver without consuming the other's flag,
retain source-error priority, and verify that public and standalone local/loss
early returns leave the other driver selected. The public local-error witness
failed before the repair, selecting viewport `[1,2,3,4]` instead of the other
driver's `[9,10,11,12]`; the diagnostic remains in
`source-error-receiver-public-reproduction-gc-none.log`. Generated source
GetError proxy/replayer evidence is recorded in
`source-get-error-generated-boundary.txt`. The corrected native helper and
driver neighbor passed in `source-error-receiver-gc-none.log`; that log also
retains an incorrect priority-neighbor filename diagnostic. The actual priority
neighbor passed separately in `source-error-receiver-priority-final-gc-none.log`.
All three public receiver/driver/host files passed in
`source-error-receiver-public-gc-none.log`. These checks supplement the unchanged
frozen 101/70 sweep; this subsequent receiver repair was not in that snapshot.

Destination-view and numeric pixel-pack `read_pixels` bodies now select their
owner before source range/binding errors and issue their actual GL calls
without the V dispatcher's invented boolean success gate. This follows
`WebGLRenderingContextOverloads.cpp:93-123` and
`WebGL2RenderingContextOverloads.cpp:426-487`. Public live buffer-witness
validation likewise follows source owner selection after IDL conversion.
The nullable WebGL1 body selects the owner before INVALID_VALUE; the distinct
WebGL2 nullable Empty branch at `:413-423` still returns before owner selection.
Real driver readback after an earlier GL_INVALID_ENUM verifies destination
bytes and a genuine pixel-pack buffer, preserving surrounding sentinel bytes.
Two-version owner witnesses cover range/binding errors, null-overload order,
public detached storage where the host supports transfer, and author numeric
exceptions before source entry. All three typed files passed in
`source-read-pixels-order-gc-none.log`; all three public files passed in
`source-read-pixels-order-public-gc-none.log`. The genuine robust GL byte count
continues to govern readback; no GL-error queue or new read algorithm is added.

`active_texture` now follows `WebGLRenderingContextImpl.cpp:123-127` directly:
select its owning context and issue GL's void command. The V-only
`active_texture_` slot, reset write and conditional success write were removed;
neither the source method nor its retained context state defines that cache.
Both versions verify actual native texture-unit selection, invalid-enum driver
behavior, a valid selection despite an earlier driver error, owner switching
and the real `ACTIVE_TEXTURE` query. Public numeric conversion still precedes
source body selection, including a throwing author `valueOf()` witness.
Two native binding neighbors passed in `source-active-texture-gc-none.log`;
the new native file passed after fixing its test field spelling in
`source-active-texture-final-gc-none.log`. All three public files passed in
`source-active-texture-public-gc-none.log`. This removes source-body cache/gates;
the actual-driver error-retention boundary is recorded separately above.

`native_egl.h`/`native_egl.c.v` create real EGL/ANGLE contexts using the Metal
backend on macOS and the source compositor configuration. `pkg-config egl
glesv2` resolves those libraries. Context loss destroys the native namespace;
restoration creates a fresh context.

The direct backend executes the translated buffer/vertex commands, indexed and
instanced draws, raster state, shader compilation/linking/reflection, typed
uniforms, GPU queries, samplers, sync, vertex arrays, transform feedback,
uniform blocks, internal-format queries, 2D/3D/compressed textures, framebuffer
attachments, multisample allocation/blits, read/draw buffers, invalidation,
and robust readback. Object names, limits, extension support, framebuffer
completeness, compile/link status, and query results come from the driver.

`HTMLCanvasElement` creates that real context, preserves its identity, resizes
its drawing buffer, and presents native pixels through the retained canvas
surface registry. The JavaScriptCore host binding reaches those same objects
and native commands, including the ANGLE instancing, WEBGL draw-buffers, and OES
vertex-array extensions. Script-created canvases retain the same DOM owner
when inserted. Public bindings retain actual BufferSource brands, generated
fixed-length/shared backing-store restrictions, late detached witnesses,
element-count spans, destination views, and pixel-pack-buffer offsets before
actual execution. TexImageSource uploads use live canvas/image/video frames or
ImageData and translate the source Skia export, including flip, scaling,
color-space, and alpha conversion. ImageBitmap and OffscreenCanvas objects
still require complete script object bindings. The upstream OffscreenCanvas
WebGL getter itself remains explicitly unimplemented.

`get_program_parameter` and `get_shader_parameter` now follow
`WebGLRenderingContextImpl.cpp:1778-1817` and `:1859-1888`: make the context
current, validate the source object handle, query the actual driver, then
interpret the source pname table. DELETE_STATUS uses the native flag, including
deferred GL deletions of current programs and attached shaders, rather than V
wrapper invalidation. Unknown native pnames preserve both the driver error and
the subsequent source INVALID_ENUM fallback. The two-version typed case, actual
public Boolean/error case, and program-extension neighbor passed with GC disabled
(three focused files).

`get_buffer_parameter` follows `WebGLRenderingContextImpl.cpp:906-928` without
an invented retained-buffer prerequisite. The source selects the pname, queries
a zero-initialized GLint with `glGetBufferParameterivRobustANGLE`, and returns a
numeric result even when the driver reports an invalid target or missing
binding; only unsupported pnames return null with source INVALID_ENUM. Actual
native bindings and usage/size changes are visible independently of V maps.
The two-version typed source case, public numeric/error case, and native draw
neighbor passed with GC disabled (three focused files).

The V `get_vertex_attrib` buffer-binding branch and actual host binding now
follow `WebGLRenderingContextImpl.cpp:2038-2042`, which creates a fresh
`WebGLBuffer` record for every queried handle, including zero. It does not
reuse the originally bound wrapper or return null for an empty binding.
Each record wraps the queried native handle and remains usable by source GL
operations; no native buffer is generated by reflection. Two typed fixtures
that expected reused/null records were migrated to native-handle assertions.
The two-version typed/public identity cases and both migrated files passed with
GC disabled (four focused files), including real WebGL2 byte mutation/readback
through a reflected wrapper. This preserves the pinned source's unusual empty
and invalid-index result records; it does not claim specification correction.

`get_active_attrib` and `get_active_uniform` now follow
`WebGLRenderingContextImpl.cpp:825-866`, including its fixed 256-byte name
buffer and unconditional record creation after the native query. Names truncate
to 255 bytes; an invalid native index returns an empty/zero WebGLActiveInfo
alongside INVALID_VALUE, while invalid source ownership still returns null with
INVALID_OPERATION. The former dynamic maximum-name allocation and zero-length
null substitution were removed. The two-version typed case, public branded
record/long-name case, migrated native shader fixture, and existing reflection
interface file passed with GC disabled (four focused files).

Remaining implemented predicate and pname queries now select their owning GL
context before null, invalid-enum, or foreign-handle returns, following the
source's initial `make_current` in `WebGLRenderingContextImpl.cpp`,
`WebGL2RenderingContextImpl.cpp:769-789`, `:967-981`, `:1121-1278`, `:1316-1332`,
and `Extensions/OESVertexArrayObject.cpp:64-79`. A focused native test leaves a
different context current, runs 36 early-return/browser-state cases across both
versions, and inspects the selected driver's viewport before subsequent API
calls can change it. The OES foreign-array branch preserves the source's
false-without-error behavior. That file and object/uniform-block/public-resource
neighbors passed with GC disabled (four focused files).

`bind_buffer` now follows `WebGLRenderingContextImpl.cpp:195-260`: select the
owner, validate the object handle and mutate its target compatibility, then
validate the version-specific target table and write the retained slot before
GL. An invalid first target therefore affects the source's later element-buffer
compatibility check; a foreign object takes INVALID_OPERATION precedence over
invalid-target INVALID_ENUM. A pre-existing real driver error cannot prevent
the retained slot from updating after a successful GL bind. The two-version
typed cases, public owner/target/driver-error case, lifetime and native draw
neighbors passed with GC disabled (four focused files).

`delete_buffer` and `delete_renderbuffer` now follow
`WebGLRenderingContextImpl.cpp:501-521` and `:571-592`: select the owner before
early returns, invalidate the source wrapper, and delete its native name without
clearing retained binding slots or vertex-buffer metadata. Binding queries keep
returning the original deleted wrapper until an explicit bind changes the slot,
even though native GL has unbound that deleted name. The deleted wrapper remains
invalid for subsequent binds. This deliberate pinned-source behavior is covered
by two-version typed and actual JavaScriptCore identity/error tests; those files,
the migrated native draw fixture, and the lifetime neighbor passed with GC
disabled (four focused files).

The retained buffer and renderbuffer slots now also own their actual typed
platform records, translating `WebGLRenderingContextImpl.h:154-174` and the
`visit_edges()` entries at `WebGLRenderingContextImpl.cpp:2594-2615`. Removing
the live native-name lookup entry no longer leaves only a numeric identifier.
Binding query results carry that same record through the host, whose wrapper
cache keys the actual platform-object address and reuses an existing wrapper
even after invalidation. A typed object first exposed after deletion receives
one wrapper rather than a fabricated null. The two ownership files passed
with default GC; those files plus deletion, native draw and lifetime neighbors
passed with GC disabled (five files). This translates the ownership graph of
these slots; full LibJS tracing and caller WrapperWorld ownership remain open.

Framebuffer attachment setters now follow
`WebGLRenderingContextImpl.cpp:734-809`: select their owner before all source
enum, level, binding and object-handle validation; issue the actual GL call;
then mutate the actual retained framebuffer's attachment map, including after
a driver error. The source's validation gates and its traced attachment map
remain intact. Tests exercise both context versions, foreign objects with
competing invalid inputs, missing bindings, differing driver/source framebuffer
bindings, real attachment-name queries, and mutation/removal after genuine
default-framebuffer driver errors. Four typed files passed with GC disabled in
`source-framebuffer-attachment-order-gc-none.log`. The public binding neighbor
passed in `source-framebuffer-attachment-order-public-gc-none.log`; the new
public owner/IDL-order/error case passed after its test-only private native-name
access was replaced with genuine GL binding queries, in
`source-framebuffer-attachment-order-public-final-gc-none.log`. This supplies
source method order and direct-driver behavior; full GC tracing, caller
WrapperWorld and remote transport remain separate boundaries.

Attachment OBJECT_NAME results now carry the actual retained texture or
renderbuffer, translating `WebGLRenderingContextImpl.cpp:1726-1776` and
`WebGLFramebuffer.{h,cpp}`. The existing host platform-object cache wraps that
record directly and reuses its wrapper; first exposure after native deletion
works after the live lookup entry has gone. The source intentionally keeps the
attachment record and reports its type/name even when GL has detached the
deleted native resource. The typed fixture compares the native NONE attachment
with that retained source identity. The public fixture checks first exposure,
brands, repeated wrapper identity, actual pointer/label retention, rejected
rebinding and repeated deletion in both context versions. Three typed files
passed in `source-framebuffer-attachment-record-gc-none.log`; the public source
ordering neighbor passed in `source-framebuffer-attachment-record-public-gc-none.log`
and the new public record fixture passed in
`source-framebuffer-attachment-record-public-final-gc-none.log`. The initial
public test used obsolete map-index option syntax; its compiler diagnostic is
preserved, and explicit map lookup corrected the fixture. All checks used GC
disabled. This preserves the source attachment graph without claiming full
LibJS tracing or caller WrapperWorld ownership.

Query begin/end now follow `WebGL2RenderingContextImpl.cpp:704-747`: select
the owner, validate only begin's source object handle, update the three actual
retained query slots before GL, and let the driver validate targets, active
queries and target compatibility. The invented `WebGLQuery.target_`/`active_`
fields and driver-success gates were removed; `WebGLQuery.{h,cpp}` only owns
its base resource record. The restricted retained map translates the three
source traced pointers (`WebGLRenderingContextImpl.h:172-174` and
`WebGLRenderingContextImpl.cpp:2611-2613`), and reset clears them as upstream.
Five typed files passed with GC disabled in `source-query-retained-gc-none.log`;
the new public source case and query enum neighbor passed in
`source-query-retained-public-gc-none.log` (two files). Cases compare genuine
GL current-query/error results with deliberately different retained slots after
duplicate begin, missing end, target reuse and unrelated pending errors. They
also cover all three targets, owner selection before invalid handles/targets,
and public IDL conversion before body entry. getQuery keeps the source's absence
of owner selection. The retained-record host wrapping described below preserves
that same body behavior; full GC tracing and remote transport remain open.

deleteQuery now selects its owner before nullable, foreign and already-invalid
resource returns, matching `WebGL2RenderingContextImpl.cpp:685-702`. Source
deletion invalidates the wrapper and deletes its native name while preserving
all three retained query slots. The typed case verifies actual glIsQuery state
and retained pointer identity after deletion, including a driver-rejected
retarget; public cases verify owner selection before all early returns and
IDL type rejection before body entry. Three typed files passed in
`source-query-deletion-gc-none.log` and two public files passed in
`source-query-deletion-public-gc-none.log`, all with GC disabled.

getQuery now wraps its actual retained query record, matching
`WebGL2RenderingContextImpl.cpp:749-770` and its generated nullable WebGLQuery
return conversion. A logical live-name lookup no longer substitutes null for
an invalidated query still held by a source slot. The existing platform-object
cache reuses one actual wrapper or first-exposes a deleted typed record, without
adding owner selection or body handle validation. The public fixture verifies
all three slots, genuine independent native query end/deletion, first exposure,
brand, pointer/label retention, repeated identity, rejected parameter queries,
repeated deletion and later slot clearing. Three public files passed in
`source-query-record-public-gc-none.log` and two typed source neighbors passed
in `source-query-record-gc-none.log`, all with GC disabled. This translates
the source ownership relationship through the compact host; full LibJS tracing
and caller WrapperWorld ownership remain open.

Sync waits/deletion now follow `WebGL2RenderingContextImpl.cpp:919-965`:
select the owner before foreign, null or already-invalid resource returns and
retain the native sync pointer after deletion, as `WebGLSync.cpp:39-58` does.
Source invalidation prevents later driver use; no extra null assignment mutates
the record. The native fixture verifies real glIsSync deletion while the exact
pointer remains retained, actual wait flag/timeout/null-handle driver errors,
and owner selection for every early return. Public fixtures check the same
ownership ordering and generated IDL type/numeric conversion before body
entry. Four typed files passed in `source-sync-owner-gc-none.log`; two public
files passed in `source-sync-owner-public-gc-none.log`, all with GC disabled.
The standalone pointer API repair below completes that record API; context-loss
transport and full GC ownership remain open.

The historical WebGLSync accessor slice separated actual native pointer
retention from compact wrapper IDs and preserved genuine driver query/deletion
behavior. Its five typed and two public files passed in
`source-sync-pointer-gc-none.log` and `source-sync-pointer-public-gc-none.log`.
That slice had not traced the generated fenceSync proxy-ID return, so the later
Source proxy-pointer storage/API repair above supersedes its handle-value
assertions. The actual native null/successful results and validation ordering
remain evidence for the direct adapter; they do not identify Source m_sync_handle.

The historical WebGLObject repair separated compact wrapper IDs from native
GLuint names and preserved actual native deletion/identity. Its eleven typed
and nine public files passed with GC disabled in
`source-object-handle-final-gc-none.log` and
`source-object-handle-public-gc-none.log`. Those driver observations remain
valid evidence for genuine native names and deletion, but its interpretation
of native_handle_ as Source m_handle was incomplete: it had not traced the
actual generated proxy-ID return and compositor map. The later Source proxy-ID
record/allocator repair above supersedes those handle-value assertions, while
preserving native driver names separately. The initial nonexistent VAO fixture
path diagnostic remains in `source-object-handle-gc-none.log`. Remote transport
and full GC/WrapperWorld still remain separate boundaries.

getAttachedShaders now wraps the actual retained shader records from
`WebGLRenderingContextImpl.cpp:867-889` and the generated
`sequence<WebGLShader>?` return. The source only validates the program; it
returns vertex then fragment pointers even after shader deletion. The host
no longer validates each shader's live handle or requires a live-name lookup.
Its platform-object cache reuses the existing branded shader or first-exposes
an invalidated typed shader directly; the obsolete live-only reply helper was
removed. The public fixture exercises both versions and both exposure paths,
checks distinct returned arrays with shared shader identity, source slot order,
actual pointer/label retention, invalidated shader operation rejection, and
program-deletion rejection. Genuine glGetAttachedShaders/glIsShader observations
confirm native deferred shader deletion while attached and final deletion after
the program is deleted. Four public files passed in
`source-attached-shader-record-public-gc-none.log`; three typed source neighbors
passed in `source-attached-shader-record-gc-none.log`, all with GC disabled.
The successful retained-only owner-switch assertion in that historical fixture
was subsequently corrected by the separate getAttachedShaders owner slice
above after reviewing the actual empty Proxy boundary. Full Source GC rooting
and caller WrapperWorld ownership remain open.

getParameter(CURRENT_PROGRAM) now returns and wraps the actual retained program
record from `WebGLRenderingContextImpl.cpp:1046-1050`, including first exposure
of a typed record. The source useProgram body retains the supplied program after
the driver call even when the native call rejects an unlinked program; the
getter therefore preserves that exact source record while a direct driver
query still reports native binding zero. Focused typed and public cases cover
both versions, actual pointer/label identity, repeated wrapper identity, owner
selection, use of the first-exposed wrapper, source slot clearing on deletion,
and rejection of later use of the invalidated record. Three typed files passed
in `source-current-program-record-gc-none.log`; three public files passed in
`source-current-program-record-public-gc-none.log`, all with GC disabled. This
preserves the pinned source retention order and does not invent a driver-success
gate. Full source GC and caller WrapperWorld ownership remain open.

getParameter(VERTEX_ARRAY_BINDING) now returns and wraps the actual retained
WebGL2 or OES vertex-array record (`WebGLRenderingContextImpl.cpp:1451-1462`).
It reuses existing public wrappers and first-exposes typed records through the
actual platform-object cache. Source extension/version gates and OES's
LegacyNoInterfaceObject behavior remain intact. Genuine direct GL deletion
resets the native binding to zero while the source retained slot still returns
the exact record; subsequent source deletion clears the slot and invalidates
that record. Typed cases verify both kinds, native/source distinction and the
OES gate. Public cases verify pointer/label identity, brands, repeated identity,
owner selection, and source WebGL2-error versus OES-silent rejection after
deletion. Three typed files passed in `source-vertex-array-record-gc-none.log`.
The two public neighbors passed in `source-vertex-array-record-public-gc-none.log`;
the new public file passed in `source-vertex-array-record-public-final-gc-none.log`
after its initial fixture incorrectly assumed an OES global constructor.
That initial ReferenceError remains in the first log. All checks use GC disabled;
full source GC and caller WrapperWorld ownership remain open.

Transform-feedback creation, bind/delete, varying selection and lifecycle
commands now select their owning context before source body gates, matching
`WebGL2RenderingContextImpl.cpp:983-1082`. The pinned source declares, traces and
resets m_transform_feedback_binding but never assigns it from bind or clears
it from deletion. The V-only binding/deletion writes and native-success gate
were removed; the existing optional source slot remains and is reset by
reset_client_side_webgl_state (`WebGLRenderingContextImpl.cpp:116`). Consequently
getParameter(TRANSFORM_FEEDBACK_BINDING) remains null while actual native binding
and capture work, preserving this upstream limitation without filling it with
a driver query or an invented retained algorithm. The old parameter fixture
now checks source null plus the actual driver's nonzero binding. Source owner,
foreign/deleted/null order, invalid-target driver errors and varying-program
validation pass in the new typed/public cases. Five typed neighbors, including
actual GPU capture/query counts, and the resource-interface public neighbor
passed in `source-transform-feedback-gc-none.log` and
`source-transform-feedback-public-gc-none.log`. The two new cases passed in
`source-transform-feedback-final-gc-none.log` and
`source-transform-feedback-public-final-gc-none.log` after their initial native
predicate incorrectly used an unsupported adapter kind; they now call genuine
glIsTransformFeedback directly. Initial diagnostics are preserved. All checks
use GC disabled; source TODOs, remote transport and full GC/WrapperWorld
ownership remain open.

Sampler bind/delete now select the owning context before nullable, foreign or
invalidated record gates and delegate to GL after the source handle validation
(`WebGL2RenderingContextImpl.cpp:803-833`). The V-only bound_samplers map, its
bind/deletion writes and restoration clearing were removed; the source has no
retained sampler binding slots. Existing getParameter(SAMPLER_BINDING) still
queries real GL and creates a fresh source sampler record every time, including
native name zero (`WebGLRenderingContextImpl.cpp:1673-1677`). Typed/public cases
verify shared driver binding across two units, fresh record/wrapper identity,
foreign/deleted/null owner order, real invalid-unit errors, actual driver
unbinding after deletion and preserved present-zero returns. The legacy sampler
fixture now queries GL after the rejected bind instead of inspecting the removed
map. Four typed files passed in `source-sampler-binding-gc-none.log`; three
public files passed in `source-sampler-binding-public-gc-none.log`, all with GC
disabled and no fixture failure. The separate source sampler parameter-name
switches remain, with the owner-first correction described below. Full source
GC, caller WrapperWorld ownership and remote transport remain open.

samplerParameteri and samplerParameterf now select the owning context before
source handle validation and the exact source parameter-name switches
(`WebGL2RenderingContextImpl.cpp:835-910`). All nine standard pnames and the
EXT_texture_filter_anisotropic enablement gate remain; no extra native value
validation was added. Genuine driver tests first obtain the result, reset each
parameter to a different valid baseline, then verify the translated integer or
float setter changes it to that exact value. Other typed cases cover foreign
and deleted handle precedence, blocked/enabled extension names, valid native
zero records reaching GL, fractional LOD readback and real invalid-value errors.
Public cases preserve generated IDL brand/null/numeric conversion before owner
selection and verify source gate/error order plus actual float readback. Three
typed files passed in `source-sampler-parameter-gc-none.log`; three public files
passed in `source-sampler-parameter-public-gc-none.log`, all with GC disabled
and no fixture failure. Source engine diagnostic logging and full GC/caller
WrapperWorld ownership remain separate boundaries.

framebufferTextureLayer now selects the owning context before optional texture
handle validation, matching `WebGL2RenderingContextImpl.cpp:131-145`. The source
body delegates target/attachment/level/layer validation to GL and does not
update the retained framebuffer attachment map; those existing boundaries stay
intact. Genuine driver cases compare all four error paths, read actual pixels
from the selected texture-array layer, detach through the nullable call and
verify source handle validation precedes driver errors after deletion or for a
foreign texture. Public cases verify the same actual layer pixels and owner
order while IDL brand/numeric exceptions still occur before method entry.
Two native neighbors passed in `source-framebuffer-layer-gc-none.log`; the new
native case passed in `source-framebuffer-layer-final-gc-none.log` after its
initial fixture supplied an extra argument to the typed convenience upload.
The initial compiler diagnostic is preserved. Both public files passed in
`source-framebuffer-layer-public-gc-none.log`. All checks use GC disabled;
full source GC, caller WrapperWorld ownership and remote transport remain open.

The three WebGL2 draw bodies now select the owner, mark the direct native
painting surface before GL, and run the concrete source canvas update hook in
its exact position (`WebGL2RenderingContextImpl.cpp:543-566`): before GL for
drawArraysInstanced/drawRangeElements, after GL for drawElementsInstanced. The
V-only negative count/offset/instance and start/end gates were removed; GL owns
those errors. The direct CPU presentation marker is now separate from
WebGL2RenderingContext::did_update_canvas_content's owning-canvas callback
(`WebGL2RenderingContext.cpp:77-85`); these three names no longer also invoke the
generic post-dispatch notification. Existing generic and ANGLE rendering
presentation adaptation remains. Real one-pixel draws verify exactly one
callback sees the pre-draw black pixel or post-draw red pixel according to the
source method, followed by actual red readback. Invalid-argument tests compare
direct driver results and retain owner selection and presentation notification;
actual EGL context loss still invokes the unconditional source canvas hook.
Six typed/HTML files passed in `source-webgl2-draw-order-gc-none.log`; the new
file passed again after adding the lost-context case in
`source-webgl2-draw-loss-gc-none.log`. Three public files passed in
`source-webgl2-draw-order-public-gc-none.log`, including IDL exceptions before
entry and actual ANGLE extension rendering. All checks use GC disabled with
no failures. The source proxy's make_current/notify hooks are currently empty
transport hooks (`WebGLContextProxyBase.h:44-45`); the direct GL/CPU surface
adapter remains explicit. Full source GC, caller WrapperWorld, remote GPU
transport and other draw/raster body comparisons remain separate work.

Ordinary drawArrays and drawElements now follow the same exact source body
order for both versions (`WebGLRenderingContextImpl.cpp:693-708`): owner and
native painting-surface marker first, canvas hook before array GL calls and
after element GL calls. The V-only negative count/offset gates and retained
ELEMENT_ARRAY_BUFFER-presence gate were removed; native validation and native
bindings govern drawing. These two names no longer receive a duplicate generic
post-dispatch canvas notification. Genuine shaders, triangle data and a
native-only element buffer produce red pixels while the source retained EAB
getter stays null. A one-call canvas witness observes black before array draws
and red after indexed draws. Actual driver error comparisons, owner selection,
notification despite rejected arguments and unconditional hooks after genuine
EGL loss pass for both versions. Six typed/HTML files passed in
`source-base-draw-gc-none.log`; three public files passed in
`source-base-draw-public-gc-none.log`, all with GC disabled and no failures.
Generated IDL conversion exceptions still precede Source method entry. The
direct CPU presentation adapter, full source GC/caller WrapperWorld ownership
and remote GPU transport remain explicit boundaries.

The concrete owning-canvas update callback now sets canvas dirty and requests
repaint with InvalidateDisplayList::No, matching both source concrete contexts
(`WebGLRenderingContext.cpp:165-173`, `WebGL2RenderingContext.cpp:77-85`). It no
longer requests .paint_commands from the DOM bridge. The native source fixture
uses actual canvas/context records and retained paintable callbacks to verify
the precise No invalidation, then confirms genuine red/blue GL surface changes
reach the existing external-content frame registry. Actual EGL loss still
reaches that canvas hook through a Source draw body. Three HTML files passed
in `source-canvas-webgl-repaint-gc-none.log` with GC disabled and no failures.
This preserves source retained-canvas repaint behavior; full source display-list
ownership, remote GPU surfaces and full GC/WrapperWorld integration remain
separate boundaries.

clear now selects the owner, marks the direct painting surface and invokes the
concrete Source canvas hook before GL (`WebGLRenderingContextImpl.cpp:382-389`).
The generic post-dispatch clear notification was removed to avoid duplicates.
Real one-pixel tests verify exactly one callback sees the old black pixel before
the translated clear writes red; actual driver errors retain owner selection
and dirty notification. Genuine EGL loss still reaches the source canvas hook.
Four typed/HTML files passed in `source-clear-order-gc-none.log`; two actual
public rendering neighbors passed in `source-clear-order-public-gc-none.log`,
all with GC disabled and no failures. The direct CPU surface adapter and full
source GC/caller WrapperWorld/remote transport boundaries remain explicit.

Buffer uploads now follow `WebGLRenderingContextOverloads.cpp:29-62`,
`WebGL2RenderingContextOverloads.cpp:33-85`, and
`WebGL2RenderingContextImpl.cpp:46-50`: select the owner, validate nullable data
or a source buffer witness, then forward to GL. No source upload requires a
retained binding lookup or maintains a CPU buffer-byte/usage mirror. Those
invented fields and the typed `bytes()` facade were removed; three legacy
fixtures now verify real GL readback. Actual driver bindings created outside
the retained source slots accept uploads, subrange writes, and copies. Both
versions preserve native enum/value/binding errors; public null and out-of-range
span failures select the owner before returning. The typed/public upload files
passed with GC disabled in `source-buffer-upload-final-gc-none.log`; the three
migrated neighbors passed in `source-buffer-upload-gc-none.log`. Initial runs
exposed and corrected test expectations and a private-field test access.
The pinned source's double-based 64-bit WebIDL conversion maps -1 to zero
(`WebIDL/AbstractOperations.cpp:553-558`, `LibJS/Runtime/AbstractOperations.h:314-324`);
public tests retain that behavior and use -4096 for negative driver inputs.
Source ByteBuffer/LibJS ownership and remote command transport remain separate
boundaries; the native GL storage is the actual storage for this adapter.

Indexed buffer and VAO binds now preserve the pinned source's retained-slot
behavior. `WebGL2RenderingContextImpl.cpp:1079-1119` forwards `bindBufferBase`
and `bindBufferRange` after handle/compatibility checks without assigning the
generic retained buffer slots, even though GL updates its generic binding.
`WebGL2RenderingContextImpl.cpp:1294-1349` and
`Extensions/OESVertexArrayObject.cpp:45-106` change only the retained VAO slot;
they never refresh the retained element-buffer slot from native GL. The extra
V driver-to-wrapper refresh and indexed cache writes were removed. Every bind
and delete selects its owner before source early returns, and an unrelated
pending GL error cannot prevent the VAO slot assignment after the driver call.
The typed retained-state case, migrated VAO fixture, transform-feedback and
upstream-entry neighbors passed with GC disabled (four files,
`source-retained-indexed-vao-gc-none.log`). Two actual public cases passed in
`source-retained-indexed-vao-public-gc-none.log`, verifying original wrapper
identity alongside different real GL bindings in both versions. These tests
preserve source behavior rather than claiming specification correction; OES
foreign-object silent returns retain the source FIXME.

Framebuffer/renderbuffer binding follows `WebGLRenderingContextImpl.cpp:263-299`:
select the owner, validate the actual object's handle, call GL, then assign the
retained source slot. Extra target prevalidation was removed. An invalid driver
target or unrelated pending GL error therefore still updates an owned slot;
a foreign/deleted handle returns INVALID_OPERATION first. The framebuffer slot
now owns the actual platform record (`WebGLRenderingContextImpl.h:157` and its
`visit_edges()` entry), carries that record through attachment/query paths, and
creates or reuses one branded host wrapper on first exposure. Source framebuffer
deletion clears the matching pointer after GL (`:523-542`); native restoration
adapters clear the new owner together with their existing numeric state.
WebGL2 `READ_FRAMEBUFFER` binding still changes the source's single retained
framebuffer slot even when the real draw binding differs. The new typed source
case and attachment/native-framebuffer/transfer/parameter-state neighbors passed
with GC disabled (five files, `source-framebuffer-binding-gc-none.log`). The
actual public invalid-target/foreign-handle/first-exposure case passed in
`source-framebuffer-binding-public-gc-none.log`. This translates those source
owning slots; complete LibJS tracing, cross-realm WrapperWorld behavior, and
remaining resource graph owners are still open.

Actual WebGL numeric conversion and typed query results now use captured
owning-runtime intrinsics. The source converts through engine `ToNumber`/
`ToString` and creates native `Float32Array`, `Int32Array`, and `Uint32Array`
records directly (`WebGLRenderingContextImpl.cpp:939-1466`, `:2027-2036`;
`WebGL2RenderingContextImpl.cpp:162-183`, `:1228-1236`). The compact adapter no
longer rereads mutable `Number.isFinite`, global `String`, or those global
constructors. Result arrays allocate by length and fill numeric elements without
iterating the private transport array. Original author ToPrimitive/iterator
hooks still run in source conversion order, and item errors retain the pinned
generator's no-IteratorClose path (`to_idl_value.py:845-869`). The poisoning/
brand/hook case passed with GC disabled in
`source-webgl-intrinsics-final-gc-none.log`; query-enum and buffer-slot neighbors
passed in `source-webgl-intrinsics-gc-none.log`. Initial new-fixture assumptions
about default-FBO draw errors and iterator closing were corrected against actual
GL and the pinned source generator; implementation behavior was preserved.
This covers those intrinsics, not all compact transport JSON/Array machinery or
full LibJS realm/builtin ownership.

Texture binding now follows `WebGLRenderingContextImpl.cpp:301-344`: select
the owner, validate the actual handle before the version-specific target table,
assign the retained slot, then call GL. `WebGLTexture.h` has no target-compatibility
field; V's invented `target_` gate was removed. Binding an actual 2D-native name
to a cube/3D/array target can therefore retain that same source record alongside
GL_INVALID_OPERATION, just as the pinned source does. Each slot owns its actual
texture record, supplies it to parameter queries, and reuses or first-exposes
one branded host wrapper. Deletion selects the owner, deletes the native name,
then clears every matching retained object pointer (`:603-632`). The two-version
typed source case and compressed/layer/nullable-upload neighbors passed with GC
disabled (four files, `source-texture-binding-gc-none.log`); the public first-
exposure/cross-target/identity/deletion case passed in
`source-texture-binding-public-gc-none.log`. These translate the texture binding
owners and source error ordering. Later source setter/upload slices remove the
invented texture parameter and geometry mirrors; full LibJS tracing and caller
WrapperWorld ownership remain open.

Renderbuffer storage now directly translates
`WebGLRenderingContextImpl.cpp:2290-2298` and
`WebGL2RenderingContextImpl.cpp:192-196`. The source selects the owner, maps
`GL_DEPTH_STENCIL` to `GL_DEPTH24_STENCIL8` for ordinary storage, and delegates
validation/allocation to the actual driver. V's invented retained-name gate,
size/sample prevalidation, and CPU format/size/sample record fields were removed
(`WebGLRenderbuffer.h` retains only its WebGLObject base). Driver bindings outside
the retained slot work for both ordinary and multisample storage. Actual packed
storage provides 24 depth bits and 8 stencil bits; ES2 may report its internal
format back through the unsized alias, which tests compare with actual mapped
driver allocation instead of a fabricated cache value. The new typed case passed
with GC disabled in `source-renderbuffer-storage-final-gc-none.log`, and the
framebuffer/transfer neighbors passed in `source-renderbuffer-storage-gc-none.log`.
The actual public two-version case passed in
`source-renderbuffer-storage-public-final-gc-none.log`. Initial new-fixture sized-
format expectations were corrected against real driver alias behavior. Remote
transport, full LibJS tracing and other remaining resource caches remain separate
boundaries.

Texture parameter setters now directly translate
`WebGLRenderingContextImpl.cpp:2368-2378`: select the owning driver, then forward
the exact integer/float parameter without a retained texture-name prerequisite.
The invented parameter maps were removed from the V texture record; queries
continue to inspect actual driver state. The unused integer conversion of float
command metadata was also removed, preserving the source float argument directly.
The new typed source case and actual public two-version case passed with GC
disabled (`source-texture-parameter-final-gc-none.log` and
`source-texture-parameter-public-gc-none.log`). Compressed/layer neighbors passed
in `source-texture-parameter-gc-none.log`; the initial new fixture used unexposed
V constant names and was corrected to the source GL enumerants. Cases use genuine
bindings outside retained source slots and compare competing invalid inputs with
actual driver error order. Other upload overloads, remote transport and complete
LibJS ownership remain separate source slices.

The 2D byte-view upload bodies now follow
`WebGLRenderingContextOverloads.cpp:121-237` and
`WebGL2RenderingContextOverloads.cpp:87-197`: select the owner, validate source
buffer witnesses and unpack state, then pass exact arguments and bounded bytes
to robust GL entry points. Extra V dimension/border prevalidation and the
subimage retained-name prerequisite were removed. The existing source
`texture_data_for_2d_upload` helper remains unchanged: invalid unpack state is a
source INVALID_OPERATION, while dimensions, borders, actual bindings and short
input storage reach GL. Nullable bodies and compact host span failures now
select the owning context before early returns. The remaining invented texture
geometry/format fields were removed (`WebGLTexture.h` owns only its WebGLObject
base); the legacy geometry fixture now verifies framebuffer completeness and
actual pixel readback. The two-version typed source case, migrated entry-point
fixture and nullable neighbor passed with GC disabled (three files,
`source-texture-upload-gc-none.log`). The actual public upload, element-span and
nullable cases passed in `source-texture-upload-public-gc-none.log` (three
files), including real driver bindings absent from retained source slots and
owner selection before a failed source span. Other upload overloads, upstream
TexImageSource TODOs, remote transport and complete LibJS ownership remain
separate boundaries.

Compressed uploads now preserve the initial owning-context selection and exact
source validation order in `WebGLRenderingContextOverloads.cpp:64-96`,
`WebGL2RenderingContextOverloads.cpp:200-229`, and
`WebGL2RenderingContextImpl.cpp:1352-1380`: reject disabled formats, validate
the input witness/span, then delegate geometry and target errors to GL. The
invented 2D dimension/border checks were removed; all four compact methods
select the owner before host-side format/span failures. The new typed source
file and existing native compressed sampling/layer file passed with GC disabled
in `source-compressed-upload-gc-none.log` (two files). The actual public source
case passed in `source-compressed-upload-public-gc-none.log`, including source
format-before-span precedence, owner selection and competing native errors.
The installed ANGLE compressed ABI adaptation below remains unchanged; this
slice translates source validation/delegation and does not claim unavailable
robust entry points or remote command transport.

WebGL2 3D byte-view and nullable uploads now directly follow
`WebGL2RenderingContextImpl.cpp:208-225`, `:244-252`, and `:265-279`:
select the owning driver, validate a non-null input witness/span, and forward
the exact dimensions, border and bytes to robust GL. Extra V geometry/border
checks were removed from the byte bodies; the separate bitmap overload's
source border check remains intact. Compact 3D span errors select the owner
before returning. The new typed source, actual texture-layer and nullable files
passed with GC disabled in `source-3d-upload-gc-none.log` (three files), including
layered readback through an actual texture binding absent from the retained
source slots and original driver error order for byte/null inputs. The actual
public source and effective-overload files passed in
`source-3d-upload-public-gc-none.log` (two files), preserving source element
offsets, genuine layer pixels and owner selection on invalid spans. Bitmap
source TODOs, remote transport and complete LibJS ownership remain separate
boundaries.

Bitmap upload bodies now select their owning driver before missing-frame,
ImageData-witness and bitmap-border returns, as in
`WebGLRenderingContextOverloads.cpp:196-213`, `:238-250`,
`WebGL2RenderingContextOverloads.cpp:121-160`, and
`WebGL2RenderingContextImpl.cpp:226-242`, `:254-263`. Their source frame,
conversion, alpha/flip/scaling and border logic remains unchanged. The new
two-version owner case and actual bitmap/layer pixel neighbor passed with GC
disabled in `source-bitmap-upload-owner-gc-none.log` (two files); the actual
public texture-source neighbor passed in
`source-bitmap-upload-owner-public-gc-none.log`. Missing image frames remain
silent while selecting the owner, and the existing source ImageData witness
and WebGL2 bitmap-border checks retain their errors before any GL call.
Upstream ImageBitmap/origin-clean TODOs and complete DOM/LibJS source bindings
remain explicit boundaries.

Nullable and bitmap uploads now issue their actual native texture calls after
the source's own gates, without conditioning them on the adapter's preceding
command logger/dispatcher error query. The pinned nullable bodies in
`WebGLRenderingContextOverloads.cpp:125-194`,
`WebGL2RenderingContextOverloads.cpp:87-130` and
`WebGL2RenderingContextImpl.cpp:211-275`, and all four bitmap native uploads in
`Services/Compositor/HostWebGLContext.cpp:119-145`, have no such success gate.
Before this repair an earlier genuine GL_INVALID_ENUM left an existing red
texture unchanged after a nullable zero upload, and prevented a bitmap image
from allocating at all. Actual 2D/array-layer pixels now verify all nine upload
bodies, including WebGL2 null pointers addressing a real pixel-unpack buffer.
Both versions retain the prior error while still issuing the command. Source
format/unpack/border/frame and bitmap-conversion gates remain intact.
`source-texture-prior-error-gc-none.log` passed four typed files;
`source-texture-prior-error-public-gc-none.log` passed three public files, and
the strengthened new public file passed separately in
`source-texture-prior-error-public-final-gc-none.log`. Original compilation
diagnostics and the meaningful failing pixel reproduction remain under
`Build/audit-fixes/source-texture-prior-error-*.log`. This slice removes the
upload cancellation gates; the separate actual-driver error-retention repair
is recorded above and is not supplied by these tests alone.

Framebuffer-to-texture copy now follows
`WebGLRenderingContextImpl.cpp:427-437`: select the owning driver and forward
every argument to GL. Extra V dimension/border prevalidation was removed from
both copy bodies. The two-version native source case and genuine texture
copy/layer pixel neighbor passed with GC disabled in
`source-texture-copy-gc-none.log` (two files); the actual public source case
passed in `source-texture-copy-public-gc-none.log`. Competing invalid targets,
dimensions and borders preserve actual driver error order and select the owner
before returning. Remote transport and full LibJS ownership remain separate.

The earlier shader/program creation, mutation and deletion repair translated
Source handle/type/slot gates and actual driver operations from
`WebGLRenderingContextImpl.cpp:129-193`, `:414-426`, `:472-485`, `:544-570`,
`:583-602`, `:2233-2246`, `:2312-2330`, and `:2486-2500`. Its original owner
fixtures assumed that every Source make_current prefix selected a native
driver. Subsequent concrete Proxy/Host review established that the prefix is
empty: only an actual dispatched GL command/query selects its owner. The
createShader type gate, shader command/deletion gates and deleteProgram CPU
and linkProgram/validateProgram gates are corrected with separately recorded
source evidence above; remaining
mutation handle/null/slot gates require independent Source slices.
attachShader assigns its actual retained shader pointer after GL, including
owned native rejection, and deleteProgram clears the current source pointer by
actual object identity. The invented bindAttribLocation `gl_` name gate was
removed: the driver decides competing index/name errors after source ownership
validation. Native owner, actual shader compilation/reflection and source
program-order files passed with GC disabled (three files,
`source-shader-program-owner-gc-none.log`); the actual public two-version owner
case passed in `source-shader-program-owner-public-gc-none.log`. Those historical
passes do not establish final driver owner order for the remaining gates. The following
record slices remove source shader/program mirrors, eager queries and the
extra native-zero null substitution. Full LibJS tracing and WrapperWorld
ownership remain open.

Shader/program records now translate `WebGLShader.h` and `WebGLProgram.h`
directly: shader type and the two actual attached-shader pointers supplement
their WebGLObject base. All six invented source/compile/link/validate/log fields
and the eager status/log queries were removed. shaderSource, compileShader,
linkProgram and validateProgram forward only the source driver operations
(`WebGLRenderingContextImpl.cpp:414-426`, `:2233-2246`, `:2312-2330`,
`:2486-2500`); parameter/source/log APIs query GL when requested. Eleven legacy
fixtures now verify actual driver status/source instead of CPU mirrors,
including initial source before external mutation and successful link status
before a native failed relink. Those files plus actual shader compilation and
status neighbors passed with GC disabled (13 files,
`source-shader-program-records-gc-none.log`). The final actual validateProgram
status/error case and source owner regression passed in
`source-shader-program-records-validation-gc-none.log` (two files), covering
unlinked status and owned native-name rejection. Public diagnostic/status
cases passed in `source-shader-program-records-public-gc-none.log` (two files).
Other remaining context caches, remote transport and complete LibJS ownership
remain separate source slices.

createShader now preserves the source's unconditional owned-record creation
after a valid shader type, retaining a separate actual native adapter name
(`WebGLRenderingContextImpl.cpp:472-485`). The subsequent generated-boundary
review above establishes that Source m_handle is the returned proxy ID, even
when the command is dropped after loss; it is not that native name. The source invalid-type null return
and INVALID_ENUM remain. The genuine ANGLE test uses the existing production
context-loss path, which destroys EGL and unbinds its current context, verifies
that raw glCreateShader returns zero, and checks both shader types' retained
records, context identity, type and generation invalidation after restoration.
No substitute backend supplies that zero. The focused native creation/owner/
loss files passed with GC disabled in `source-shader-creation-gc-none.log`
(three files); the final restoration fixture passed in
`source-shader-creation-final-gc-none.log`. Actual JavaScriptCore zero-name
creation and owner cases passed in `source-shader-creation-public-gc-none.log`
(two files), including distinct branded shader wrappers and the one-shot
context-loss error. This covers source record projection; remote execution and
complete native command suppression after loss remain separate boundaries.

The creation-return inventory against the pinned source is:

| Creation family | Source reference | Native-zero return projection |
| --- | --- | --- |
| Buffer, framebuffer, program, renderbuffer, texture | `WebGLRenderingContextImpl.cpp:438-498` | Owned records retained; no V zero/null gate |
| Shader | `WebGLRenderingContextImpl.cpp:474-489` | Valid types retain owned records after this repair |
| Query, sampler, transform feedback, vertex array | `WebGL2RenderingContextImpl.cpp:675-683`, `:793-801`, `:983-991`, `:1285-1293` | Owned records retained; no V zero/null gate |
| OES vertex array | `Extensions/OESVertexArrayObject.cpp:33-39` | Owned record retained; no V zero/null gate |
| Sync | `WebGL2RenderingContextImpl.cpp:912-918`, `WebGLSync.cpp:19-30` | Owned record retained after actual driver rejection; no V null gate |

Logical resource IDs in the JavaScriptCore bridge remain distinct from driver
handles, including zero; full source GC context edges and WrapperWorld
ownership are not supplied by those transport IDs.

fenceSync now returns the source owned WebGLSync record even when actual
glFenceSync returns a null GLsync. The driver still determines invalid-condition,
invalid-flag and competing-argument errors; no substituted success value or
backend supplies the result. Native creation, real GPU fence/wait/query and
object-lifetime cases passed with GC disabled in
`source-sync-creation-gc-none.log` (three files). The two old null-return fixtures
now assert an owned record with a null native handle and the same driver error.
The actual JavaScriptCore source creation and resource-interface cases passed
in `source-sync-creation-public-gc-none.log` (two files), covering retained
branded wrappers, native label storage, owner selection, genuine null-handle
query results/errors and source invalidation after deletion. This preserves the
pinned implementation even where the driver rejects fence creation; it does not
claim a completed remote transport or full WrapperWorld lifetime implementation.

Immutable texture storage now follows
`WebGL2RenderingContextImpl.cpp:198-209`: select the owning driver and forward
levels, formats and dimensions without extra V prevalidation. The native source
case and real texture-layer/storage neighbor passed with GC disabled in
`source-texture-storage-gc-none.log` (two files); the actual public source case
passed in `source-texture-storage-public-gc-none.log`. Cases inspect genuine
immutable-format/level query results, verify pixels in an allocated 3D layer,
use actual bindings absent from retained slots, and preserve the driver's
competing error order. Remote transport and full LibJS ownership remain separate.

Material platform adaptations are explicit: painting uses CPU readback into the
retained bitmap instead of upstream IOSurface/Vulkan shared-image handoff;
ANGLE builds lacking compressed robust entry points use the matching GLES call
with its exact payload size; unsupported source Skia RGBA5551 export returns an
error instead of the upstream surface assertion; WebGL1 null texture allocation
above the V-array/GLsizei capacity reports OUT_OF_MEMORY instead of the upstream
MUST allocation failure. These do not establish remote compositor parity.

`context_proxy.v` still records transmitted batches in memory and consumes
fixture-supplied synchronous replies/readback. It has no real remote WebGL
transport/command processor. Its wait-success and next-reply fields therefore
remain audit gaps independently of the production direct native path.

Source TODOs remain visible. `get_uniform` now translates the pinned source's
exact integer-zero result and absence of body handle checks, native queries or
owner selection (`WebGLRenderingContextImpl.cpp:1997-2001`). The invented
uniform-value cache and all four setter-family writes were removed. Public
arguments still undergo source nonnullable WebGLProgram/WebGLUniformLocation
IDL conversion (`WebGLRenderingContextBase.idl:120`), including wrong-brand,
null and missing-argument rejection. Genuine uploaded vector/matrix values in
the legacy fixture now use driver queries; the focused native source getter,
legacy entry-point, real draw and location-identity cases passed with GC
disabled in `source-uniform-getter-gc-none.log` (four files). Actual public source
getter and rendered Canvas/WebGL host cases passed in
`source-uniform-getter-public-gc-none.log` (two files). Cases verify real uniform
uploads independently, exact zero for foreign/deleted records, unchanged native
context selection and preserved unrelated driver errors. This matches an
upstream FIXME and supplies no invented uniform-read algorithm. The V typed
signature retains its existing optional-location convenience; the public IDL
argument remains nonnullable.

All eight scalar uniform setters now translate
`WebGLRenderingContextImpl.cpp:2380-2465`: select the owning context, use native
location zero for a null record, validate the parent-program pointer only for a
present record, then call the exact glUniform1f–4f or glUniform1i–4i operation.
They no longer inherit the vector helper's null no-op or late owner selection.
Direct native ABI forwards preserve the source scalar commands and actual
driver errors. Native source, source getter, real draw and location-identity
cases passed with GC disabled in `source-scalar-uniform-gc-none.log` (four files).
The actual public source and rendered host cases passed in
`source-scalar-uniform-public-gc-none.log` (two files). Both versions exercise
all eight matching uniform types, reset driver values before each null-location
call, verify genuine uploads, and compare unbound-program driver errors.
Foreign-parent rejection selects the owner before returning. Public wrong-brand
conversion precedes numeric hooks, and all scalar numeric hooks finish before
body parent validation. The source null-location behavior can update native
location zero; this preserves the pin rather than supplying a specification
correction. The following slices complete vector/matrix owner ordering and
matrix transpose forwarding.

The four WebGL2 unsigned scalar setters likewise follow
`WebGL2RenderingContextImpl.cpp:280-322`, using the source scalar owner/optional
parent prelude and exact glUniform1ui–4ui calls instead of the unsigned-vector
helper's null no-op. The existing shared typed adapter retains its WebGL2 gate;
public WebGL1 exposes none of these operations. Extended native scalar/source
getter/draw cases passed with GC disabled in
`source-unsigned-scalar-uniform-final-gc-none.log` (three files); actual public
scalar and rendered host cases passed in
`source-unsigned-scalar-uniform-public-gc-none.log` (two files). Native unsigned
queries verify every bit of 0xffffffff, 0x80000000, 0x10000001 and 0x7fffffff,
alongside reset-before-null uploads, selected-owner rejection and genuine
unbound-program driver errors. The initial test-only conditional range-bound
syntax was replaced with an explicit operation count for the repository's
compiler; the earlier failed compilation is retained in
`source-unsigned-scalar-uniform-gc-none.log`.

Float, signed and unsigned vector uniform bodies select their owner before
nullable-location, parent-pointer and list-size returns, matching
`WebGLRenderingContextOverloads.cpp:236-362`,
`WebGL2RenderingContextOverloads.cpp:224-356`, and
`WebGL2RenderingContextImpl.cpp:324-386`. The public list-uniform prelude also
selects the owner before source buffer-witness/offset handling; its shared
matrix entry likewise gains that source prelude. JavaScriptCore still finishes
all generated IDL argument conversions before entering it. Null vector
locations remain source no-ops after selecting the owner, distinct from the
scalar native-zero behavior. Native early-owner, real draw and scalar regression
cases passed with GC disabled in `source-vector-uniform-owner-gc-none.log`
(three files). Actual public owner, real source-span/rendering and sequence
conversion cases passed in `source-vector-uniform-owner-public-gc-none.log`
(three files), covering all 12 applicable vector names, parent-before-span/size
errors, null-before-offset returns and an IDL numeric hook failure that leaves
the previously current driver untouched. The following matrix slice completes
the typed owner prelude and native transpose forwarding.

All nine matrix uniform bodies now preserve owner selection before
null/parent/list-size returns and forward the caller's transpose flag to the
matching glUniformMatrix entry point. The invented early transpose rejection
and native ABI's hardcoded GL_FALSE were removed, following
`WebGLRenderingContextOverloads.cpp:364-416`,
`WebGL2RenderingContextOverloads.cpp:358-410`, and
`WebGL2RenderingContextImpl.cpp:388-494`. The existing shared typed adapter keeps
its nonsquare WebGL2 gate; public WebGL1 retains only its three square methods.
Native source matrix, migrated legacy entry-point and real draw files passed
with GC disabled in `source-matrix-uniform-gc-none.log` (three files). Actual
public matrix and source-span/rendering cases passed in
`source-matrix-uniform-public-gc-none.log` (two files). Both versions cover every
applicable shape, genuine false-flag uploads, true-flag driver results after
resetting the native values, and competing transpose/unbound-program errors
with the source program pointer retained. Public null/foreign records precede
source span/size errors. The old wrong-type/true fixture now compares the actual
driver error instead of assuming an invented transpose priority. No matrix
read/transposition algorithm is supplied by the translation; the actual driver
owns execution and the source getter retains its separate upstream FIXME.

Upstream
WebGL2 declarations below are explicitly `[FIXME]` at pinned commit
`963d46a829f3e1b79f44dba9d02afb70654300fa`, with no matching operation bodies in
`WebGL2RenderingContextImpl.{h,cpp}` or `WebGL2RenderingContextOverloads.{h,cpp}`.
They are upstream unavailable operations, distinct from remaining translation
work on implemented source bodies.

`xr_operations.v` translates the executed `make_xr_compatible` branches in
`WebGLRenderingContextBase.cpp:395-462`: deferred context-loss/compatibility
selection, a separate Unspecified settlement task, source InvalidStateError,
and a fresh owning-realm Promise. `html/webgl_xr_operations.v` supplies the
owning HTML loop and the source callbacks-enabled temporary execution context.
The source platform deferred invocation is adapted to an owning-loop task;
Promise reactions remain owning-loop microtasks. The two focused owning-loop
cases passed with GC disabled. Permissions policy and immersive-device
selection remain the pinned source TODOs; its assumed compatible adapter is
preserved and does not establish WebXR device support. The synchronous bool
helper has been removed; its existing context-loss caller now runs the actual
`make_xr_compatible` deferred and settlement steps and inspects the resulting
Promise. Both that focused file and the HTML ownership file passed with GC
disabled.

The public `makeXRCompatible()` method now uses
`browserjs/canvas_webgl_xr_host_darwin.c.v` to invoke that same owning operation
and wrap its native capability in an actual JavaScriptCore Promise. Both
context prototypes expose the source zero-argument, nonconstructible operation;
receiver errors produce rejected Promises carrying their original engine values.
Context loss becomes an actual DOMException after the source settlement task.
The four public ownership/rejection/close cases and the context-interface
neighbor passed with GC disabled. The existing Promise bridge retains the
engine Promise until runtime closure and releases settlement roots when used;
full engine wrapper collection and translated VM Promise parity remain separate
boundaries.

| Upstream unavailable operation | Source declaration under `Libraries/LibWeb/WebGL/` |
| --- | --- |
| Numeric PBO texImage2D / texSubImage2D | `WebGL2RenderingContextOverloads.idl:24`, `:31` |
| Numeric PBO compressedTexImage2D / compressedTexSubImage2D | `WebGL2RenderingContextOverloads.idl:37`, `:40` |
| Numeric PBO texImage3D / texSubImage3D | `WebGL2RenderingContextBase.idl:296`, `:304` |
| Numeric PBO compressedTexImage3D / compressedTexSubImage3D | `WebGL2RenderingContextBase.idl:313`, `:316` |
| copyTexSubImage3D / getFragDataLocation | `WebGL2RenderingContextBase.idl:311`, `:320` |
| isQuery / isSampler / isSync / isTransformFeedback | `WebGL2RenderingContextBase.idl:366`, `:375`, `:383`, `:392` |
| getSamplerParameter / getTransformFeedbackVarying / getIndexedParameter | `WebGL2RenderingContextBase.idl:379`, `:397`, `:404` |

The pinned binding generator excludes `[FIXME]` declarations from operation
overload sets (`Meta/Generators/libweb_bindings/overload_resolution.py:542-549`).
Wholly unimplemented operation names receive only the source unimplemented
property marker (`operations.py:185-203`); some V internal native getter helpers
do not imply completed public source operation bindings. Numeric pixel-unpack
texture overloads must not be confused with the implemented numeric pixel-pack
readPixels overload. Source reset_to_default_state bodies are empty in both
context classes and remain empty in the translation.

The pinned compositor allocates a texture-backed default framebuffer
(`Services/Compositor/OpenGLContext.cpp:578-580`, `:667-669`), and the implemented
WebGL2 draw_buffers body forwards its enum vector unchanged
(`WebGL2RenderingContextImpl.cpp:568-573`). The V CPU surface preserves that
source forwarding: drawBuffers([BACK]) on this hidden framebuffer reports the
native INVALID_OPERATION. No inferred BACK remapping has been introduced;
explicit user framebuffers and their COLOR_ATTACHMENT entries execute natively.

The compact public binding now applies that source `[FIXME]` exclusion before
overload resolution. Unsupported numeric unpack calls raise TypeError without
issuing an empty-byte native upload. Failed ambiguous resolution retains the
source "Overload resolution failed" diagnostic, while the supported numeric
bufferData overload still converts ordinary objects through ToNumber. Both
focused effective-overload cases and all three adjacent public host, nullable
texture, and source-span files pass with `-gc none`.

Uniform reflection now preserves the implemented source result distinctions
(`WebGL2RenderingContextImpl.cpp:1121-1193`): getUniformIndices returns null for
an invalid program, getActiveUniforms returns undefined for an invalid program,
and an empty uniform-index vector returns an empty Array after the native
query even when pname is unsupported. Native and local errors retain separate
source getError precedence. The old typed nonnullable index getter remains a
convenience adapter; public bindings use the new source nullable getter. New
native/public result-shape cases and the existing native uniform-block file
pass with `-gc none`.

Actual WebGL buffer/view and exact typed-list argument conversion now uses
captured engine internal-slot getters, ignoring author-shadowed buffer,
byteOffset, byteLength, BYTES_PER_ELEMENT, values, and iterator properties.
Buffer and typed-list snapshots happen after all argument conversions; ordinary
sequence snapshots remain eager. Destination writeback uses those same real
slots. The pinned generator disallows resizable backing stores without
AllowResizable and shared buffers without AllowShared
(`Meta/Generators/libweb_bindings/to_idl_value.py:1329-1445`): WebGL view
arguments are AllowShared, ordinary BufferSource and exact Float32/Int32/Uint32
list members are not, and no WebGL buffer argument is AllowResizable. Earlier
public RAB acceptance was therefore a translation error; typed witness helpers
retain the source operation-body rules independently of public IDL restrictions.

All three new slot/timing cases plus the six adjacent source-span, public host,
effective-overload, texture-source, pixel-pack, and nullable-texture files pass
with `-gc none`. They exercise mutation/detachment by later argument getters,
native buffer and rendered uniform results, view-property tampering, actual
DataView/typed destination writes, raw-buffer versus view brands, and optional
engine RAB/SAB exposure. This interop adaptation does not establish complete
LibJS builtin/prototype/WrapperWorld parity.

Float16Array views retain their two-byte element size, as declared by the
pinned `Libraries/LibWeb/WebIDL/Buffers.h:20-33` variant. The focused native host
test passed with Float16Array exposed by JavaScriptCore, checking offset/length
upload bytes and destination offsets without reading an author-shadowed
BYTES_PER_ELEMENT property.

Effective overload selection distinguishes raw ArrayBuffer from ArrayBufferView
using actual engine brands, matching `WebIDL/OverloadResolution.cpp:203-253`.
An ambiguous texImage2D call with a raw buffer now raises the source overload
resolution error before reading earlier numeric argument getters. The focused
effective-overload file passed with `-gc none`, including supported numeric
buffer allocation and nullable/typed-view texture uploads.

Generic sequence arguments now translate the pinned generated
GetIteratorFromMethod/IteratorStepValue loop
(`Meta/Generators/libweb_bindings/to_idl_value.py:824-871`), sharing the existing
Crypto sequence conversion factory. They get Symbol.iterator and iterator.next
once, convert each item before later argument getters, and preserve original
exceptions without IteratorClose, as the source loop does. Float/Int/Uint list
union failures retain source union selection while exact typed members keep
their operation-body copy point. All three focused sequence cases and the
existing native Crypto generation/import files passed with `-gc none`.

DOMString arguments use the source ToString string primitive hint, preserving
Symbol TypeErrors and original conversion exceptions. The focused native host
case passed with `-gc none`, checking real compiled shader source, ordinary
toString/valueOf ordering, extension names, and sequence string-item failures.

Context creation follows `HTML/HTMLCanvasElement.cpp:282-310` and the actual
hand-written `WebGLContextAttributes.cpp:14-160` converter used by both context
classes. Nonobject options become null/defaults; the nine implemented getters
run once in source order and powerPreference validates before later getters.
The source converter omits xrCompatible, leaving it false even though the IDL
declares it. Public native and typed HTML creation now preserve that omission.
The generic typed ContextAttributeInput convenience converter still accepts the
full IDL record; the source-named creation converter leaves xrCompatible false.
Existing contexts return before option getters run. Native public, typed HTML,
and typed attribute focused files passed with `-gc none`.

getContextAttributes returns a fresh ordinary dictionary with lexical member
order, matching `Meta/Generators/libweb_bindings/to_js_value.py:342-391` and the
sorted dictionary members in `Meta/Utils/webidl_parser.py:554`. Its focused
native host case passes with `-gc none`, including own-key order, ordinary
prototype, and independent writable copies.

Active variable and shader precision query results now adapt the concrete
`WebGLActiveInfo`/`WebGLShaderPrecisionFormat` source records and readonly IDL
getters instead of exposing their JSON transport records directly. The wrappers
have the source prototypes, tags, getter descriptors/receiver checks, fresh
per-query identity, and constructor errors from generated bindings and
`Bindings/InterfaceObject.cpp:61-64`. A focused native host case passes with
`-gc none`, querying actual linked shader attributes/uniforms and driver
precision and checking readonly access, forgery rejection, and allowed own
property shadows. This is a reflection-wrapper interop adaptation; the full
cross-realm WrapperWorld graph remains open.

Concrete context interface methods/constants/readonly getters now reside on
the corresponding WebGLRenderingContext or WebGL2RenderingContext prototype,
following `Meta/Generators/libweb_bindings/interfaces.py:399-435`, `:470-520`
and `operations.py:164-203`, `:450-480`. Captured engine receiver records reject
forged or wrong-interface receivers before argument getters; borrowed methods
dispatch to their actual receiver's native context. Method names, lengths,
nonconstructibility, source arity/constructor errors, constant descriptors,
tags and shared method identity follow the source generated bindings. Native
two-canvas prototype/receiver tests plus public host and extension execution
neighbors pass with `-gc none`. Global constructor replacement does not alter
the cached native interface prototype used for subsequently created contexts.
Cross-realm WrapperWorld work remains open.

Typed query result selection uses the once-converted unsigned enum, matching
the source get_parameter/get_vertex_attrib/get_active_uniform_block_parameter
switches. It no longer converts the author pname object again after native GL
execution, and values wrapping modulo 2^32 select the same typed result as the
source. The focused native host case passes with `-gc none` for viewport,
constant vertex attributes and an actual linked uniform block's indices.

Resource interfaces now follow the source WebGLObject prototype/constructor
inheritance, brands, tags and constructor errors. Uniform locations retain their
separate interface; WebGLVertexArrayObjectOES has its source internal prototype
without an exposed LegacyNoInterfaceObject constructor. WebGLObject.label gets
and sets the actual V resource record (`WebGLObject.h:25-26`); it remains usable
after handle deletion and uses source USVString conversion through captured
engine ToString/toWellFormed operations (`WebIDL/AbstractOperations.cpp:262-265`).
The focused native resource case and public host neighbor pass with `-gc none`,
covering all twelve labelled resource families, actual V field changes,
getter/setter brand validation, Unicode replacement, deletion, cache identity, and constructor
or intrinsic replacement. Full cross-realm/WrapperWorld cache lifetime remains
an explicit boundary.

Reflection getters also preserve generated native-function nonconstructibility:
they have no own prototype and construction raises TypeError without running
the getter. The actual reflection query test passes with `-gc none` after this
focused correction.

The thirteen implemented extension factories now create their source internal
interface prototypes, tags, constant descriptors and shared native-function
methods (`WebGLRenderingContextBase.cpp:67-124`, `Extensions/*.idl`). Each retains
LegacyNoInterfaceObject behavior. Method receivers are checked before argument
conversion, following the generated `operations.py:450-480` binding steps, and
borrowed ANGLE/OES methods use the receiving extension's actual native context.
The focused native two-context interface test and existing extension execution
test pass with `-gc none`, including cache aliases, forged receivers, arity,
method identity and real divisor/vertex-array queries. This remains an actual
JavaScriptCore interop adaptation rather than a complete cross-realm
WrapperWorld implementation.

The registry retains the source creates_empty_object flags for
OES_texture_float_linear and EXT_float_blend. Native support enables them in
both versions without the experimental flag; getExtension requests their native
extensions and returns a cached ordinary empty object, matching
`WebGLRenderingContextBase.cpp:128-208`. The source non-ASCII name rejection also
runs before lookup. Focused typed and actual native JavaScriptCore cases pass
with `-gc none`, covering support filtering, alias identity, per-context object
identity, ordinary extensible objects and native extension enabling. These two
objects retain the host cache lifetime boundary documented above.

isEnabled now makes its owning context current and calls actual glIsEnabled,
matching `WebGLRenderingContextImpl.cpp:2131-2135`, instead of reading a V
capability cache. Its focused native two-version case and public host neighbor
pass with `-gc none`, including out-of-cache driver mutations, context switching
and native INVALID_ENUM for non-capability pnames.

Shader source, shader/program info logs and attached-shader queries validate
their context-owned live handles and return nullable failures with
INVALID_OPERATION, as in `WebGLRenderingContextImpl.cpp:867-890`, `:1817-1836`
and `:1900-1940`. getAttachedShaders retains the source vertex/fragment wrapper
order; getShaderSource reads actual GL_SHADER_SOURCE_LENGTH and glGetShaderSource
instead of the retained source cache. Typed and actual JavaScriptCore focused
cases pass with `-gc none`, including foreign/deleted objects, empty values,
resource identity and a native source mutation outside the V cache. Existing
native shader compile/link/reflection tests also pass with `-gc none`.

getError now queries its owning native driver's error at the synchronous
receiver boundary, after pending local errors and before stored translation errors, matching
`WebGLRenderingContextImpl.cpp:1720-1724` and
`WebGLRenderingContextBase.cpp:315-332`. Its focused native two-version test and
existing native object-query file pass with `-gc none`, including driver errors
raised outside translated calls, context switching, exact precedence and the
source one-time context-loss error branch.

Browser-only pixelStorei state returns before issuing native GL commands, and
UNPACK_COLORSPACE_CONVERSION_WEBGL stores the converted GLint as GLenum without
extra enum validation, matching `WebGLRenderingContextImpl.cpp:2246-2282`.
The earlier focused two-version fixture assumed native selection from the
source's empty Proxy::make_current prefix. The subsequent source pixel-store
slice above corrects that fixture and preserves the already-current other
driver on browser-only and invalid UNPACK_ALIGNMENT returns. Focused native
and public checks pass with `-gc none`, including negative/arbitrary
color-space state, browser-only boolean flags and preserved unpack errors. This
preserves the pinned source behavior even where it accepts state beyond the
usual NONE/BROWSER_DEFAULT_WEBGL values.

Program operations preserve pinned source state ordering. useProgram validates
only its owned live handle, calls the driver and then writes its retained current
program; getUniformLocation likewise lets the driver determine link validity.
detachShader calls the driver before clearing the corresponding retained shader
slot (`WebGLRenderingContextImpl.cpp:651-680`, `:2003-2023`, `:2468-2485`).
Focused typed and actual JavaScriptCore cases pass with `-gc none`, including a
program linked outside the V status cache and native rejection paths. These
preserve two upstream cache limitations: rejecting an unlinked useProgram can
leave the retained program different from the actual driver binding; rejecting
an unattached detachShader can clear a retained slot while the actual shader
remains attached. The source cache queries and driver parameter queries expose
those distinct results.

Each successful getUniformLocation now performs the native query and creates a
fresh source record, as in `WebGLRenderingContextImpl.cpp:2003-2023`; the invented
per-name record cache has been removed. Typed and actual JavaScriptCore identity
cases plus existing native uniform tests pass with `-gc none`, including distinct
wrappers sharing one driver location, use of both wrappers, fresh queries after
relink, missing names and a native failed relink outside the V status cache.
The host's resource wrapper lifetime boundary remains unchanged.

WebGLUniformLocation handle validation now compares optional current/parent
program pointers exactly (`WebGLUniformLocation.cpp:48-53`), including the
source factory's valid both-null case. A present mismatch still reports
INVALID_OPERATION; matching pointer identity remains valid after native/source
program deletion, without an added link/deletion query. The focused typed
factory/pointer case and actual native location-identity neighbor passed with
GC disabled in `source-uniform-location-handle-gc-none.log` (two files). This
translates the source record validator; it does not add a public constructor or
complete the remaining WrapperWorld lifetime boundary.

drawBuffers and drawBuffersWEBGL no longer dirty CPU canvas presentation merely
because their dispatch names begin with draw. Their pinned source bodies only
change native draw-buffer state (`WebGL2RenderingContextImpl.cpp:568-573`,
`Extensions/WebGLDrawBuffers.cpp:36-40`). Focused two-version native presentation
and framebuffer-transfer tests pass with `-gc none`, covering unchanged retained
pixels/presentation state and subsequent actual clearing. The existing native
CPU presentation adaptation for rendering commands remains explicit.

Wholly upstream-unavailable operation names now retain absent JavaScript
property descriptors instead of gaining fabricated functions with empty
overload sets. The source `operations.py:185-203` uses engine-private
unimplemented markers; `LibJS/Runtime/Object.cpp:1605-1618` records those names
without creating properties. The focused actual JavaScriptCore case and existing
effective-overload test pass with `-gc none`, including nine unavailable names
and all mixed implemented texture/readPixels overload families. Source engine
diagnostics for the private markers remain a LibJS boundary; JavaScriptCore
exposes the same absent property/function behavior without that private flag.

The browser continues to use JavaScriptCore. Compact wrappers and typed V
WebIDL values do not provide the unfinished LibJS VM's Promise/builtin object
graph or full WebIDL brand/prototype parity.

## Verification

After the source query/error/program-state/interface repairs, the private
`e5f9d9b1` snapshot passed all 53 tracked `webgl/*_test.v` files and all 22
`browserjs/canvas_webgl*_test.v` public binding files on 2026-10-03 with
`-old-compiler -enable-globals -gc none` and an explicit private module path.
The complete manifest and per-file results are retained under
`Build/audit-fixes/webgl-final-e5f9d9b1/`. No obsolete fixture failures appeared.
These counts include the existing remote proxy fixtures and preserve the
remaining source TODO, remote transport and full VM/WrapperWorld boundaries.

All 44 current WebGL test files passed using direct
`v -old-compiler -enable-globals -path 'WORKTREE|@vlib|@vmodules' FILE_test.v`
invocations on 2026-10-02. Native tests use actual ANGLE/Metal results, including
compiled draws, framebuffer/layer/compressed texture pixels, synchronization,
query/reflection values, destination/PBO offsets, and nullable uploads. Focused
JavaScriptCore host tests also pass for typed span/resize/detach rules,
TexImageSource conversion, PBO readback, nullable textures, instanced extension
draws, separate draw-buffer attachment pixels, and owner identity. The counts
include existing state/proxy fixture tests and do not claim remote execution or
complete source/VM parity.
