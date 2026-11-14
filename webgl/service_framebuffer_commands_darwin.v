module webgl

fn (mut context MetalServiceContext) set_draw_buffers(count int,values &u32) {
    if count<0 || count>8 { metal_service_error(invalid_value);return }
    if count>0 && values==unsafe { nil } { metal_service_error(invalid_value);return }
    default_:=context.draw_framebuffer==1
    if default_ && count!=1 { metal_service_error(invalid_operation);return }
    mut result:=[]u32{len:count}
    for i in 0..count {
        value:=unsafe { values[i] }
        if value!=0 && (if default_ { value!=back } else { value<color_attachment0 || value>=color_attachment0+8 }) { unsafe { result.free() };metal_service_error(invalid_enum);return }
        if !default_ && value!=0 && value!=color_attachment0+u32(i) { unsafe { result.free() };metal_service_error(invalid_operation);return }
        result[i]=value
    }
    if default_ { context.default_draw_buffer=result[0];unsafe { result.free() };return }
    mut fbo:=context.bound_framebuffer(framebuffer) or { unsafe { result.free() };return }
    unsafe { fbo.draw_buffers.free() }
    fbo.draw_buffers=result
}

fn (mut context MetalServiceContext) set_read_buffer(value u32) {
    if context.read_framebuffer==1 {
        if value !in [back,u32(0)] { metal_service_error(invalid_enum);return }
        context.default_read_buffer=value
        return
    }
    if value!=0 && (value<color_attachment0 || value>=color_attachment0+8) { metal_service_error(invalid_enum);return }
    mut fbo:=context.bound_framebuffer(if context.version==3 { read_framebuffer } else { framebuffer }) or { return }
    fbo.read_buffer=value
}

fn (mut context MetalServiceContext) invalidate_framebuffer(target u32,count int,attachments &u32,x int,y int,width int,height int) {
    if !context.valid_framebuffer_target(target) { metal_service_error(invalid_enum);return }
    if count<0 || width<0 || height<0 { metal_service_error(invalid_value);return }
    if count>0 && attachments==unsafe { nil } { metal_service_error(invalid_value);return }
    default_:=context.framebuffer_name(target)==1
    for i in 0..count {
        point:=unsafe { attachments[i] }
        if (default_ && point !in [u32(0x1800),0x1801,0x1802]) || (!default_ && (!context.valid_attachment(point) || point==depth_stencil_attachment)) { metal_service_error(invalid_enum);return }
    }
    // Invalidation is a discard hint. Keeping initialized storage is permitted
    // and avoids exposing uninitialized bytes through subsequent reads.
}

fn (mut context MetalServiceContext) read_pixels_to_buffer(x int,y int,width int,height int,format u32,type_ u32,offset i64) {
    if width<0 || height<0 { metal_service_error(invalid_value);return }
    object:=context.bound_buffer(pixel_pack_buffer) or { return }
    if offset<0 || object.gpu_buffer==unsafe { nil } || offset>object.gpu_buffer.size() { metal_service_error(invalid_operation);return }
    mut bytes:=object.gpu_buffer.read(int(offset),object.gpu_buffer.size()-int(offset)) or { metal_service_error(invalid_operation);return }
    defer { unsafe { bytes.free() } }
    name:=context.buffers[pixel_pack_buffer];context.buffers[pixel_pack_buffer]=0
    defer { context.buffers[pixel_pack_buffer]=name }
    written:=context.read_pixels(x,y,width,height,format,type_,bytes.len,bytes.data)
    if written>0 { object.gpu_buffer.write(int(offset),bytes) or { metal_service_error(invalid_operation) } }
}
