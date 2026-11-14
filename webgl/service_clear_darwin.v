module webgl

import webgl.metal

fn (mut context MetalServiceContext) clear_color_layout(index int) ?MetalServicePixelLayout {
    if context.draw_framebuffer==1 {
        if context.default_draw_buffer==0 { return none }
        return MetalServicePixelLayout{format:.rgba8}
    }
    fbo:=context.bound_framebuffer(framebuffer) or { return none }
    if index>=fbo.draw_buffers.len || fbo.draw_buffers[index]==0 { return none }
    attachment:=fbo.attachments[fbo.draw_buffers[index]] or { return none }
    image:=context.attachment_image(attachment) or { return none }
    return image.layout
}

fn (mut context MetalServiceContext) clear_buffer(buffer u32,index int,kind u32,values voidptr,depth_value f32,stencil_value i32) {
    allowed:=if kind==13 { buffer in [u32(0x1800),0x1801] } else if kind==7 { buffer in [u32(0x1800),0x1802] } else if kind==8 { buffer==0x1800 } else { buffer==0x84f9 }
    if !allowed { metal_service_error(invalid_enum);return }
    if index<0 || index>=8 || (buffer!=0x1800 && index!=0) || (context.draw_framebuffer==1 && index>0) { metal_service_error(invalid_value);return }
    if context.framebuffer_status(framebuffer)!=0x8cd5 { metal_service_error(invalid_framebuffer_operation);return }
    if buffer==0x1800 {
        layout:=context.clear_color_layout(index) or { return }
        if layout.integer!=(kind in [u32(7),8]) || (layout.integer && layout.signed!=(kind==7)) { metal_service_error(invalid_operation);return }
    }
    color:=context.clear_color;depth:=context.clear_depth;stencil:=context.clear_stencil
    defer { context.clear_color=color;context.clear_depth=depth;context.clear_stencil=stencil }
    mask:=if buffer==0x1800 { u32(0x4000) } else if buffer==0x1801 { u32(0x100) } else if buffer==0x1802 { u32(0x400) } else { u32(0x500) }
    if buffer==0x84f9 { context.clear_depth=metal_service_unit(depth_value);context.clear_stencil=u32(stencil_value)&255 }
    else {
        if values==unsafe { nil } { metal_service_error(invalid_value);return }
        if buffer==0x1800 && kind==13 { layout:=context.clear_color_layout(index) or { return };for i in 0..4 { value:=unsafe { (&f32(values))[i] };context.clear_color[i]=if layout.floating { value } else { metal_service_unit(value) } } }
        if buffer==0x1801 { context.clear_depth=metal_service_unit(unsafe { *&f32(values) }) }
        if buffer==0x1802 { context.clear_stencil=unsafe { u32(*&i32(values)) }&255 }
    }
    if buffer!=0x1800 || kind==13 {
        context.clear_pixels_at(mask,if buffer==0x1800 { index } else { -1 }) or { context.last_failure=err.msg();metal_service_error(invalid_operation) }
        return
    }
    mut view:=context.framebuffer_view(framebuffer) or { return }
    defer { view.close() }
    mut selected:=[]metal.ColorTargetBinding{}
    defer { unsafe { selected.free() } }
    for binding in view.colors { if binding.index==index { selected<<binding } }
    if kind !in context.clear_integer_programs {
        mut declarations:='';mut writes:=''
        type_:=if kind==7 { 'ivec4' } else { 'uvec4' }
        for slot in 0..8 { declarations+='layout(location=${slot})out ${type_} c${slot};';writes+='c${slot}=value;' }
        program:=metal.ShaderProgram.compile(context.target,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
            '#version 300 es\nprecision highp float;uniform ${type_} value;${declarations}void main(){${writes}}',3) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
        context.clear_integer_programs[kind]=program
    }
    mut program:=context.clear_integer_programs[kind] or { return }
    if kind==7 {
        mut integers:=[]i32{len:4}
        defer { unsafe { integers.free() } }
        unsafe { vmemcpy(integers.data,values,16) }
        program.uniform_ints('value',integers) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
    } else {
        mut integers:=[]u32{len:4}
        defer { unsafe { integers.free() } }
        unsafe { vmemcpy(integers.data,values,16) }
        program.uniform_uints('value',integers) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
    }
    context.target.draw_with_options(program,[],.triangles,0,3,1,metal.DrawOptions{color_target:view.primary,color_targets:selected,colors_configured:true,state:metal.RenderState{color_mask:context.color_mask,scissor:if context.scissor_enabled { ?metal.ScissorRect(context.scissor) } else { ?metal.ScissorRect(none) }}}) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
    context.invalidate_draw_textures()
}
