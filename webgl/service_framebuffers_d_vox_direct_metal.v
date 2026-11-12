module webgl

import webgl.metal
import math

struct MetalServiceAttachment {
    object u32
    kind int
    target u32
    level int
    layer int
}

@[heap]
struct MetalServiceFramebuffer {
mut:
    attachments map[u32]MetalServiceAttachment
    draw_buffers []u32 = [color_attachment0]
    read_buffer u32 = color_attachment0
}

@[heap]
struct MetalServiceRenderbuffer {
mut:
    width int
    height int
    samples int
    internal u32 = 0x8056
    layout MetalServicePixelLayout
    gpu &metal.Texture2D = unsafe { nil }
}

struct MetalServiceRenderImage {
    gpu &metal.Texture2D
    layout MetalServicePixelLayout
    internal u32
    width int
    height int
    layer int
    samples int = 1
    object u32
}

struct MetalServiceFramebufferView {
mut:
    primary &metal.Texture2D = unsafe { nil }
    colors []metal.ColorTargetBinding
    owned []&metal.Texture2D
    depth &metal.DepthStencil = unsafe { nil }
    depth_owned bool
    width int
    height int
    samples int = 1
    has_depth bool
    has_stencil bool
    depth_format u32
    stencil_format u32
    custom bool
}

fn (mut view MetalServiceFramebufferView) close() {
    if view.depth_owned { view.depth.close();unsafe { free(view.depth) } }
    for mut texture in view.owned { texture.close();unsafe { free(texture) } }
    unsafe { view.owned.free();view.colors.free() }
}

fn (context &MetalServiceContext) valid_framebuffer_target(target u32) bool {
    return target==framebuffer || (context.version==3 && target in [draw_framebuffer,read_framebuffer])
}

fn (context &MetalServiceContext) framebuffer_name(target u32) u32 {
    return if target==read_framebuffer { context.read_framebuffer } else { context.draw_framebuffer }
}

fn (mut context MetalServiceContext) bound_framebuffer(target u32) !&MetalServiceFramebuffer {
    if !context.valid_framebuffer_target(target) { metal_service_error(invalid_enum);return error('Invalid framebuffer target') }
    name:=context.framebuffer_name(target)
    if name<16 { metal_service_error(invalid_operation);return error('Default framebuffer cannot be modified') }
    object:=context.objects[name] or { metal_service_error(invalid_operation);return error('No framebuffer bound') }
    if object.fbo==unsafe { nil } { metal_service_error(invalid_operation);return error('Framebuffer is not initialized') }
    return object.fbo
}

fn (mut context MetalServiceContext) bind_framebuffer(target u32,name u32) {
    if !context.valid_framebuffer_target(target) { metal_service_error(invalid_enum);return }
    if name>1 {
        mut object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=1 || object.deleted { metal_service_error(invalid_operation);return }
        if object.fbo==unsafe { nil } { object.fbo=&MetalServiceFramebuffer{} }
        object.created=true
    }
    if target!=read_framebuffer { context.draw_framebuffer=name }
    if target!=draw_framebuffer { context.read_framebuffer=name }
}

fn (context &MetalServiceContext) attachment_image(attachment MetalServiceAttachment) !MetalServiceRenderImage {
    object:=context.objects[attachment.object] or { return error('Missing framebuffer object') }
    if attachment.kind==2 {
        rbo:=object.rbo
        if rbo==unsafe { nil } || rbo.gpu==unsafe { nil } { return error('Renderbuffer is not allocated') }
        return MetalServiceRenderImage{gpu:rbo.gpu,width:rbo.width,height:rbo.height,layout:rbo.layout,internal:rbo.internal,samples:if rbo.samples>0 { rbo.samples } else { 1 },object:attachment.object}
    }
    if object.texture==unsafe { nil } { return error('Texture has no images') }
    image:=object.texture.images[metal_service_image_key(attachment.target,attachment.level)] or { return error('Texture image is not defined') }
    if image.gpu==unsafe { nil } || attachment.layer<0 || attachment.layer>=image.depth { return error('Texture layer is outside image') }
    return MetalServiceRenderImage{gpu:image.gpu,width:image.width,height:image.height,layout:image.layout,internal:image.internal,layer:attachment.layer,object:attachment.object}
}

