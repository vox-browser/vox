module webgl

import webgl.metal

fn blit_framebuffer_fixture(mut context WebGLRenderingContext,width int,height int) &WebGLFramebuffer {
    fbo:=context.create_framebuffer();context.bind_framebuffer(framebuffer,fbo)
    texture:=context.create_texture();context.bind_texture(texture_2d,texture)
    context.tex_storage2d(texture_2d,1,0x8058,width,height)
    context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,texture,0)
    storage:=context.create_renderbuffer();context.bind_renderbuffer(renderbuffer,storage)
    context.renderbuffer_storage(renderbuffer,0x88f0,width,height)
    context.framebuffer_renderbuffer(framebuffer,depth_stencil_attachment,renderbuffer,storage)
    assert context.check_framebuffer_status(framebuffer)==0x8cd5
    return fbo
}

fn blit_read_depth_stencil() ![]u8 {
    mut context:=metal_service_current()
    mut view:=context.framebuffer_view(draw_framebuffer)!
    defer { view.close() }
    mut texture:=view.depth.texture_view(false)!
    defer { texture.close() }
    return texture.read_region(0,0,metal.TextureRegion{width:view.width,height:view.height})
}

fn test_direct_metal_depth_stencil_blits_preserve_other_aspects_scale_and_apply_scissor() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    source:=blit_framebuffer_fixture(mut context,2,2)
    context.clear_depth(0.25);context.clear_stencil(37);context.clear(0x500)
    destination:=blit_framebuffer_fixture(mut context,4,4)
    context.clear_depth(0.75);context.clear_stencil(7);context.clear(0x500)
    context.bind_framebuffer(read_framebuffer,source);context.bind_framebuffer(draw_framebuffer,destination)
    context.blit_framebuffer(0,0,2,2,0,0,4,4,0x100,0x2600)
    bytes:=blit_read_depth_stencil()!
    for offset:=0;offset<bytes.len;offset+=8 { assert bytes[offset..offset+8]==[u8(0),0,128,62,7,0,0,0] }
    context.blit_framebuffer(0,0,2,2,0,0,4,4,0x400,0x2600)
    both:=blit_read_depth_stencil()!
    for offset:=0;offset<both.len;offset+=8 { assert both[offset..offset+8]==[u8(0),0,128,62,37,0,0,0] }
    context.clear_depth(0.75);context.clear(0x100)
    context.enable(scissor_test);context.scissor(1,1,1,1)
    context.blit_framebuffer(0,0,2,2,0,0,4,4,0x100,0x2600)
    clipped:=blit_read_depth_stencil()!
    for pixel in 0..16 {
        offset:=pixel*8
        assert clipped[offset..offset+8]==if pixel==5 { [u8(0),0,128,62,37,0,0,0] } else { [u8(0),0,64,63,37,0,0,0] }
    }
    assert context.get_error()==no_error,metal_service_current().last_failure
    context.blit_framebuffer(0,0,2,2,0,0,4,4,0x100,0x2601)
    assert context.get_error()==invalid_operation
    assert metal_service_current().unsupported.len==0
}

fn test_direct_metal_multisample_blits_reject_scaled_offset_and_multisample_destinations() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    source:=context.create_framebuffer();context.bind_framebuffer(framebuffer,source)
    storage:=context.create_renderbuffer();context.bind_renderbuffer(renderbuffer,storage)
    count:=int(context.get_internalformat_parameter(renderbuffer,0x8058,samples).integers[0])
    assert count>1
    context.renderbuffer_storage_multisample(renderbuffer,count,0x8058,2,2)
    context.framebuffer_renderbuffer(framebuffer,color_attachment0,renderbuffer,storage)
    context.clear_color(1,0,0,1);context.clear(0x4000)
    destination:=blit_framebuffer_fixture(mut context,2,2)
    context.bind_framebuffer(read_framebuffer,source);context.bind_framebuffer(draw_framebuffer,destination)
    context.blit_framebuffer(0,0,2,2,1,0,3,2,0x4000,0x2600)
    assert context.get_error()==invalid_operation
    context.bind_framebuffer(draw_framebuffer,source)
    context.blit_framebuffer(0,0,2,2,0,0,2,2,0x4000,0x2600)
    assert context.get_error()==invalid_operation
    context.bind_framebuffer(draw_framebuffer,destination)
    context.blit_framebuffer(0,0,2,2,0,0,2,2,0x4000,0x2600)
    context.bind_framebuffer(read_framebuffer,destination)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    assert context.get_error()==no_error,metal_service_current().last_failure
}
