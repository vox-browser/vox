// Experimental direct Metal service. Enabled only with -d vox_direct_metal.
// Unsupported service calls report INVALID_OPERATION and are counted; they never
// delegate to ANGLE. The default stays unchanged until the conformance gate passes.
module webgl

import webgl.metal

#include "@DIR/native_metal_boundary.h"
fn C.vox_metal_service_get() voidptr
fn C.vox_metal_service_set(voidptr)
fn C.vox_metal_service_validate_stage(&char,i32,i32,i32,&char,u64) i32

@[heap]
struct MetalServiceContext {
mut:
    next_id u32 = 16
    objects map[u32]&MetalServiceObject
    buffers map[u32]u32
    fences map[voidptr]&MetalServiceFence
    indexed_buffers map[u64]MetalServiceBufferRange
    vertex_arrays map[u32]&MetalServiceVertexArray
    vertex_array u32
    samplers [32]u32
    textures map[u64]u32
    black_textures map[u64]&metal.Texture2D
    draw_framebuffer u32
    read_framebuffer u32
    renderbuffer u32
    default_draw_buffer u32 = 0x405
    default_read_buffer u32 = 0x405
    current_program u32
    current_attributes [16]MetalServiceCurrentAttribute
    version int
    target &metal.DrawingBuffer
    depth &metal.DepthStencil = unsafe { nil }
    clear_program &metal.ShaderProgram = unsafe { nil }
    clear_integer_programs map[u32]&metal.ShaderProgram
    width int = 1
    height int = 1
    surface bool
    has_depth bool
    has_stencil bool
    error_ u32
    parameters map[u32][]f64
    enabled map[u32]bool
    clear_color [4]f32
    clear_depth f32 = 1
    clear_stencil u32
    color_mask u32 = 15
    depth_mask bool = true
    front_stencil_mask u32 = 255
    scissor_enabled bool
    scissor metal.ScissorRect
    viewport metal.Viewport
    unsupported map[string]int
    last_failure string
}

@[heap]
struct MetalServiceObject {
mut:
    kind int
    created bool
    deleted bool
    gpu_buffer &metal.GPUBuffer = unsafe { nil }
    usage u32 = 0x88e4
    sampling &MetalServiceSampling = unsafe { nil }
    texture &MetalServiceTexture = unsafe { nil }
    fbo &MetalServiceFramebuffer = unsafe { nil }
    rbo &MetalServiceRenderbuffer = unsafe { nil }
    retired bool
    shader_type u32
    source string
    compiled_source string
    log string
    compiled bool
    attached []u32
    bindings map[string]int
    program &metal.ShaderProgram = unsafe { nil }
    linked bool
    validated bool
    attributes []MetalServiceActiveInfo
    uniforms []MetalServiceActiveInfo
    locations []MetalServiceUniformLocation
    blocks []MetalServiceUniformBlock
}

struct MetalServiceActiveInfo {
    name string
    lookup string
    type_ u32
    size int
    resource metal.ShaderResource
    block_index int = -1
mut:
    values []u8
}

struct MetalServiceUniformLocation {
    uniform int
    element int
}

fn (mut context MetalServiceContext) new_object(kind int) u32 {
    name := context.next_id
    if name == 0 { metal_service_error(out_of_memory); return 0 }
    context.next_id++
    context.objects[name] = &MetalServiceObject{kind:kind,created:kind in [5,9,10]}
    return name
}

fn (context &MetalServiceContext) object(name u32,kind int) !&MetalServiceObject {
    object := context.objects[name] or { metal_service_error(invalid_value); return error('Unknown object') }
    if object.kind != kind { metal_service_error(invalid_operation); return error('Wrong object kind') }
    if object.retired { metal_service_error(invalid_value); return error('Deleted object') }
    return object
}

fn (mut context MetalServiceContext) collect_programs() {
    for name,mut object in context.objects {
        if object.kind != 10 || !object.deleted || object.retired || name==context.current_program { continue }
        object.retired = true
        object.attached.clear()
        if object.program != unsafe { nil } { object.program.close(); unsafe { free(object.program) }; object.program = unsafe { nil } }
    }
    for name,mut object in context.objects {
        if object.kind != 9 || !object.deleted || object.retired { continue }
        mut attached := false
        for _,program in context.objects { if program.kind==10 && !program.retired && name in program.attached { attached = true } }
        if !attached { object.retired = true }
    }
}

fn metal_service_gl_type(resource metal.ShaderResource) u32 {
    if resource.kind==7 {
        if resource.image_scalar_type==7 { return if resource.image_dimension==3 { u32(0x8dcc) } else if resource.image_dimension==2 { u32(0x8dcb) } else if resource.image_arrayed { u32(0x8dcf) } else { u32(0x8dca) } }
        if resource.image_scalar_type==8 { return if resource.image_dimension==3 { u32(0x8dd4) } else if resource.image_dimension==2 { u32(0x8dd3) } else if resource.image_arrayed { u32(0x8dd7) } else { u32(0x8dd2) } }
        if resource.image_depth { return if resource.image_dimension==3 { u32(0x8dc5) } else if resource.image_arrayed { u32(0x8dc4) } else { u32(0x8b62) } }
        return if resource.image_dimension==3 { u32(0x8b60) } else if resource.image_dimension==2 { u32(0x8b5f) } else if resource.image_arrayed { u32(0x8dc1) } else { u32(0x8b5e) }
    }
    if resource.columns > 1 {
        if resource.columns==resource.rows { return 0x8b5a + resource.columns - 2 }
        return match resource.columns*10+resource.rows { 23 { u32(0x8b65) } 24 { u32(0x8b66) } 32 { u32(0x8b67) } 34 { u32(0x8b68) } 42 { u32(0x8b69) } 43 { u32(0x8b6a) } else { u32(0) } }
    }
    base := match resource.scalar_type { 2 { u32(0x8b56) } 7 { u32(0x1404) } 8 { u32(0x1405) } 13 { u32(0x1406) } else { u32(0) } }
    if resource.rows==1 { return base }
    return match resource.scalar_type { 2 { u32(0x8b57)+resource.rows-2 } 7 { u32(0x8b53)+resource.rows-2 } 8 { u32(0x8dc6)+resource.rows-2 } 13 { u32(0x8b50)+resource.rows-2 } else { u32(0) } }
}

fn metal_service_copy_string(value string,capacity i32,output &char) {
    if capacity < 0 { metal_service_error(invalid_value); return }
    if capacity==0 || output==unsafe { nil } { return }
    count := if value.len < int(capacity)-1 { value.len } else { int(capacity)-1 }
    unsafe { if count>0 { vmemcpy(output,value.str,count) }; output[count]=0 }
}

struct MetalServiceVertexAttribute {
mut:
    buffer u32
    size int = 4
    type_ u32 = 0x1406
    normalized bool
    integer bool
    stride int
    offset i64
    divisor u32
    enabled bool
}

@[heap]
struct MetalServiceVertexArray {
mut:
    element_buffer u32
    attributes [16]MetalServiceVertexAttribute
}

fn (mut context MetalServiceContext) vao() &MetalServiceVertexArray {
    if vao := context.vertex_arrays[context.vertex_array] { return vao }
    vao := &MetalServiceVertexArray{}
    context.vertex_arrays[context.vertex_array] = vao
    return vao
}

fn (mut context MetalServiceContext) buffer_binding(target u32) u32 {
    if target == element_array_buffer { return context.vao().element_buffer }
    return context.buffers[target]
}

fn (context &MetalServiceContext) valid_buffer_target(target u32) bool {
    return target in [array_buffer,element_array_buffer] || (context.version == 3 && target in [u32(0x8f36),0x8f37,0x88eb,0x88ec,0x8c8e,0x8a11])
}

fn (mut context MetalServiceContext) bound_buffer(target u32) !&MetalServiceObject {
    if !context.valid_buffer_target(target) { metal_service_error(invalid_enum); return error('Invalid buffer target') }
    name := context.buffer_binding(target)
    if name == 0 { metal_service_error(invalid_operation); return error('No buffer bound') }
    return context.objects[name] or { metal_service_error(invalid_operation); return error('Unknown buffer') }
}

fn (mut context MetalServiceContext) collect_buffers() {
    for name, mut object in context.objects {
        if object.kind != 0 || !object.deleted || object.gpu_buffer == unsafe { nil } { continue }
        mut referenced := context.buffers.values().contains(name)
        for _,binding in context.indexed_buffers { if binding.buffer==name { referenced=true } }
        for _,mut texture in context.black_textures { texture.close();unsafe { free(texture) } }
    unsafe { context.black_textures.free() }
    for _, fence in context.fences { unsafe { free(fence) } }
    unsafe { context.fences.free(); context.indexed_buffers.free();context.textures.free() }
    for _, vao in context.vertex_arrays {
            if vao.element_buffer == name || vao.attributes.any(it.buffer == name) { referenced = true }
        }
        if !referenced { object.gpu_buffer.close(); unsafe { free(object.gpu_buffer) }; object.gpu_buffer = unsafe { nil } }
    }
}

fn metal_service_current() &MetalServiceContext {
    return unsafe { &MetalServiceContext(C.vox_metal_service_get()) }
}

fn metal_service_error(code u32) {
    mut context := metal_service_current()
    if context != unsafe { nil } && context.error_ == 0 { context.error_ = code }
}

fn metal_service_unsupported(name string) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.unsupported[name]++ }
    metal_service_error(invalid_operation)
}

fn (mut context MetalServiceContext) clear_pixels(mask u32) ! {
    context.clear_pixels_at(mask,-1)!
}