fn (mut context MetalServiceContext) framebuffer_status(target u32) u32 {
    if !context.valid_framebuffer_target(target) { metal_service_error(invalid_enum);return 0 }
    name:=context.framebuffer_name(target)
    if name==1 { return if context.surface { u32(0x8cd5) } else { u32(0x8219) } }
    if name==0 { return 0x8219 }
    fbo:=context.bound_framebuffer(target) or { return 0x8cd7 }
    if fbo.attachments.len==0 { return 0x8cd7 }
    mut width:=0;mut height:=0;mut samples:=-1
    for point,attachment in fbo.attachments {
        image:=context.attachment_image(attachment) or { return 0x8cd6 }
        if image.width<1 || image.height<1 { return 0x8cd6 }
        if point>=color_attachment0 && point<color_attachment0+8 && image.layout.format in [.depth16,.depth32,.depth_stencil,.stencil8] { return 0x8cd6 }
        if point==depth_attachment && image.layout.format !in [.depth16,.depth32,.depth_stencil] { return 0x8cd6 }
        if point==stencil_attachment && image.layout.format !in [.stencil8,.depth_stencil] { return 0x8cd6 }
        if width==0 { width=image.width;height=image.height;samples=image.samples }
        if width!=image.width || height!=image.height { return 0x8cd9 }
        if samples!=image.samples { return 0x8d56 }
    }
    return 0x8cd5
}

fn (context &MetalServiceContext) valid_attachment(point u32) bool {
    return point in [depth_attachment,stencil_attachment,depth_stencil_attachment] || (point>=color_attachment0 && point<color_attachment0+8)
}

fn (mut context MetalServiceContext) attach_texture(target u32,point u32,texture_target u32,name u32,level int,layer int,layered bool) {
    mut fbo:=context.bound_framebuffer(target) or { return }
    if !context.valid_attachment(point) { metal_service_error(invalid_enum);return }
    if level<0 || level>14 || layer<0 || layer>=2048 { metal_service_error(invalid_value);return }
    mut selected_target:=texture_target
    if name!=0 {
        object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=3 || object.deleted || object.texture==unsafe { nil } { metal_service_error(invalid_operation);return }
        if layered {
            if object.texture.target !in [texture_3d,texture_2d_array] { metal_service_error(invalid_operation);return }
            selected_target=object.texture.target
        } else if (texture_target!=texture_2d && (texture_target<0x8515 || texture_target>0x851a)) || metal_service_texture_target(texture_target)!=object.texture.target { metal_service_error(invalid_operation);return }
    }
    points:=if point==depth_stencil_attachment { [depth_attachment,stencil_attachment] } else { [point] }
    defer { unsafe { points.free() } }
    for selected in points {
        if name==0 { fbo.attachments.delete(selected) }
        else { fbo.attachments[selected]=MetalServiceAttachment{object:name,kind:3,target:selected_target,level:level,layer:layer} }
    }
}

fn (mut context MetalServiceContext) attach_renderbuffer(target u32,point u32,renderbuffer_target u32,name u32) {
    mut fbo:=context.bound_framebuffer(target) or { return }
    if renderbuffer_target!=renderbuffer || !context.valid_attachment(point) { metal_service_error(invalid_enum);return }
    if name!=0 {
        object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=2 || object.deleted || object.rbo==unsafe { nil } { metal_service_error(invalid_operation);return }
    }
    points:=if point==depth_stencil_attachment { [depth_attachment,stencil_attachment] } else { [point] }
    defer { unsafe { points.free() } }
    for selected in points {
        if name==0 { fbo.attachments.delete(selected) }
        else { fbo.attachments[selected]=MetalServiceAttachment{object:name,kind:2} }
    }
}

fn (mut context MetalServiceContext) bind_renderbuffer(target u32,name u32) {
    if target!=renderbuffer { metal_service_error(invalid_enum);return }
    if name>2 {
        mut object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=2 || object.deleted { metal_service_error(invalid_operation);return }
        if object.rbo==unsafe { nil } { object.rbo=&MetalServiceRenderbuffer{} }
        object.created=true
    } else if name==1 { metal_service_error(invalid_operation);return }
    context.renderbuffer=name
}

