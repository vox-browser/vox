module webgl

// Backend-neutral inspection for conformance tests. Source wrapper records may
// intentionally retain deleted handles; these queries inspect the GPU service.
@[export: 'vox_gl_is_sync']
fn metal_service_vox_gl_is_sync(handle voidptr) i32 {
    context:=metal_service_current()
    if context==unsafe { nil } { return 0 }
    if fence:=context.fences[handle] { return i32(!fence.deleted) }
    return 0
}

@[export: 'vox_gl_attached_shaders']
fn metal_service_vox_gl_attached_shaders(name u32,capacity i32,count &i32,shaders &u32) {
    if capacity<0 { metal_service_error(invalid_value);return }
    program:=metal_service_current().object(name,10) or { return }
    length:=if int(capacity)<program.attached.len { int(capacity) } else { program.attached.len }
    unsafe { if count!=nil { *count=i32(length) };if shaders!=nil { for i in 0..length { shaders[i]=program.attached[i] } } }
}

@[export: 'vox_gl_query_target_parameter']
fn metal_service_vox_gl_query_target_parameter(target u32,pname u32) i32 {
    if !metal_service_valid_query(target) || pname!=current_query { metal_service_error(invalid_enum);return 0 }
    return i32(metal_service_current().active_queries[target])
}

@[export: 'vox_gl_framebuffer_attachment_parameter']
fn metal_service_vox_gl_framebuffer_attachment_parameter(target u32,point u32,pname u32) i32 {
    mut context:=metal_service_current()
    fbo:=context.bound_framebuffer(target) or { return 0 }
    if !(point>=color_attachment0 && point<color_attachment0+8) && point !in [depth_attachment,stencil_attachment,u32(0x821a)] { metal_service_error(invalid_enum);return 0 }
    attachment:=fbo.attachments[point] or {
        if pname in [framebuffer_attachment_object_type,framebuffer_attachment_object_name] { return 0 }
        metal_service_error(invalid_operation);return 0
    }
    match pname {
        framebuffer_attachment_object_type { return i32(if attachment.kind==2 { renderbuffer } else { gl_texture }) }
        framebuffer_attachment_object_name { return i32(attachment.object) }
        framebuffer_attachment_texture_level { if attachment.kind==3 { return i32(attachment.level) } }
        framebuffer_attachment_texture_cube_map_face { if attachment.kind==3 { return i32(if attachment.target>=0x8515 && attachment.target<=0x851a { attachment.target } else { 0 }) } }
        u32(0x8cd4) { if attachment.kind==3 { return i32(attachment.layer) } }
        else { metal_service_error(invalid_enum);return 0 }
    }
    metal_service_error(invalid_enum)
    return 0
}