fn (mut context MetalServiceContext) clear_pixels_at(mask u32,index int) ! {
    mut view:=context.framebuffer_view(framebuffer)!
    defer { view.close() }
    if mask & ~u32(0x4500) != 0 { return error('Invalid clear mask') }
    if index>=0 && view.custom {
        selected:=view.colors.filter(it.index==index)
        unsafe { view.colors.free() }
        view.colors=selected
        if selected.len==0 { return }
    }
    if context.clear_program == unsafe { nil } {
        context.clear_program = metal.ShaderProgram.compile(context.target,
            '#version 300 es\nuniform float z;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,z,1.0);}',
            '#version 300 es\nprecision highp float;uniform vec4 value;layout(location=0)out vec4 c0;layout(location=1)out vec4 c1;layout(location=2)out vec4 c2;layout(location=3)out vec4 c3;layout(location=4)out vec4 c4;layout(location=5)out vec4 c5;layout(location=6)out vec4 c6;layout(location=7)out vec4 c7;void main(){c0=value;c1=value;c2=value;c3=value;c4=value;c5=value;c6=value;c7=value;}',3)!
    }
    context.clear_program.uniform_floats('z',[context.clear_depth * 2 - 1])!
    context.clear_program.uniform_floats('value',context.clear_color[..])!
    mut scissor := ?metal.ScissorRect(none)
    if context.scissor_enabled { scissor = context.scissor }
    context.target.draw_with_options(context.clear_program,[],.triangles,0,3,1,metal.DrawOptions{
        color_target:view.primary
        color_targets:view.colors
        colors_configured:view.custom
        depth_stencil:view.depth
        state:metal.RenderState{
            scissor:scissor
            color_mask:if mask & 0x4000 != 0 { context.color_mask } else { u32(0) }
            depth_test:view.has_depth && mask & 0x100 != 0
            depth_compare:.always
            depth_write:context.depth_mask
            stencil_test:view.has_stencil && mask & 0x400 != 0
            front_stencil:metal.StencilFace{pass:.replace,reference:context.clear_stencil,write_mask:context.front_stencil_mask}
            back_stencil:metal.StencilFace{pass:.replace,reference:context.clear_stencil,write_mask:context.front_stencil_mask}
        }
    })!
    context.invalidate_draw_textures()
}

@[export: 'vox_egl_create']
fn metal_service_vox_egl_create(a0 i32) voidptr {
    if a0 !in [i32(2),3] { return unsafe { nil } }
    target := metal.DrawingBuffer.create(1,1) or { return unsafe { nil } }
    mut context := &MetalServiceContext{version:int(a0),target:target,parameters:metal_service_default_parameters(),enabled:{dither:true}}
    for mut attribute in context.current_attributes {
        attribute.floats[3]=1
        attribute.signed[3]=1
        attribute.unsigned[3]=1
    }
    C.vox_metal_service_set(context)
    return context
}

@[export: 'vox_egl_make_current']
fn metal_service_vox_egl_make_current(a0 voidptr) i32 {
    if a0 == unsafe { nil } { C.vox_metal_service_set(unsafe { nil }); return 0 }
    context := unsafe { &MetalServiceContext(a0) }
    width,_ := context.target.size()
    if width == 0 { return 0 }
    C.vox_metal_service_set(a0)
    return 1
}

@[export: 'vox_egl_destroy']
fn metal_service_vox_egl_destroy(a0 voidptr) {
    if a0 == unsafe { nil } { return }
    mut context := unsafe { &MetalServiceContext(a0) }
    if C.vox_metal_service_get() == a0 { C.vox_metal_service_set(unsafe { nil }) }
    if context.clear_program != unsafe { nil } { context.clear_program.close(); unsafe { free(context.clear_program) } }
    for _,mut program in context.clear_integer_programs { program.close();unsafe { free(program) } };unsafe { context.clear_integer_programs.free() }
    if context.depth != unsafe { nil } { context.depth.close(); unsafe { free(context.depth) } }
    for _, mut object in context.objects {
        if object.gpu_buffer != unsafe { nil } { object.gpu_buffer.close(); unsafe { free(object.gpu_buffer) } }
        if object.program != unsafe { nil } { object.program.close(); unsafe { free(object.program) } }
        if object.fbo!=unsafe { nil } { unsafe { object.fbo.attachments.free();object.fbo.draw_buffers.free();free(object.fbo) } }
        if object.rbo!=unsafe { nil } { if object.rbo.gpu!=unsafe { nil } { object.rbo.gpu.close();unsafe { free(object.rbo.gpu) } };unsafe { free(object.rbo) } }
        if object.texture!=unsafe { nil } { object.texture.close();unsafe { free(object.texture) } }
        if object.sampling!=unsafe { nil } { unsafe { object.sampling.parameters.free();free(object.sampling) } }
        unsafe { object.source.free(); object.compiled_source.free(); object.log.free(); object.attached.free(); object.bindings.free(); object.clear_reflection(); object.attributes.free(); object.uniforms.free(); object.blocks.free(); object.locations.free(); free(object) }
    }
    for _, vao in context.vertex_arrays { unsafe { free(vao) } }
    for _, values in context.parameters { unsafe { values.free() } }
    unsafe { context.objects.free(); context.buffers.free(); context.vertex_arrays.free(); context.parameters.free(); context.enabled.free() }
    context.target.close()
    unsafe { free(context.target); context.unsupported.free(); context.last_failure.free(); free(context) }
}

@[export: 'vox_gl_fence_sync']
fn metal_service_vox_gl_fence_sync(a0 u32, a1 u32) voidptr {
    return metal_service_fence(a0,a1)
}

@[export: 'vox_gl_client_wait_sync']
fn metal_service_vox_gl_client_wait_sync(a0 voidptr, a1 u32, a2 u64) u32 {
    return metal_service_client_wait(a0,a1)
}

@[export: 'vox_gl_wait_sync']
fn metal_service_vox_gl_wait_sync(a0 voidptr, a1 u32, a2 u64) {
    metal_service_wait(a0,a1,a2)
}

@[export: 'vox_gl_delete_sync']
fn metal_service_vox_gl_delete_sync(a0 voidptr) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || a0==unsafe { nil } { return }
    if mut fence:=context.fences[a0] { fence.deleted=true } else { metal_service_error(invalid_value) }
}

@[export: 'vox_gl_get_sync_parameter']
fn metal_service_vox_gl_get_sync_parameter(a0 voidptr, a1 u32) i32 {
    return metal_service_sync_parameter(a0,a1)
}

@[export: 'vox_gl_get_error']
fn metal_service_vox_gl_get_error() u32 {
    mut context := metal_service_current()
    if context == unsafe { nil } { return 0 }
    result := context.error_
    context.error_ = 0
    return result
}

@[export: 'vox_gl_is_object']
fn metal_service_vox_gl_is_object(a0 i32, a1 u32) i32 {
    context := metal_service_current()
    if context == unsafe { nil } || a1 == 0 { return 0 }
    if object := context.objects[a1] { return i32(object.kind == int(a0) && object.created && (if object.kind in [9,10] { !object.retired } else { !object.deleted })) }
    return 0
}

@[export: 'vox_gl_string']
fn metal_service_vox_gl_string(a0 u32) &char {
    match a0 {
        0x1f00 { return 'Vox'.str }
        0x1f01 { return 'Vox direct Metal'.str }
        0x1f02 { return if metal_service_current().version==3 { 'OpenGL ES 3.0 Vox direct Metal experimental'.str } else { 'OpenGL ES 2.0 Vox direct Metal experimental'.str } }
        0x8b8c { return if metal_service_current().version==3 { 'OpenGL ES GLSL ES 3.00'.str } else { 'OpenGL ES GLSL ES 1.00'.str } }
        0x1f03 { return 'GL_EXT_texture_filter_anisotropic'.str }
        0x93a8 { return ''.str }
        else { metal_service_error(invalid_enum); return unsafe { nil } }
    }
}

@[export: 'vox_gl_request_extension']
fn metal_service_vox_gl_request_extension(a0 &char) {
    // No optional extension is advertised by the incomplete service yet.
    _ = a0
}

@[export: 'vox_egl_free_surface']
fn metal_service_vox_egl_free_surface(a0 voidptr) {
    if a0 == unsafe { nil } { return }
    mut context := unsafe { &MetalServiceContext(a0) }
    if context.depth != unsafe { nil } { context.depth.close(); unsafe { free(context.depth) }; context.depth = unsafe { nil } }
    context.target.resize(1,1) or { context.last_failure = err.msg() }
    context.surface = false
}

@[export: 'vox_egl_allocate_surface']
fn metal_service_vox_egl_allocate_surface(a0 voidptr, a1 i32, a2 i32, a3 i32, a4 i32) i32 {
    if a0 == unsafe { nil } || a1 < 1 || a2 < 1 { return 0 }
    mut context := unsafe { &MetalServiceContext(a0) }
    context.target.resize(int(a1),int(a2)) or { context.last_failure = err.msg(); return 0 }
    if context.depth != unsafe { nil } { context.depth.close(); unsafe { free(context.depth) }; context.depth = unsafe { nil } }
    if a3 != 0 || a4 != 0 {
        context.depth = metal.DepthStencil.create(context.target,int(a1),int(a2)) or { context.last_failure = err.msg(); return 0 }
    }
    context.width = int(a1); context.height = int(a2)
    context.viewport = metal.Viewport{width:f64(a1),height:f64(a2)}
    context.has_depth = a3 != 0; context.has_stencil = a4 != 0; context.surface = true
    context.draw_framebuffer=1;context.read_framebuffer=1;context.renderbuffer=if context.depth!=unsafe { nil } { u32(2) } else { u32(0) }
    return 1
}

@[export: 'vox_egl_default_framebuffer']
fn metal_service_vox_egl_default_framebuffer(a0 voidptr) u32 {
    if a0 == unsafe { nil } { return 0 }
    context := unsafe { &MetalServiceContext(a0) }
    return if context.surface { u32(1) } else { u32(0) }
}

@[export: 'vox_egl_default_renderbuffer']
fn metal_service_vox_egl_default_renderbuffer(a0 voidptr) u32 {
    if a0 == unsafe { nil } { return 0 }
    context := unsafe { &MetalServiceContext(a0) }
    return if context.surface && context.depth != unsafe { nil } { u32(2) } else { u32(0) }
}

@[export: 'vox_egl_copy_drawing_buffer']
fn metal_service_vox_egl_copy_drawing_buffer(a0 voidptr, a1 i32, a2 i32, a3 &u8) i32 {
    if a0 == unsafe { nil } || a3 == unsafe { nil } { return 0 }
    mut context := unsafe { &MetalServiceContext(a0) }
    if !context.surface || context.width != int(a1) || context.height != int(a2) { return 0 }
    pixels := context.target.read_pixels() or { context.last_failure = err.msg(); return 0 }
    defer { unsafe { pixels.free() } }
    row := context.width * 4
    for y in 0..context.height { unsafe { vmemcpy(a3 + (context.height - y - 1) * row, &u8(pixels.data) + y * row, row) } }
    return 1
}