fn (mut context MetalServiceContext) renderbuffer_storage(target u32,samples int,internal u32,width int,height int) {
    if target!=renderbuffer { metal_service_error(invalid_enum);return }
    if samples<0 || width<0 || height<0 || width>16384 || height>16384 { metal_service_error(invalid_value);return }
    layout:=metal_service_layout(internal) or { metal_service_error(invalid_enum);return }
    mut object:=context.objects[context.renderbuffer] or { metal_service_error(invalid_operation);return }
    if object.rbo==unsafe { nil } { metal_service_error(invalid_operation);return }
    mut count:=1
    if samples>0 {
        counts:=context.target.sample_counts()
        defer { unsafe { counts.free() } }
        mut selected:=0
        for value in counts { if value>=samples && (selected==0 || value<selected) { selected=value } }
        if selected==0 { metal_service_error(invalid_operation);return }
        count=selected
    }
    mut gpu:=unsafe { &metal.Texture2D(nil) }
    if width>0 && height>0 {
        gpu=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:width,height:height,samples:count,format:layout.format}) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
    }
    if object.rbo.gpu!=unsafe { nil } { object.rbo.gpu.close();unsafe { free(object.rbo.gpu) } }
    object.rbo.gpu=gpu;object.rbo.width=width;object.rbo.height=height;object.rbo.layout=layout;object.rbo.internal=internal;object.rbo.samples=if samples==0 { 0 } else { count }
}

fn (mut context MetalServiceContext) framebuffer_view(target u32) !MetalServiceFramebufferView {
    if context.framebuffer_status(target)!=0x8cd5 { metal_service_error(invalid_framebuffer_operation);return error('Framebuffer is incomplete') }
    if context.framebuffer_name(target)==1 {
        return MetalServiceFramebufferView{width:context.width,height:context.height,depth:context.depth,has_depth:context.has_depth,has_stencil:context.has_stencil,depth_format:if context.has_stencil { u32(0x88f0) } else { u32(0x81a6) },stencil_format:if context.has_depth { u32(0x88f0) } else { u32(0x8d48) }}
    }
    fbo:=context.bound_framebuffer(target)!
    mut result:=MetalServiceFramebufferView{custom:true}
    for index,point in fbo.draw_buffers {
        if point==0 { continue }
        attachment:=fbo.attachments[point] or { continue }
        image:=context.attachment_image(attachment)!
        view:=image.gpu.attachment(0,image.layer)!
        result.owned<<view
        result.colors<<metal.ColorTargetBinding{index:index,texture:view}
        if result.primary==unsafe { nil } { result.primary=view;result.width=image.width;result.height=image.height;result.samples=image.samples }
    }
    mut depth_view:=unsafe { &metal.Texture2D(nil) };mut stencil_view:=unsafe { &metal.Texture2D(nil) }
    for point in [depth_attachment,stencil_attachment] {
        if attachment:=fbo.attachments[point] {
            image:=context.attachment_image(attachment)!
            view:=image.gpu.attachment(0,image.layer)!
            result.owned<<view
            if point==depth_attachment { depth_view=view;result.has_depth=true;result.depth_format=metal_service_attachment_format(image) } else { stencil_view=view;result.has_stencil=true;result.stencil_format=metal_service_attachment_format(image) }
            if result.width==0 { result.width=image.width;result.height=image.height;result.samples=image.samples }
        }
    }
    if depth_view!=unsafe { nil } || stencil_view!=unsafe { nil } {
        result.depth=metal.DepthStencil.from_attachments(context.target,depth_view,stencil_view)!
        result.depth_owned=true
    }
    if result.primary==unsafe { nil } {
        if result.width==0 { for _,attachment in fbo.attachments { image:=context.attachment_image(attachment)!;result.width=image.width;result.height=image.height;result.samples=image.samples;break } }
        carrier:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:result.width,height:result.height,samples:result.samples})!
        result.owned<<carrier;result.primary=carrier
        result.colors<<metal.ColorTargetBinding{index:0,texture:carrier}
    }
    return result
}

