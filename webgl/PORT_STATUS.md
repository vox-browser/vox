# WebGL module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebGL`

Reference audit: 2026-09-12
Latest native focused verification: 2026-10-03

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

Source TODOs remain visible. Upstream `get_uniform` returns zero with a FIXME;
its V cached-value model does not establish a translated native getter. Upstream
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