@[export: 'vox_egl_clear_drawing_buffer']
fn metal_service_vox_egl_clear_drawing_buffer(a0 voidptr) {
    if a0 == unsafe { nil } { return }
    mut context := unsafe { &MetalServiceContext(a0) }
    color := context.clear_color; depth := context.clear_depth; stencil := context.clear_stencil
    context.clear_color = [f32(0),0,0,0]!
    context.clear_depth = 1; context.clear_stencil = 0
    context.clear_pixels(0x4500) or { context.last_failure = err.msg(); context.error_ = out_of_memory }
    context.clear_color = color; context.clear_depth = depth; context.clear_stencil = stencil
}

@[export: 'vox_gl_gen_object']
fn metal_service_vox_gl_gen_object(a0 i32) u32 {
    mut context := metal_service_current()
    if context == unsafe { nil } { return 0 }
    if a0 < 0 || a0 > 8 { metal_service_error(invalid_value); return 0 }
    name := context.next_id
    if name == 0 { metal_service_error(out_of_memory); return 0 }
    context.next_id++
    context.objects[name] = &MetalServiceObject{kind:int(a0),created:a0==5}
    return name
}

@[export: 'vox_gl_delete_object']
fn metal_service_vox_gl_delete_object(a0 i32, a1 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } || a1 == 0 { return }
    mut object := context.objects[a1] or { return }
    if object.kind != int(a0) || object.deleted { return }
    object.deleted = true
    if a0 == 0 {
        for target,name in context.buffers { if name == a1 { context.buffers[target] = 0 } }
        for key,binding in context.indexed_buffers { if binding.buffer==a1 { context.indexed_buffers.delete(key) } }
        mut vao := context.vao()
        if vao.element_buffer == a1 { vao.element_buffer = 0 }
        for mut attribute in vao.attributes { if attribute.buffer == a1 { attribute.buffer = 0 } }
        context.collect_buffers()
    } else if a0==1 {
        if context.draw_framebuffer==a1 { context.draw_framebuffer=0 };if context.read_framebuffer==a1 { context.read_framebuffer=0 }
    } else if a0==2 {
        if context.renderbuffer==a1 { context.renderbuffer=0 }
    } else if a0==3 {
        for key,name in context.textures { if name==a1 { context.textures[key]=0 } }
    } else if a0==5 {
        for index,name in context.samplers { if name==a1 { context.samplers[index]=0 } }
    } else if a0 in [6,7] {
        if context.vertex_array==a1 { context.vertex_array=0 }
        if vao:=context.vertex_arrays[a1] { context.vertex_arrays.delete(a1); unsafe { free(vao) } }
        context.collect_buffers()
    }
}

@[export: 'vox_gl_begin_query']
fn metal_service_vox_gl_begin_query(a0 u32, a1 u32) {
    metal_service_unsupported('vox_gl_begin_query')
}

@[export: 'vox_gl_end_query']
fn metal_service_vox_gl_end_query(a0 u32) {
    metal_service_unsupported('vox_gl_end_query')
}

@[export: 'vox_gl_query_parameter']
fn metal_service_vox_gl_query_parameter(a0 u32, a1 u32) u32 {
    metal_service_unsupported('vox_gl_query_parameter')
    return 0
}

@[export: 'vox_gl_bind_sampler']
fn metal_service_vox_gl_bind_sampler(a0 u32, a1 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0>=32 { metal_service_error(invalid_value);return }
    if a1!=0 { context.sampler_object(a1) or { return } }
    context.samplers[int(a0)]=a1
}

@[export: 'vox_gl_sampler_parameteri']
fn metal_service_vox_gl_sampler_parameteri(a0 u32, a1 u32, a2 i32) {
    metal_service_sampler_set(a0,a1,f32(a2))
}

@[export: 'vox_gl_sampler_parameterf']
fn metal_service_vox_gl_sampler_parameterf(a0 u32, a1 u32, a2 f32) {
    metal_service_sampler_set(a0,a1,a2)
}

@[export: 'vox_gl_sampler_parameter']
fn metal_service_vox_gl_sampler_parameter(a0 u32, a1 u32) f32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    object:=context.sampler_object(a0) or { return 0 }
    if value:=object.sampling.parameters[a1] { return value }
    metal_service_error(invalid_enum)
    return 0
}

@[export: 'vox_gl_bind_vertex_array']
fn metal_service_vox_gl_bind_vertex_array(a0 u32, a1 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0!=0 {
        mut object:=context.objects[a0] or { metal_service_error(invalid_operation); return }
        if object.kind !in [6,7] || object.deleted { metal_service_error(invalid_operation); return }
        object.created=true
    }
    context.vertex_array=a0
    context.vao()
    context.collect_buffers()
}

@[export: 'vox_gl_is_vertex_array']
fn metal_service_vox_gl_is_vertex_array(a0 u32, a1 i32) i32 {
    context:=metal_service_current()
    if context==unsafe { nil } || a0==0 { return 0 }
    if object:=context.objects[a0] { return i32(object.kind in [6,7] && object.created && !object.deleted) }
    return 0
}

@[export: 'vox_gl_vertex_attrib_parameter']
fn metal_service_vox_gl_vertex_attrib_parameter(a0 u32, a1 u32) i32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } || !context.valid_vertex(a0) { return 0 }
    attribute:=context.vao().attributes[int(a0)]
    return match a1 {
        0x8622 { i32(attribute.enabled) } 0x8623 { i32(attribute.size) }
        0x8624 { i32(attribute.stride) } 0x8625 { i32(attribute.type_) }
        0x886a { i32(attribute.normalized) } 0x889f { i32(attribute.buffer) }
        0x88fd { i32(attribute.integer) } 0x88fe { i32(attribute.divisor) }
        else { metal_service_error(invalid_enum); i32(0) }
    }
}

@[export: 'vox_gl_vertex_attrib_float_parameter']
fn metal_service_vox_gl_vertex_attrib_float_parameter(a0 u32, a1 &f32) {
    context:=metal_service_current()
    if context==unsafe { nil } || a1==unsafe { nil } { return }
    values:=context.current_vertex_numbers(a0) or { return }
    for i in 0..4 { unsafe { a1[i]=f32(values[i]) } }
}

@[export: 'vox_gl_vertex_attrib_offset']
fn metal_service_vox_gl_vertex_attrib_offset(a0 u32) i64 {
    mut context:=metal_service_current()
    if context==unsafe { nil } || !context.valid_vertex(a0) { return 0 }
    return context.vao().attributes[int(a0)].offset
}

@[export: 'vox_gl_bind_transform_feedback']
fn metal_service_vox_gl_bind_transform_feedback(a0 u32, a1 u32) {
    metal_service_unsupported('vox_gl_bind_transform_feedback')
}

@[export: 'vox_gl_begin_transform_feedback']
fn metal_service_vox_gl_begin_transform_feedback(a0 u32) {
    metal_service_unsupported('vox_gl_begin_transform_feedback')
}

@[export: 'vox_gl_end_transform_feedback']
fn metal_service_vox_gl_end_transform_feedback() {
    metal_service_unsupported('vox_gl_end_transform_feedback')
}

@[export: 'vox_gl_pause_transform_feedback']
fn metal_service_vox_gl_pause_transform_feedback() {
    metal_service_unsupported('vox_gl_pause_transform_feedback')
}

@[export: 'vox_gl_resume_transform_feedback']
fn metal_service_vox_gl_resume_transform_feedback() {
    metal_service_unsupported('vox_gl_resume_transform_feedback')
}

@[export: 'vox_gl_transform_feedback_varyings']
fn metal_service_vox_gl_transform_feedback_varyings(a0 u32, a1 i32, a2 voidptr, a3 u32) {
    metal_service_unsupported('vox_gl_transform_feedback_varyings')
}

@[export: 'vox_gl_bind_buffer_base']
fn metal_service_vox_gl_bind_buffer_base(a0 u32, a1 u32, a2 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.bind_indexed_buffer(a0,a1,a2,0,0,false) }
}

@[export: 'vox_gl_bind_buffer_range']
fn metal_service_vox_gl_bind_buffer_range(a0 u32, a1 u32, a2 u32, a3 i64, a4 i64) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.bind_indexed_buffer(a0,a1,a2,a3,a4,true) }
}

@[export: 'vox_gl_bind_buffer']
fn metal_service_vox_gl_bind_buffer(a0 u32, a1 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if !context.valid_buffer_target(a0) { metal_service_error(invalid_enum); return }
    if a1 != 0 {
        mut object := context.objects[a1] or { metal_service_error(invalid_operation); return }
        if object.kind != 0 || object.deleted { metal_service_error(invalid_operation); return }
        if object.gpu_buffer == unsafe { nil } {
            object.gpu_buffer = metal.GPUBuffer.create(context.target,0) or { metal_service_error(out_of_memory); return }
        }
        object.created = true
    }
    if a0 == element_array_buffer { mut vao := context.vao(); vao.element_buffer = a1 }
    else { context.buffers[a0] = a1 }
    context.collect_buffers()
}

@[export: 'vox_gl_buffer_data']
fn metal_service_vox_gl_buffer_data(a0 u32, a1 i64, a2 voidptr, a3 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    mut object := context.bound_buffer(a0) or { return }
    if a1 < 0 || u64(a1) > u64(max_int) { metal_service_error(invalid_value); return }
    valid_usage := a3 in [u32(0x88e0),0x88e4,0x88e8] || (context.version == 3 && a3 in [u32(0x88e1),0x88e2,0x88e5,0x88e6,0x88e9,0x88ea])
    if !valid_usage { metal_service_error(invalid_enum); return }
    mut buffer := metal.GPUBuffer.create(context.target,int(a1)) or { metal_service_error(out_of_memory); return }
    if a2 != unsafe { nil } && a1 > 0 { buffer.write(0,unsafe { (&u8(a2)).vbytes(int(a1)) }) or { buffer.close(); metal_service_error(out_of_memory); return } }
    old := object.gpu_buffer
    object.gpu_buffer = buffer; object.usage = a3
    if old != unsafe { nil } { mut retired := old; retired.close(); unsafe { free(retired) } }
}