fn (mut context MetalServiceContext) read_color_image() !MetalServiceRenderImage {
    target:=if context.version==3 { read_framebuffer } else { framebuffer }
    if context.framebuffer_status(target)!=0x8cd5 { metal_service_error(invalid_framebuffer_operation);return error('Read framebuffer is incomplete') }
    fbo:=context.bound_framebuffer(target)!
    attachment:=fbo.attachments[fbo.read_buffer] or { metal_service_error(invalid_operation);return error('Read buffer has no color image') }
    return context.attachment_image(attachment)
}

fn (mut context MetalServiceContext) read_color_pixels() !([]u8,int,int) {
    target:=if context.version==3 { read_framebuffer } else { framebuffer }
    if context.framebuffer_status(target)!=0x8cd5 { metal_service_error(invalid_framebuffer_operation);return error('Read framebuffer is incomplete') }
    if context.framebuffer_name(target)==1 { if context.default_read_buffer==0 { metal_service_error(invalid_operation);return error('Default read buffer is NONE') };return context.target.read_pixels()!,context.width,context.height }
    image:=context.read_color_image()!
    if image.samples>1 { metal_service_error(invalid_operation);return error('Cannot read a multisample framebuffer') }
    if image.layout.integer { metal_service_error(invalid_operation);return error('Integer framebuffer requires integer readback') }
    volume:=image.gpu.texture_kind()==.volume_3d
    bytes:=image.gpu.read_region(0,if volume { 0 } else { image.layer },metal.TextureRegion{z:if volume { image.layer } else { 0 },width:image.width,height:image.height})!
    if image.layout.format in [.rgba8,.srgba8] && image.layout.components==4 { return bytes,image.width,image.height }
    defer { unsafe { bytes.free() } }
    mut result:=[]u8{len:image.width*image.height*4}
    size:=image.layout.format.pixel_size();channels:=metal_service_native_channels(image.layout.format);scalar:=size/channels
    for pixel in 0..image.width*image.height {
        for component in 0..4 {
            mut value:=if component==3 { f64(1) } else { f64(0) }
            if component<channels && (component!=3 || image.layout.components==4) {
                offset:=pixel*size+component*scalar
                value=if image.layout.floating { metal_service_read_scalar(bytes,offset,if scalar==2 { half_float } else { gl_float }) }
                    else if image.layout.signed { metal_service_read_scalar(bytes,offset,gl_byte)/127 }
                    else { f64(bytes[offset])/255 }
            }
            result[pixel*4+component]=u8(if value!=value || value<0 { f64(0) } else if value>1 { f64(255) } else { value*255+0.5 })
        }
    }
    return result,image.width,image.height
}

fn (mut context MetalServiceContext) renderbuffer_parameter(target u32,pname u32) i32 {
    if target!=renderbuffer { metal_service_error(invalid_enum);return 0 }
    if context.renderbuffer==2 {
        return match pname {
            0x8d42 { i32(context.width) } 0x8d43 { i32(context.height) }
            0x8d44 { if context.has_stencil && context.has_depth { i32(0x88f0) } else if context.has_stencil { i32(0x8d48) } else { i32(0x81a6) } }
            0x8d54 { if context.has_depth { i32(24) } else { i32(0) } } 0x8d55 { if context.has_stencil { i32(8) } else { i32(0) } }
            0x8d50,0x8d51,0x8d52,0x8d53,0x8cab { i32(0) }
            else { metal_service_error(invalid_enum);i32(0) }
        }
    }
    object:=context.objects[context.renderbuffer] or { metal_service_error(invalid_operation);return 0 }
    if object.rbo==unsafe { nil } { metal_service_error(invalid_operation);return 0 }
    rbo:=object.rbo
    return match pname {
        0x8d42 { i32(rbo.width) } 0x8d43 { i32(rbo.height) } 0x8d44 { i32(rbo.internal) } 0x8cab { i32(rbo.samples) }
        0x8d54 { if rbo.layout.format==.depth16 { i32(16) } else if rbo.layout.format in [.depth32,.depth_stencil] { i32(if rbo.internal==0x81a6 || rbo.internal==0x88f0 { 24 } else { 32 }) } else { i32(0) } }
        0x8d55 { if rbo.layout.format in [.stencil8,.depth_stencil] { i32(8) } else { i32(0) } }
        0x8d50,0x8d51,0x8d52,0x8d53 {
            channel:=int(pname-0x8d50)
            if rbo.layout.format in [.depth16,.depth32,.depth_stencil,.stencil8] || channel>=rbo.layout.components { return 0 }
            if rbo.internal==0x8056 { return 4 }
            if rbo.internal==0x8057 { return if channel==3 { i32(1) } else { i32(5) } }
            if rbo.internal==0x8d62 { return if channel==1 { i32(6) } else { i32(5) } }
            i32(rbo.layout.format.pixel_size()*8/metal_service_native_channels(rbo.layout.format))
        }
        else { metal_service_error(invalid_enum);i32(0) }
    }
}

