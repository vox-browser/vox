# WebGL module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebGL`

Reference audit: 2026-09-12
Latest native focused verification: 2026-10-04

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

Framebuffer-to-texture copy now follows
`WebGLRenderingContextImpl.cpp:427-437`: select the owning driver and forward
every argument to GL. Extra V dimension/border prevalidation was removed from
both copy bodies. The two-version native source case and genuine texture
copy/layer pixel neighbor passed with GC disabled in
`source-texture-copy-gc-none.log` (two files); the actual public source case
passed in `source-texture-copy-public-gc-none.log`. Competing invalid targets,
dimensions and borders preserve actual driver error order and select the owner
before returning. Remote transport and full LibJS ownership remain separate.

Shader/program creation, mutation and deletion now select their owner before
source handle, shader-type, duplicate-slot, null and repeated-deletion returns.
This matches `WebGLRenderingContextImpl.cpp:129-193`, `:414-426`, `:474-489`,
`:544-570`, `:583-602`, `:2233-2246`, `:2312-2330`, and `:2486-2500`.
attachShader assigns its actual retained shader pointer after GL, including
owned native rejection, and deleteProgram clears the current source pointer by
actual object identity. The invented bindAttribLocation `gl_` name gate was
removed: the driver decides competing index/name errors after source ownership
validation. Native owner, actual shader compilation/reflection and source
program-order files passed with GC disabled (three files,
`source-shader-program-owner-gc-none.log`); the actual public two-version owner
case passed in `source-shader-program-owner-public-gc-none.log`. The following
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
after a valid shader type, even when actual glCreateShader returns zero
(`WebGLRenderingContextImpl.cpp:474-489`). The source invalid-type null return
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

getError now queries the current native driver's error after pending local
errors and before stored translation errors, matching
`WebGLRenderingContextImpl.cpp:1720-1724` and
`WebGLRenderingContextBase.cpp:315-332`. Its focused native two-version test and
existing native object-query file pass with `-gc none`, including driver errors
raised outside translated calls, context switching, exact precedence and the
source one-time context-loss error branch.

Browser-only pixelStorei state makes its owning context current, and
UNPACK_COLORSPACE_CONVERSION_WEBGL stores the converted GLint as GLenum without
extra enum validation, matching `WebGLRenderingContextImpl.cpp:2246-2282`.
The focused native two-version test and existing texture-source file pass with
`-gc none`, including context switching, negative/arbitrary color-space state,
browser-only boolean flags and preserved native unpack-alignment errors. This
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