@[export: 'vox_gl_buffer_sub_data']
fn metal_service_vox_gl_buffer_sub_data(a0 u32, a1 i64, a2 i64, a3 voidptr) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    mut object := context.bound_buffer(a0) or { return }
    if a1 < 0 || a2 < 0 || a1 > object.gpu_buffer.size() || a2 > i64(object.gpu_buffer.size()) - a1 || (a2 > 0 && a3 == unsafe { nil }) { metal_service_error(invalid_value); return }
    object.gpu_buffer.write(int(a1),unsafe { (&u8(a3)).vbytes(int(a2)) }) or { metal_service_error(invalid_operation) }
}

@[export: 'vox_gl_copy_buffer_sub_data']
fn metal_service_vox_gl_copy_buffer_sub_data(a0 u32, a1 u32, a2 i64, a3 i64, a4 i64) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    source := context.bound_buffer(a0) or { return }
    mut destination := context.bound_buffer(a1) or { return }
    if a2 < 0 || a3 < 0 || a4 < 0 || a2 > source.gpu_buffer.size() || a4 > i64(source.gpu_buffer.size()) - a2
        || a3 > destination.gpu_buffer.size() || a4 > i64(destination.gpu_buffer.size()) - a3 { metal_service_error(invalid_value); return }
    if voidptr(source) == voidptr(destination) && a2 < a3 + a4 && a3 < a2 + a4 { metal_service_error(invalid_value); return }
    bytes := source.gpu_buffer.read(int(a2),int(a4)) or { metal_service_error(invalid_operation); return }
    defer { unsafe { bytes.free() } }
    destination.gpu_buffer.write(int(a3),bytes) or { metal_service_error(invalid_operation) }
}

@[export: 'vox_gl_read_buffer_sub_data']
fn metal_service_vox_gl_read_buffer_sub_data(a0 u32, a1 i64, a2 i64, a3 voidptr) i32 {
    mut context := metal_service_current()
    if context == unsafe { nil } { return 0 }
    object := context.bound_buffer(a0) or { return 0 }
    if a1 < 0 || a2 < 0 || a1 > object.gpu_buffer.size() || a2 > i64(object.gpu_buffer.size()) - a1 || (a2 > 0 && a3 == unsafe { nil }) { metal_service_error(invalid_value); return 0 }
    bytes := object.gpu_buffer.read(int(a1),int(a2)) or { metal_service_error(invalid_operation); return 0 }
    defer { unsafe { bytes.free() } }
    if a2 > 0 { unsafe { vmemcpy(a3,bytes.data,int(a2)) } }
    return 1
}

@[export: 'vox_gl_buffer_parameter']
fn metal_service_vox_gl_buffer_parameter(a0 u32, a1 u32) i32 {
    mut context := metal_service_current()
    if context == unsafe { nil } { return 0 }
    object := context.bound_buffer(a0) or { return 0 }
    if a1 == 0x8764 { return i32(object.gpu_buffer.size()) }
    if a1 == 0x8765 { return i32(object.usage) }
    metal_service_error(invalid_enum)
    return 0
}

@[export: 'vox_gl_vertex_attrib_pointer']
fn metal_service_vox_gl_vertex_attrib_pointer(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32, a5 i64) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_vertex_pointer(a0,int(a1),a2,a3!=0,int(a4),a5,false) }
}

@[export: 'vox_gl_vertex_attrib_i_pointer']
fn metal_service_vox_gl_vertex_attrib_i_pointer(a0 u32, a1 i32, a2 u32, a3 i32, a4 i64) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_vertex_pointer(a0,int(a1),a2,false,int(a3),a4,true) }
}

@[export: 'vox_gl_vertex_attrib1f']
fn metal_service_vox_gl_vertex_attrib1f(a0 u32, a1 f32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_vertex_floats(a0,[a1,f32(0),f32(0),f32(1)]!) }
}

@[export: 'vox_gl_vertex_attrib2f']
fn metal_service_vox_gl_vertex_attrib2f(a0 u32, a1 f32, a2 f32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_vertex_floats(a0,[a1,a2,f32(0),f32(1)]!) }
}

@[export: 'vox_gl_vertex_attrib3f']
fn metal_service_vox_gl_vertex_attrib3f(a0 u32, a1 f32, a2 f32, a3 f32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_vertex_floats(a0,[a1,a2,a3,f32(1)]!) }
}

@[export: 'vox_gl_vertex_attrib4f']
fn metal_service_vox_gl_vertex_attrib4f(a0 u32, a1 f32, a2 f32, a3 f32, a4 f32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_vertex_floats(a0,[a1,a2,a3,a4]!) }
}

@[export: 'vox_gl_vertex_attrib1fv']
fn metal_service_vox_gl_vertex_attrib1fv(a0 u32, a1 &f32) {
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    unsafe { metal_service_vox_gl_vertex_attrib1f(a0,a1[0]) }
}

@[export: 'vox_gl_vertex_attrib2fv']
fn metal_service_vox_gl_vertex_attrib2fv(a0 u32, a1 &f32) {
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    unsafe { metal_service_vox_gl_vertex_attrib2f(a0,a1[0],a1[1]) }
}

@[export: 'vox_gl_vertex_attrib3fv']
fn metal_service_vox_gl_vertex_attrib3fv(a0 u32, a1 &f32) {
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    unsafe { metal_service_vox_gl_vertex_attrib3f(a0,a1[0],a1[1],a1[2]) }
}

@[export: 'vox_gl_vertex_attrib_floats']
fn metal_service_vox_gl_vertex_attrib_floats(a0 u32, a1 &f32) {
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    unsafe { metal_service_vox_gl_vertex_attrib4f(a0,a1[0],a1[1],a1[2],a1[3]) }
}

@[export: 'vox_gl_vertex_attrib_enable']
fn metal_service_vox_gl_vertex_attrib_enable(a0 u32, a1 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || !context.valid_vertex(a0) { return }
    mut vao:=context.vao();vao.attributes[int(a0)].enabled=a1!=0
}

@[export: 'vox_gl_vertex_attrib_divisor']
fn metal_service_vox_gl_vertex_attrib_divisor(a0 u32, a1 u32, a2 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || !context.valid_vertex(a0) { return }
    mut vao:=context.vao();vao.attributes[int(a0)].divisor=a1
}

@[export: 'vox_gl_draw_arrays']
fn metal_service_vox_gl_draw_arrays(a0 u32, a1 i32, a2 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.draw(a0,int(a1),int(a2),1,false,0,0,none) }
}

@[export: 'vox_gl_draw_elements']
fn metal_service_vox_gl_draw_elements(a0 u32, a1 i32, a2 u32, a3 i64) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.draw(a0,0,int(a1),1,true,a2,a3,none) }
}

@[export: 'vox_gl_draw_arrays_instanced']
fn metal_service_vox_gl_draw_arrays_instanced(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.draw(a0,int(a1),int(a2),int(a3),false,0,0,none) }
}

@[export: 'vox_gl_draw_elements_instanced']
fn metal_service_vox_gl_draw_elements_instanced(a0 u32, a1 i32, a2 u32, a3 i64, a4 i32, a5 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.draw(a0,0,int(a1),int(a4),true,a2,a3,none) }
}

@[export: 'vox_gl_draw_range_elements']
fn metal_service_vox_gl_draw_range_elements(a0 u32, a1 u32, a2 u32, a3 i32, a4 u32, a5 i64) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { if a2<a1 { metal_service_error(invalid_value);return };context.draw(a0,0,int(a3),1,true,a4,a5,a2) }
}

@[export: 'vox_gl_bind_framebuffer']
fn metal_service_vox_gl_bind_framebuffer(a0 u32, a1 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.bind_framebuffer(a0,a1) }
}

@[export: 'vox_gl_bind_renderbuffer']
fn metal_service_vox_gl_bind_renderbuffer(a0 u32, a1 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.bind_renderbuffer(a0,a1) }
}

@[export: 'vox_gl_bind_texture']
fn metal_service_vox_gl_bind_texture(a0 u32, a1 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.bind_texture(a0,a1) }
}

@[export: 'vox_gl_framebuffer_status']
fn metal_service_vox_gl_framebuffer_status(a0 u32) u32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return context.framebuffer_status(a0)
}

@[export: 'vox_gl_framebuffer_texture']
fn metal_service_vox_gl_framebuffer_texture(a0 u32, a1 u32, a2 u32, a3 u32, a4 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.attach_texture(a0,a1,a2,a3,int(a4),0,false) }
}

@[export: 'vox_gl_framebuffer_renderbuffer']
fn metal_service_vox_gl_framebuffer_renderbuffer(a0 u32, a1 u32, a2 u32, a3 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.attach_renderbuffer(a0,a1,a2,a3) }
}

@[export: 'vox_gl_renderbuffer_storage']
fn metal_service_vox_gl_renderbuffer_storage(a0 u32, a1 u32, a2 i32, a3 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.renderbuffer_storage(a0,0,a1,int(a2),int(a3)) }
}

@[export: 'vox_gl_tex_image2d']
fn metal_service_vox_gl_tex_image2d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 u32, a7 u32, a8 i32, a9 voidptr) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0!=texture_2d && (a0<0x8515 || a0>0x851a) { metal_service_error(invalid_enum);return }
    context.define_texture_image(a0,int(a1),u32(a2),int(a3),int(a4),1,int(a5),a6,a7,int(a8),a9)
}

@[export: 'vox_gl_compressed_tex_image2d']
fn metal_service_vox_gl_compressed_tex_image2d(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32, a5 i32, a6 i32, a7 voidptr) {
    metal_service_unsupported('vox_gl_compressed_tex_image2d')
}

@[export: 'vox_gl_compressed_tex_sub_image2d']
fn metal_service_vox_gl_compressed_tex_sub_image2d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 u32, a7 i32, a8 voidptr) {
    metal_service_unsupported('vox_gl_compressed_tex_sub_image2d')
}

@[export: 'vox_gl_compressed_tex_image3d']
fn metal_service_vox_gl_compressed_tex_image3d(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32, a5 i32, a6 i32, a7 i32, a8 voidptr) {
    metal_service_unsupported('vox_gl_compressed_tex_image3d')
}