fn (mut context MetalServiceContext) read_color_data(format u32,type_ u32) !([]u8,int,int,int) {
    if format==rgba && type_==unsigned_byte {
        bytes,width,height:=context.read_color_pixels()!
        return bytes,width,height,4
    }
    if format !in [rgba,rgba_integer] || type_ !in [gl_float,gl_int,unsigned_int] { metal_service_error(invalid_enum);return error('Unsupported read format/type') }
    if context.read_framebuffer<16 { metal_service_error(invalid_operation);return error('Drawing buffer does not have the requested read type') }
    image:=context.read_color_image()!
    if image.samples>1 { metal_service_error(invalid_operation);return error('Multisample framebuffer must be resolved') }
    if (format==rgba_integer && (!image.layout.integer || (type_==gl_int)!=image.layout.signed || type_==gl_float))
        || (format==rgba && (!image.layout.floating || type_!=gl_float)) { metal_service_error(invalid_operation);return error('Read type does not match color attachment') }
    volume:=image.gpu.texture_kind()==.volume_3d
    bytes:=image.gpu.read_region(0,if volume { 0 } else { image.layer },metal.TextureRegion{z:if volume { image.layer } else { 0 },width:image.width,height:image.height})!
    defer { unsafe { bytes.free() } }
    mut result:=[]u8{len:image.width*image.height*16}
    size:=image.layout.format.pixel_size();channels:=metal_service_native_channels(image.layout.format);scalar:=size/channels
    for pixel in 0..image.width*image.height {
        for component in 0..4 {
            mut value:=if component==3 { f64(1) } else { f64(0) }
            if component<channels && (component!=3 || image.layout.components==4) {
                native_type:=if image.layout.floating { if scalar==2 { half_float } else { gl_float } }
                    else if image.layout.signed { if scalar==1 { gl_byte } else if scalar==2 { gl_short } else { gl_int } }
                    else { if scalar==1 { unsigned_byte } else if scalar==2 { unsigned_short } else { unsigned_int } }
                value=metal_service_read_scalar(bytes,pixel*size+component*scalar,native_type)
            }
            encoded:=if type_==gl_float { math.f32_bits(f32(value)) } else { u32(i64(value)) }
            metal_service_put_scalar(mut result,pixel*16+component*4,4,encoded)
        }
    }
    return result,image.width,image.height,16
}

fn (mut context MetalServiceContext) detach_deleted_attachment(name u32,kind int) {
    for framebuffer_name in [context.draw_framebuffer,context.read_framebuffer] {
        if framebuffer_name<16 { continue }
        if mut object:=context.objects[framebuffer_name] {
            if object.fbo==unsafe { nil } { continue }
            mut points:=[]u32{}
            for point,attachment in object.fbo.attachments { if attachment.object==name && attachment.kind==kind { points<<point } }
            for point in points { object.fbo.attachments.delete(point) }
            unsafe { points.free() }
        }
    }
}

fn metal_service_attachment_format(image MetalServiceRenderImage) u32 {
    return match image.internal {
        0x1908 { u32(0x8058) } 0x1907 { u32(0x8051) }
        0x1902 { if image.layout.format==.depth16 { u32(0x81a5) } else { u32(0x81a6) } }
        0x84f9 { u32(0x88f0) }
        else { image.internal }
    }
}