@[export: 'vox_gl_compressed_tex_sub_image3d']
fn metal_service_vox_gl_compressed_tex_sub_image3d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 i32, a7 i32, a8 u32, a9 i32, a10 voidptr) {
    metal_service_unsupported('vox_gl_compressed_tex_sub_image3d')
}

@[export: 'vox_gl_tex_sub_image2d']
fn metal_service_vox_gl_tex_sub_image2d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 u32, a7 u32, a8 i32, a9 voidptr) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0!=texture_2d && (a0<0x8515 || a0>0x851a) { metal_service_error(invalid_enum);return }
    context.sub_texture_image(a0,int(a1),int(a2),int(a3),0,int(a4),int(a5),1,a6,a7,int(a8),a9)
}

@[export: 'vox_gl_tex_parameteri']
fn metal_service_vox_gl_tex_parameteri(a0 u32, a1 u32, a2 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.texture_parameter(a0,a1,f32(a2),true) }
}

@[export: 'vox_gl_tex_parameterf']
fn metal_service_vox_gl_tex_parameterf(a0 u32, a1 u32, a2 f32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.texture_parameter(a0,a1,a2,true) }
}

@[export: 'vox_gl_tex_storage2d']
fn metal_service_vox_gl_tex_storage2d(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0 !in [texture_2d,texture_cube_map] { metal_service_error(invalid_enum);return }
    context.texture_storage(a0,int(a1),a2,int(a3),int(a4),1)
}

@[export: 'vox_gl_tex_storage3d']
fn metal_service_vox_gl_tex_storage3d(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32, a5 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0 !in [texture_3d,texture_2d_array] { metal_service_error(invalid_enum);return }
    context.texture_storage(a0,int(a1),a2,int(a3),int(a4),int(a5))
}

@[export: 'vox_gl_tex_image3d']
fn metal_service_vox_gl_tex_image3d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 i32, a7 u32, a8 u32, a9 i32, a10 voidptr) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0 !in [texture_3d,texture_2d_array] { metal_service_error(invalid_enum);return }
    context.define_texture_image(a0,int(a1),u32(a2),int(a3),int(a4),int(a5),int(a6),a7,a8,int(a9),a10)
}

@[export: 'vox_gl_tex_sub_image3d']
fn metal_service_vox_gl_tex_sub_image3d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 i32, a7 i32, a8 u32, a9 u32, a10 i32, a11 voidptr) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0 !in [texture_3d,texture_2d_array] { metal_service_error(invalid_enum);return }
    context.sub_texture_image(a0,int(a1),int(a2),int(a3),int(a4),int(a5),int(a6),int(a7),a8,a9,int(a10),a11)
}

@[export: 'vox_gl_framebuffer_texture_layer']
fn metal_service_vox_gl_framebuffer_texture_layer(a0 u32, a1 u32, a2 u32, a3 i32, a4 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.attach_texture(a0,a1,0,a2,int(a3),int(a4),true) }
}

@[export: 'vox_gl_copy_tex_image2d']
fn metal_service_vox_gl_copy_tex_image2d(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32, a5 i32, a6 i32, a7 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.copy_texture(a0,int(a1),a2,0,0,int(a3),int(a4),int(a5),int(a6),int(a7),true) }
}

@[export: 'vox_gl_copy_tex_sub_image2d']
fn metal_service_vox_gl_copy_tex_sub_image2d(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 i32, a7 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.copy_texture(a0,int(a1),0,int(a2),int(a3),int(a4),int(a5),int(a6),int(a7),0,false) }
}

@[export: 'vox_gl_draw_buffers']
fn metal_service_vox_gl_draw_buffers(a0 i32, a1 &u32, a2 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_draw_buffers(int(a0),a1) }
}

@[export: 'vox_gl_read_buffer']
fn metal_service_vox_gl_read_buffer(a0 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.set_read_buffer(a0) }
}

@[export: 'vox_gl_blit_framebuffer']
fn metal_service_vox_gl_blit_framebuffer(a0 i32, a1 i32, a2 i32, a3 i32, a4 i32, a5 i32, a6 i32, a7 i32, a8 u32, a9 u32) {
    metal_service_unsupported('vox_gl_blit_framebuffer')
}

@[export: 'vox_gl_renderbuffer_storage_multisample']
fn metal_service_vox_gl_renderbuffer_storage_multisample(a0 u32, a1 i32, a2 u32, a3 i32, a4 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.renderbuffer_storage(a0,int(a1),a2,int(a3),int(a4)) }
}

@[export: 'vox_gl_invalidate_framebuffer']
fn metal_service_vox_gl_invalidate_framebuffer(a0 u32, a1 i32, a2 &u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.invalidate_framebuffer(a0,int(a1),a2,0,0,0,0) }
}

@[export: 'vox_gl_invalidate_sub_framebuffer']
fn metal_service_vox_gl_invalidate_sub_framebuffer(a0 u32, a1 i32, a2 &u32, a3 i32, a4 i32, a5 i32, a6 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.invalidate_framebuffer(a0,int(a1),a2,int(a3),int(a4),int(a5),int(a6)) }
}

@[export: 'vox_gl_tex_parameter']
fn metal_service_vox_gl_tex_parameter(a0 u32, a1 u32) i32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return i32(context.texture_parameter(a0,a1,0,false))
}

@[export: 'vox_gl_tex_float_parameter']
fn metal_service_vox_gl_tex_float_parameter(a0 u32, a1 u32) f32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return context.texture_parameter(a0,a1,0,false)
}

@[export: 'vox_gl_renderbuffer_parameter']
fn metal_service_vox_gl_renderbuffer_parameter(a0 u32, a1 u32) i32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return context.renderbuffer_parameter(a0,a1)
}

@[export: 'vox_gl_read_pixels_to_buffer']
fn metal_service_vox_gl_read_pixels_to_buffer(a0 i32, a1 i32, a2 i32, a3 i32, a4 u32, a5 u32, a6 i64) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.read_pixels_to_buffer(int(a0),int(a1),int(a2),int(a3),a4,a5,a6) }
}

@[export: 'vox_gl_read_pixels']
fn metal_service_vox_gl_read_pixels(a0 i32, a1 i32, a2 i32, a3 i32, a4 u32, a5 u32, a6 i32, a7 voidptr) i32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return i32(context.read_pixels(int(a0),int(a1),int(a2),int(a3),a4,a5,int(a6),a7))
}

@[export: 'vox_gl_clear_color']
fn metal_service_vox_gl_clear_color(a0 f32, a1 f32, a2 f32, a3 f32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    context.clear_color = [metal_service_unit(a0),metal_service_unit(a1),metal_service_unit(a2),metal_service_unit(a3)]!
    context.set_parameter(color_clear_value,context.clear_color.map(f64(it)))
}

@[export: 'vox_gl_clear_depth']
fn metal_service_vox_gl_clear_depth(a0 f32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    context.clear_depth = metal_service_unit(a0)
    context.set_parameter(depth_clear_value,[f64(context.clear_depth)])
}

@[export: 'vox_gl_clear_stencil']
fn metal_service_vox_gl_clear_stencil(a0 i32) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.clear_stencil = u32(a0) & 255; context.set_parameter(stencil_clear_value,[f64(a0)]) }
}

@[export: 'vox_gl_color_mask']
fn metal_service_vox_gl_color_mask(a0 i32, a1 i32, a2 i32, a3 i32) {
    mut context := metal_service_current()
    if context != unsafe { nil } {
        context.color_mask = u32(a0 != 0) | (u32(a1 != 0) << 1) | (u32(a2 != 0) << 2) | (u32(a3 != 0) << 3)
        context.set_parameter(color_writemask,[f64(a0 != 0),f64(a1 != 0),f64(a2 != 0),f64(a3 != 0)])
    }
}

@[export: 'vox_gl_depth_mask']
fn metal_service_vox_gl_depth_mask(a0 i32) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.depth_mask = a0 != 0; context.set_parameter(depth_writemask,[f64(a0 != 0)]) }
}

@[export: 'vox_gl_clear']
fn metal_service_vox_gl_clear(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 & ~u32(0x4500) != 0 { metal_service_error(invalid_value); return }
    context.clear_pixels(a0) or { context.last_failure = err.msg(); metal_service_error(out_of_memory) }
}

@[export: 'vox_gl_viewport']
fn metal_service_vox_gl_viewport(a0 i32, a1 i32, a2 i32, a3 i32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a2 < 0 || a3 < 0 { metal_service_error(invalid_value); return }
    context.viewport = metal.Viewport{x:f64(a0),y:f64(a1),width:f64(if a2 > 16384 { i32(16384) } else { a2 }),height:f64(if a3 > 16384 { i32(16384) } else { a3 })}
}

@[export: 'vox_gl_scissor']
fn metal_service_vox_gl_scissor(a0 i32, a1 i32, a2 i32, a3 i32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a2 < 0 || a3 < 0 { metal_service_error(invalid_value); return }
    context.scissor = metal.ScissorRect{x:int(a0),y:int(a1),width:int(a2),height:int(a3)}
}

@[export: 'vox_gl_enable']
fn metal_service_vox_gl_enable(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if !context.valid_capability(a0) { metal_service_error(invalid_enum); return }
    context.enabled[a0] = true
    if a0 == scissor_test { context.scissor_enabled = true }
}

@[export: 'vox_gl_is_enabled']
fn metal_service_vox_gl_is_enabled(a0 u32) i32 {
    context := metal_service_current()
    if context == unsafe { nil } { return 0 }
    if !context.valid_capability(a0) { metal_service_error(invalid_enum); return 0 }
    return i32(context.enabled[a0])
}

@[export: 'vox_gl_disable']
fn metal_service_vox_gl_disable(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if !context.valid_capability(a0) { metal_service_error(invalid_enum); return }
    context.enabled[a0] = false
    if a0 == scissor_test { context.scissor_enabled = false }
}

@[export: 'vox_gl_pixel_storei']
fn metal_service_vox_gl_pixel_storei(a0 u32, a1 i32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    alignment := a0 in [pack_alignment,unpack_alignment]
    extended := context.version==3 && a0 in [u32(0xd02),0xd03,0xd04,0x806e,0xcf2,0x806d,0xcf3,0xcf4]
    if !alignment && !extended { metal_service_error(invalid_enum); return }
    if (alignment && a1 !in [i32(1),2,4,8]) || (extended && a1 < 0) { metal_service_error(invalid_value); return }
    context.set_parameter(a0,[f64(a1)])
}

@[export: 'vox_gl_active_texture']
fn metal_service_vox_gl_active_texture(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 < texture0 || a0 >= texture0 + 32 { metal_service_error(invalid_enum); return }
    context.set_parameter(active_texture,[f64(a0)])
}

@[export: 'vox_gl_blend_color']
fn metal_service_vox_gl_blend_color(a0 f32, a1 f32, a2 f32, a3 f32) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.set_parameter(blend_color,[f64(metal_service_unit(a0)),f64(metal_service_unit(a1)),f64(metal_service_unit(a2)),f64(metal_service_unit(a3))]) }
}

@[export: 'vox_gl_blend_equation']
fn metal_service_vox_gl_blend_equation(a0 u32) {
    metal_service_vox_gl_blend_equation_separate(a0,a0)
}

@[export: 'vox_gl_blend_equation_separate']
fn metal_service_vox_gl_blend_equation_separate(a0 u32, a1 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    for value in [a0,a1] {
        if value !in [func_add,func_subtract,func_reverse_subtract] && !(context.version==3 && value in [u32(0x8007),0x8008]) { metal_service_error(invalid_enum); return }
    }
    context.set_parameter(blend_equation_rgb,[f64(a0)]); context.set_parameter(blend_equation_alpha,[f64(a1)])
}

@[export: 'vox_gl_blend_func']
fn metal_service_vox_gl_blend_func(a0 u32, a1 u32) {
    metal_service_vox_gl_blend_func_separate(a0,a1,a0,a1)
}

@[export: 'vox_gl_blend_func_separate']
fn metal_service_vox_gl_blend_func_separate(a0 u32, a1 u32, a2 u32, a3 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if !metal_service_valid_blend_factor(a0,true) || !metal_service_valid_blend_factor(a1,false) || !metal_service_valid_blend_factor(a2,true) || !metal_service_valid_blend_factor(a3,false) { metal_service_error(invalid_enum); return }
    color_factor := a0 in [u32(0x8001),0x8002] || a1 in [u32(0x8001),0x8002]
    alpha_factor := a0 in [u32(0x8003),0x8004] || a1 in [u32(0x8003),0x8004]
    if color_factor && alpha_factor { metal_service_error(invalid_operation); return }
    context.set_parameter(blend_src_rgb,[f64(a0)]); context.set_parameter(blend_dst_rgb,[f64(a1)])
    context.set_parameter(blend_src_alpha,[f64(a2)]); context.set_parameter(blend_dst_alpha,[f64(a3)])
}

@[export: 'vox_gl_cull_face']
fn metal_service_vox_gl_cull_face(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 !in [front,back,front_and_back] { metal_service_error(invalid_enum); return }
    context.set_parameter(cull_face_mode,[f64(a0)])
}

@[export: 'vox_gl_depth_func']
fn metal_service_vox_gl_depth_func(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 < 0x200 || a0 > 0x207 { metal_service_error(invalid_enum); return }
    context.set_parameter(depth_func,[f64(a0)])
}

@[export: 'vox_gl_depth_range']
fn metal_service_vox_gl_depth_range(a0 f32, a1 f32) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.set_parameter(depth_range,[f64(metal_service_unit(a0)),f64(metal_service_unit(a1))]) }
}

@[export: 'vox_gl_finish']
fn metal_service_vox_gl_finish() {
    // All commands currently complete synchronously.
}

@[export: 'vox_gl_flush']
fn metal_service_vox_gl_flush() {
    // All commands currently complete synchronously.
}

@[export: 'vox_gl_front_face']
fn metal_service_vox_gl_front_face(a0 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 !in [u32(0x900),0x901] { metal_service_error(invalid_enum); return }
    context.set_parameter(front_face,[f64(a0)])
}

@[export: 'vox_gl_generate_mipmap']
fn metal_service_vox_gl_generate_mipmap(a0 u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.generate_mipmap(a0) }
}

@[export: 'vox_gl_hint']
fn metal_service_vox_gl_hint(a0 u32, a1 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 !in [generate_mipmap_hint,fragment_shader_derivative_hint] || a1 !in [u32(0x1100),0x1101,0x1102] { metal_service_error(invalid_enum); return }
    context.set_parameter(a0,[f64(a1)])
}

@[export: 'vox_gl_line_width']
fn metal_service_vox_gl_line_width(a0 f32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 <= 0 { metal_service_error(invalid_value); return }
    context.set_parameter(line_width,[f64(a0)])
}

@[export: 'vox_gl_polygon_offset']
fn metal_service_vox_gl_polygon_offset(a0 f32, a1 f32) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.set_parameter(polygon_offset_factor,[f64(a0)]); context.set_parameter(polygon_offset_units,[f64(a1)]) }
}

@[export: 'vox_gl_sample_coverage']
fn metal_service_vox_gl_sample_coverage(a0 f32, a1 i32) {
    mut context := metal_service_current()
    if context != unsafe { nil } { context.set_parameter(sample_coverage_value,[f64(metal_service_unit(a0))]); context.set_parameter(sample_coverage_invert,[f64(a1 != 0)]) }
}

@[export: 'vox_gl_stencil_func']
fn metal_service_vox_gl_stencil_func(a0 u32, a1 i32, a2 u32) {
    metal_service_vox_gl_stencil_func_separate(front_and_back,a0,a1,a2)
}

@[export: 'vox_gl_stencil_func_separate']
fn metal_service_vox_gl_stencil_func_separate(a0 u32, a1 u32, a2 i32, a3 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 !in [front,back,front_and_back] || a1 < 0x200 || a1 > 0x207 { metal_service_error(invalid_enum); return }
    reference := if a2 < 0 { i32(0) } else if a2 > 255 { i32(255) } else { a2 }
    if a0 != back { context.set_parameter(stencil_func,[f64(a1)]); context.set_parameter(stencil_ref,[f64(reference)]); context.set_parameter(stencil_value_mask,[f64(i32(a3))]) }
    if a0 != front { context.set_parameter(stencil_back_func,[f64(a1)]); context.set_parameter(stencil_back_ref,[f64(reference)]); context.set_parameter(stencil_back_value_mask,[f64(i32(a3))]) }
}

@[export: 'vox_gl_stencil_mask']
fn metal_service_vox_gl_stencil_mask(a0 u32) {
    metal_service_vox_gl_stencil_mask_separate(front_and_back,a0)
}

@[export: 'vox_gl_stencil_mask_separate']
fn metal_service_vox_gl_stencil_mask_separate(a0 u32, a1 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 !in [front,back,front_and_back] { metal_service_error(invalid_enum); return }
    if a0 != back { context.front_stencil_mask=a1 & 255; context.set_parameter(stencil_writemask,[f64(i32(a1))]) }
    if a0 != front { context.set_parameter(stencil_back_writemask,[f64(i32(a1))]) }
}

@[export: 'vox_gl_stencil_op']
fn metal_service_vox_gl_stencil_op(a0 u32, a1 u32, a2 u32) {
    metal_service_vox_gl_stencil_op_separate(front_and_back,a0,a1,a2)
}

@[export: 'vox_gl_stencil_op_separate']
fn metal_service_vox_gl_stencil_op_separate(a0 u32, a1 u32, a2 u32, a3 u32) {
    mut context := metal_service_current()
    if context == unsafe { nil } { return }
    if a0 !in [front,back,front_and_back] { metal_service_error(invalid_enum); return }
    for value in [a1,a2,a3] { if value !in [u32(0),0x1e00,0x1e01,0x1e02,0x1e03,0x150a,0x8507,0x8508] { metal_service_error(invalid_enum); return } }
    if a0 != back { context.set_parameter(stencil_fail,[f64(a1)]); context.set_parameter(stencil_pass_depth_fail,[f64(a2)]); context.set_parameter(stencil_pass_depth_pass,[f64(a3)]) }
    if a0 != front { context.set_parameter(stencil_back_fail,[f64(a1)]); context.set_parameter(stencil_back_pass_depth_fail,[f64(a2)]); context.set_parameter(stencil_back_pass_depth_pass,[f64(a3)]) }
}

@[export: 'vox_gl_clear_buffer_floats']
fn metal_service_vox_gl_clear_buffer_floats(a0 u32, a1 i32, a2 &f32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.clear_buffer(a0,int(a1),13,a2,0,0) }
}

@[export: 'vox_gl_clear_buffer_ints']
fn metal_service_vox_gl_clear_buffer_ints(a0 u32, a1 i32, a2 &i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.clear_buffer(a0,int(a1),7,a2,0,0) }
}

@[export: 'vox_gl_clear_buffer_uints']
fn metal_service_vox_gl_clear_buffer_uints(a0 u32, a1 i32, a2 &u32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.clear_buffer(a0,int(a1),8,a2,0,0) }
}

@[export: 'vox_gl_clear_buffer_depth_stencil']
fn metal_service_vox_gl_clear_buffer_depth_stencil(a0 u32, a1 i32, a2 f32, a3 i32) {
    mut context:=metal_service_current()
    if context!=unsafe { nil } { context.clear_buffer(a0,int(a1),0,unsafe { nil },a2,a3) }
}

@[export: 'vox_gl_vertex_attrib_i4i']
fn metal_service_vox_gl_vertex_attrib_i4i(a0 u32, a1 i32, a2 i32, a3 i32, a4 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || !context.valid_vertex(a0) { return }
    context.current_attributes[int(a0)].kind=7
    context.current_attributes[int(a0)].signed=[a1,a2,a3,a4]!
}

@[export: 'vox_gl_vertex_attrib_i4ui']
fn metal_service_vox_gl_vertex_attrib_i4ui(a0 u32, a1 u32, a2 u32, a3 u32, a4 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || !context.valid_vertex(a0) { return }
    context.current_attributes[int(a0)].kind=8
    context.current_attributes[int(a0)].unsigned=[a1,a2,a3,a4]!
}

@[export: 'vox_gl_vertex_attrib_ints']
fn metal_service_vox_gl_vertex_attrib_ints(a0 u32, a1 &i32) {
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    unsafe { metal_service_vox_gl_vertex_attrib_i4i(a0,a1[0],a1[1],a1[2],a1[3]) }
}

@[export: 'vox_gl_vertex_attrib_uints']
fn metal_service_vox_gl_vertex_attrib_uints(a0 u32, a1 &u32) {
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    unsafe { metal_service_vox_gl_vertex_attrib_i4ui(a0,a1[0],a1[1],a1[2],a1[3]) }
}

@[export: 'vox_gl_vertex_attrib_int_parameter']
fn metal_service_vox_gl_vertex_attrib_int_parameter(a0 u32, a1 &i32) {
    context:=metal_service_current()
    if context==unsafe { nil } || a1==unsafe { nil } { return }
    values:=context.current_vertex_numbers(a0) or { return }
    for i in 0..4 { unsafe { a1[i]=i32(values[i]) } }
}

@[export: 'vox_gl_vertex_attrib_uint_parameter']
fn metal_service_vox_gl_vertex_attrib_uint_parameter(a0 u32, a1 &u32) {
    context:=metal_service_current()
    if context==unsafe { nil } || a1==unsafe { nil } { return }
    values:=context.current_vertex_numbers(a0) or { return }
    for i in 0..4 { unsafe { a1[i]=u32(values[i]) } }
}

@[export: 'vox_gl_float_parameter']
fn metal_service_vox_gl_float_parameter(a0 u32, a1 &f32) {
    mut context := metal_service_current()
    if context == unsafe { nil } || a1 == unsafe { nil } { return }
    values := context.parameter(a0) or { return }
    defer { unsafe { values.free() } }
    for i,value in values { unsafe { a1[i] = f32(value) } }
}

@[export: 'vox_gl_int_parameter']
fn metal_service_vox_gl_int_parameter(a0 u32, a1 &i32) {
    mut context := metal_service_current()
    if context == unsafe { nil } || a1 == unsafe { nil } { return }
    values := context.parameter(a0) or { return }
    defer { unsafe { values.free() } }
    for i,value in values { unsafe { a1[i] = i32(value) } }
}

@[export: 'vox_gl_create_shader']
fn metal_service_vox_gl_create_shader(a0 u32) u32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    if a0 !in [vertex_shader,fragment_shader] { metal_service_error(invalid_enum); return 0 }
    name:=context.new_object(9)
    if name!=0 { mut shader:=context.objects[name] or { return 0 }; shader.shader_type=a0 }
    return name
}

@[export: 'vox_gl_create_program']
fn metal_service_vox_gl_create_program() u32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return context.new_object(10)
}

@[export: 'vox_gl_shader_source']
fn metal_service_vox_gl_shader_source(a0 u32, a1 &char, a2 i32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut shader:=context.object(a0,9) or { return }
    if a1==unsafe { nil } { metal_service_error(invalid_value); return }
    source:=unsafe { if a2<0 { cstring_to_vstring(a1).clone() } else { tos(a1,int(a2)).clone() } }
    unsafe { shader.source.free() }
    shader.source=source
}

@[export: 'vox_gl_compile_shader']
fn metal_service_vox_gl_compile_shader(a0 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut shader:=context.object(a0,9) or { return }
    mut log:=[]u8{len:16384}
    defer { unsafe { log.free() } }
    shader.compiled=C.vox_metal_service_validate_stage(shader.source.str,i32(shader.source.len),i32(shader.shader_type==fragment_shader),i32(context.version),&char(log.data),u64(log.len))==1
    unsafe { shader.log.free() }
    shader.log=unsafe { cstring_to_vstring(&char(log.data)).clone() }
    if shader.compiled { unsafe { shader.compiled_source.free() }; shader.compiled_source=shader.source.clone() }
}

@[export: 'vox_gl_attach_shader']
fn metal_service_vox_gl_attach_shader(a0 u32, a1 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut program:=context.object(a0,10) or { return }
    shader:=context.object(a1,9) or { return }
    for name in program.attached {
        attached:=context.objects[name] or { continue }
        if attached.shader_type==shader.shader_type { metal_service_error(invalid_operation); return }
    }
    program.attached << a1
}

@[export: 'vox_gl_detach_shader']
fn metal_service_vox_gl_detach_shader(a0 u32, a1 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut program:=context.object(a0,10) or { return }
    context.object(a1,9) or { return }
    index:=program.attached.index(a1)
    if index<0 { metal_service_error(invalid_operation); return }
    program.attached.delete(index)
    context.collect_programs()
}

@[export: 'vox_gl_link_program']
fn metal_service_vox_gl_link_program(a0 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut program:=context.object(a0,10) or { return }
    program.linked=false; program.validated=false
    unsafe { program.log.free() }; program.log=''
    mut vertex:=''; mut fragment:=''
    for name in program.attached {
        shader:=context.objects[name] or { continue }
        if !shader.compiled { program.log='Attached shader did not compile'.clone(); return }
        if shader.shader_type==vertex_shader { vertex=shader.compiled_source }
        if shader.shader_type==fragment_shader { fragment=shader.compiled_source }
    }
    if vertex.len==0 || fragment.len==0 { program.log='Both vertex and fragment shaders are required'.clone(); return }
    mut compiled:=metal.ShaderProgram.compile_with_bindings(context.target,vertex,fragment,context.version,program.bindings) or { program.log=err.msg().clone(); return }
    program.reflect_program(compiled) or { compiled.close(); unsafe { free(compiled) }; program.log=err.msg().clone(); return }
    if program.program!=unsafe { nil } { program.program.close(); unsafe { free(program.program) } }
    program.program=compiled; program.linked=true
}

@[export: 'vox_gl_use_program']
fn metal_service_vox_gl_use_program(a0 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0!=0 { context.linked_program(a0) or { return } }
    context.current_program=a0
    context.collect_programs()
}

@[export: 'vox_gl_validate_program']
fn metal_service_vox_gl_validate_program(a0 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut program:=context.object(a0,10) or { return }
    program.validated=program.linked
}

@[export: 'vox_gl_delete_shader']
fn metal_service_vox_gl_delete_shader(a0 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || a0==0 { return }
    mut shader:=context.object(a0,9) or { return }
    shader.deleted=true; context.collect_programs()
}

@[export: 'vox_gl_delete_program']
fn metal_service_vox_gl_delete_program(a0 u32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } || a0==0 { return }
    mut program:=context.object(a0,10) or { return }
    program.deleted=true; context.collect_programs()
}

@[export: 'vox_gl_shader_parameter']
fn metal_service_vox_gl_shader_parameter(a0 u32, a1 u32) i32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return context.shader_parameter(a0,a1)
}

@[export: 'vox_gl_shader_parameter_robust']
fn metal_service_vox_gl_shader_parameter_robust(a0 u32, a1 u32) i32 {
    return metal_service_vox_gl_shader_parameter(a0,a1)
}

@[export: 'vox_gl_program_parameter']
fn metal_service_vox_gl_program_parameter(a0 u32, a1 u32) i32 {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    return context.program_parameter(a0,a1)
}

@[export: 'vox_gl_program_parameter_robust']
fn metal_service_vox_gl_program_parameter_robust(a0 u32, a1 u32) i32 {
    return metal_service_vox_gl_program_parameter(a0,a1)
}

@[export: 'vox_gl_shader_log']
fn metal_service_vox_gl_shader_log(a0 u32, a1 i32, a2 &char) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    shader:=context.object(a0,9) or { return }
    metal_service_copy_string(shader.log,a1,a2)
}

@[export: 'vox_gl_get_shader_source']
fn metal_service_vox_gl_get_shader_source(a0 u32, a1 i32, a2 &char) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    shader:=context.object(a0,9) or { return }
    metal_service_copy_string(shader.source,a1,a2)
}

@[export: 'vox_gl_program_log']
fn metal_service_vox_gl_program_log(a0 u32, a1 i32, a2 &char) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    program:=context.object(a0,10) or { return }
    metal_service_copy_string(program.log,a1,a2)
}

@[export: 'vox_gl_uniform_location']
fn metal_service_vox_gl_uniform_location(a0 u32, a1 &char) i32 {
    context:=metal_service_current()
    if context==unsafe { nil } { return -1 }
    program:=context.linked_program(a0) or { return -1 }
    if a1==unsafe { nil } { return -1 }
    name:=unsafe { cstring_to_vstring(a1) }
    for index,location in program.locations {
        info:=program.uniforms[location.uniform]
        candidate:=info.lookup+'['+location.element.str()+']'
        if name==candidate || (location.element==0 && (name==info.lookup || name==info.name)) { return i32(index) }
    }
    return -1
}

@[export: 'vox_gl_attrib_location']
fn metal_service_vox_gl_attrib_location(a0 u32, a1 &char) i32 {
    context:=metal_service_current()
    if context==unsafe { nil } { return -1 }
    program:=context.linked_program(a0) or { return -1 }
    if a1==unsafe { nil } { return -1 }
    name:=unsafe { cstring_to_vstring(a1) }
    for info in program.attributes { if info.name==name { return i32(info.resource.location) } }
    return -1
}

@[export: 'vox_gl_bind_attrib_location']
fn metal_service_vox_gl_bind_attrib_location(a0 u32, a1 u32, a2 &char) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut program:=context.object(a0,10) or { return }
    if a1>=16 { metal_service_error(invalid_value); return }
    if a2==unsafe { nil } { metal_service_error(invalid_value); return }
    name:=unsafe { cstring_to_vstring(a2) }
    if name.starts_with('gl_') { metal_service_error(invalid_operation); return }
    program.bindings[name.clone()]=int(a1)
}

@[export: 'vox_gl_active_info']
fn metal_service_vox_gl_active_info(a0 u32, a1 u32, a2 i32, a3 i32, a4 &char, a5 &i32, a6 &u32) i32 {
    context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    program:=context.linked_program(a0) or { return 0 }
    list:=if a2!=0 { program.uniforms } else { program.attributes }
    if u64(a1)>=u64(list.len) || a3<0 { metal_service_error(invalid_value); return 0 }
    info:=list[int(a1)]
    metal_service_copy_string(info.name,a3,a4)
    unsafe { if a5!=nil { *a5=i32(info.size) }; if a6!=nil { *a6=info.type_ } }
    return if a3>0 { i32(if info.name.len<int(a3)-1 { info.name.len } else { int(a3)-1 }) } else { i32(0) }
}

@[export: 'vox_gl_uniform_indices']
fn metal_service_vox_gl_uniform_indices(a0 u32, a1 i32, a2 voidptr, a3 &u32) {
    metal_service_uniform_indices(a0,a1,a2,a3)
}

@[export: 'vox_gl_active_uniforms']
fn metal_service_vox_gl_active_uniforms(a0 u32, a1 i32, a2 &u32, a3 u32, a4 &i32) {
    metal_service_active_uniforms(a0,a1,a2,a3,a4)
}

@[export: 'vox_gl_uniform_block_index']
fn metal_service_vox_gl_uniform_block_index(a0 u32, a1 &char) u32 {
    context:=metal_service_current()
    if context==unsafe { nil } { return ~u32(0) }
    program:=context.linked_program(a0) or { return ~u32(0) }
    if a1!=unsafe { nil } { name:=unsafe { cstring_to_vstring(a1) };for i,block in program.blocks { if block.name==name { return u32(i) } } }
    return ~u32(0)
}

@[export: 'vox_gl_uniform_block_parameter']
fn metal_service_vox_gl_uniform_block_parameter(a0 u32, a1 u32, a2 u32, a3 i32, a4 &i32) {
    metal_service_block_parameter(a0,a1,a2,a3,a4)
}

@[export: 'vox_gl_uniform_block_name']
fn metal_service_vox_gl_uniform_block_name(a0 u32, a1 u32, a2 i32, a3 &char) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    program:=context.linked_program(a0) or { return }
    if a1>=u32(program.blocks.len) { metal_service_error(invalid_value);return }
    metal_service_copy_string(program.blocks[int(a1)].name,a2,a3)
}

@[export: 'vox_gl_uniform_block_binding']
fn metal_service_vox_gl_uniform_block_binding(a0 u32, a1 u32, a2 u32) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut program:=context.linked_program(a0) or { return }
    if a1>=u32(program.blocks.len) || a2>=30 { metal_service_error(invalid_value);return }
    program.blocks[int(a1)].binding=a2
}

@[export: 'vox_gl_internalformat_parameter']
fn metal_service_vox_gl_internalformat_parameter(a0 u32, a1 u32, a2 u32, a3 i32, a4 &i32) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    if a0!=renderbuffer || a1 !in [u32(0x8058),0x8056,0x8057,0x8d62,0x8c43,0x8229,0x822b,0x881a,0x8814,0x8d48,0x81a5,0x81a6,0x8cac,0x88f0,0x8cad] || a2 !in [samples,num_sample_counts] { metal_service_error(invalid_enum);return }
    if a3<0 { metal_service_error(invalid_value);return }
    counts:=context.target.sample_counts()
    defer { unsafe { counts.free() } }
    if a3==0 || a4==unsafe { nil } { return }
    if a2==num_sample_counts { unsafe { *a4=i32(counts.len) };return }
    for i,count in counts { if i>=int(a3) { break };unsafe { a4[i]=i32(count) } }
}

@[export: 'vox_gl_shader_precision']
fn metal_service_vox_gl_shader_precision(a0 u32, a1 u32, a2 &i32, a3 &i32) {
    if a0 !in [vertex_shader,fragment_shader] || a1 !in [u32(0x8df0),0x8df1,0x8df2,0x8df3,0x8df4,0x8df5] { metal_service_error(invalid_enum); return }
    if a2==unsafe { nil } || a3==unsafe { nil } { return }
    unsafe { a2[0]=if a1<=0x8df2 { i32(127) } else { i32(31) }; a2[1]=if a1<=0x8df2 { i32(127) } else { i32(30) }; *a3=if a1<=0x8df2 { i32(23) } else { i32(0) } }
}

@[export: 'vox_gl_uniform1f']
fn metal_service_vox_gl_uniform1f(a0 i32, a1 f32) {
    values:=[a1]!
    metal_service_upload_uniform(a0,1,1,1,13,&values[0],false)
}

@[export: 'vox_gl_uniform2f']
fn metal_service_vox_gl_uniform2f(a0 i32, a1 f32, a2 f32) {
    values:=[a1,a2]!
    metal_service_upload_uniform(a0,2,1,1,13,&values[0],false)
}

@[export: 'vox_gl_uniform3f']
fn metal_service_vox_gl_uniform3f(a0 i32, a1 f32, a2 f32, a3 f32) {
    values:=[a1,a2,a3]!
    metal_service_upload_uniform(a0,3,1,1,13,&values[0],false)
}

@[export: 'vox_gl_uniform4f']
fn metal_service_vox_gl_uniform4f(a0 i32, a1 f32, a2 f32, a3 f32, a4 f32) {
    values:=[a1,a2,a3,a4]!
    metal_service_upload_uniform(a0,4,1,1,13,&values[0],false)
}

@[export: 'vox_gl_uniform1i']
fn metal_service_vox_gl_uniform1i(a0 i32, a1 i32) {
    values:=[a1]!
    metal_service_upload_uniform(a0,1,1,1,7,&values[0],false)
}

@[export: 'vox_gl_uniform2i']
fn metal_service_vox_gl_uniform2i(a0 i32, a1 i32, a2 i32) {
    values:=[a1,a2]!
    metal_service_upload_uniform(a0,2,1,1,7,&values[0],false)
}

@[export: 'vox_gl_uniform3i']
fn metal_service_vox_gl_uniform3i(a0 i32, a1 i32, a2 i32, a3 i32) {
    values:=[a1,a2,a3]!
    metal_service_upload_uniform(a0,3,1,1,7,&values[0],false)
}

@[export: 'vox_gl_uniform4i']
fn metal_service_vox_gl_uniform4i(a0 i32, a1 i32, a2 i32, a3 i32, a4 i32) {
    values:=[a1,a2,a3,a4]!
    metal_service_upload_uniform(a0,4,1,1,7,&values[0],false)
}

@[export: 'vox_gl_uniform1ui']
fn metal_service_vox_gl_uniform1ui(a0 i32, a1 u32) {
    values:=[a1]!
    metal_service_upload_uniform(a0,1,1,1,8,&values[0],false)
}

@[export: 'vox_gl_uniform2ui']
fn metal_service_vox_gl_uniform2ui(a0 i32, a1 u32, a2 u32) {
    values:=[a1,a2]!
    metal_service_upload_uniform(a0,2,1,1,8,&values[0],false)
}

@[export: 'vox_gl_uniform3ui']
fn metal_service_vox_gl_uniform3ui(a0 i32, a1 u32, a2 u32, a3 u32) {
    values:=[a1,a2,a3]!
    metal_service_upload_uniform(a0,3,1,1,8,&values[0],false)
}

@[export: 'vox_gl_uniform4ui']
fn metal_service_vox_gl_uniform4ui(a0 i32, a1 u32, a2 u32, a3 u32, a4 u32) {
    values:=[a1,a2,a3,a4]!
    metal_service_upload_uniform(a0,4,1,1,8,&values[0],false)
}

@[export: 'vox_gl_uniform_floats']
fn metal_service_vox_gl_uniform_floats(a0 i32, a1 i32, a2 i32, a3 &f32) {
    metal_service_upload_uniform(a0,int(a1),1,int(a2),13,a3,false)
}

@[export: 'vox_gl_uniform_ints']
fn metal_service_vox_gl_uniform_ints(a0 i32, a1 i32, a2 i32, a3 &i32) {
    metal_service_upload_uniform(a0,int(a1),1,int(a2),7,a3,false)
}

@[export: 'vox_gl_uniform_uints']
fn metal_service_vox_gl_uniform_uints(a0 i32, a1 i32, a2 i32, a3 &u32) {
    metal_service_upload_uniform(a0,int(a1),1,int(a2),8,a3,false)
}

@[export: 'vox_gl_uniform_matrix']
fn metal_service_vox_gl_uniform_matrix(a0 i32, a1 i32, a2 i32, a3 i32, a4 i32, a5 &f32) {
    metal_service_upload_uniform(a0,int(a2),int(a1),int(a3),13,a5,a4!=0)
}

@[export: 'vox_gl_get_uniform_floats']
fn metal_service_vox_gl_get_uniform_floats(a0 u32, a1 i32, a2 &f32) {
    if a2==unsafe { nil } { return }
    values:=metal_service_uniform_numbers(a0,a1) or { return }
    defer { unsafe { values.free() } }
    for i,value in values { unsafe { a2[i]=f32(value) } }
}

@[export: 'vox_gl_get_uniform_ints']
fn metal_service_vox_gl_get_uniform_ints(a0 u32, a1 i32, a2 &i32) {
    if a2==unsafe { nil } { return }
    values:=metal_service_uniform_numbers(a0,a1) or { return }
    defer { unsafe { values.free() } }
    for i,value in values { unsafe { a2[i]=i32(value) } }
}

@[export: 'vox_gl_get_uniform_uints']
fn metal_service_vox_gl_get_uniform_uints(a0 u32, a1 i32, a2 &u32) {
    if a2==unsafe { nil } { return }
    values:=metal_service_uniform_numbers(a0,a1) or { return }
    defer { unsafe { values.free() } }
    for i,value in values { unsafe { a2[i]=u32(value) } }
}

@[export: 'vox_gl_parameter_shape']
fn metal_service_vox_gl_parameter_shape(a0 u32, a1 i32) i32 {
    return metal_service_parameter_shape(a0,int(a1))
}

@[export: 'vox_gl_parameter']
fn metal_service_vox_gl_parameter(a0 u32, a1 i32, a2 &f64) {
    mut context := metal_service_current()
    if context == unsafe { nil } || a2 == unsafe { nil } { return }
    values := context.parameter(a0) or { return }
    defer { unsafe { values.free() } }
    count := int(a1 % 10)
    if count < 1 || count > values.len { metal_service_error(invalid_enum); return }
    for i in 0..count { unsafe { a2[i] = if a1 / 10 == 3 { f64(values[i] != 0) } else { values[i] } } }
}
