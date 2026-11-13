module webgl

import webgl.metal
import math

fn (mut context MetalServiceContext) blit_source_color() !(&metal.Texture2D,MetalServicePixelLayout) {
    if context.read_framebuffer==1 {
        if context.default_read_buffer==0 { metal_service_error(invalid_operation);return error('Default read buffer is NONE') }
        return context.target.color_attachment()!,MetalServicePixelLayout{format:.rgba8}
    }
    image:=context.read_color_image()!
    if image.samples>1 { return image.gpu.resolved_copy()!,image.layout }
    mut copy:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:image.width,height:image.height,format:image.layout.format})!
    volume:=image.gpu.texture_kind()==.volume_3d
    copy.copy_from(image.gpu,0,if volume { 0 } else { image.layer },metal.TextureRegion{z:if volume { image.layer } else { 0 },width:image.width,height:image.height},0,0,0,0,0) or { copy.close();unsafe { free(copy) };return err }
    return copy,image.layout
}

fn (mut context MetalServiceContext) blit_color(sx0 int,sy0 int,sx1 int,sy1 int,dx0 int,dy0 int,dx1 int,dy1 int,filter u32,view &MetalServiceFramebufferView) ! {
    mut texture,layout:=context.blit_source_color()!
    defer { texture.close();unsafe { free(texture) } }
    if layout.integer && filter!=0x2600 { metal_service_error(invalid_operation);return error('Integer blits require nearest filtering') }
    if context.draw_framebuffer>=16 {
        fbo:=context.bound_framebuffer(framebuffer)!
        for point in fbo.draw_buffers {
            if attachment:=fbo.attachments[point] {
                image:=context.attachment_image(attachment)!
                if image.layout.integer!=layout.integer || (layout.integer && image.layout.signed!=layout.signed) { metal_service_error(invalid_operation);return error('Blit color component types differ') }
            }
        }
    } else if layout.integer { metal_service_error(invalid_operation);return error('Integer blit cannot target normalized drawing buffer') }
    left:=if dx0<dx1 { dx0 } else { dx1 };right:=if dx0>dx1 { dx0 } else { dx1 }
    top:=if dy0<dy1 { dy0 } else { dy1 };bottom:=if dy0>dy1 { dy0 } else { dy1 }
    x0:=if left<0 { 0 } else if left>view.width { view.width } else { left };x1:=if right<0 { 0 } else if right>view.width { view.width } else { right }
    y0:=if top<0 { 0 } else if top>view.height { view.height } else { top };y1:=if bottom<0 { 0 } else if bottom>view.height { view.height } else { bottom }
    if x0>=x1 || y0>=y1 || dx0==dx1 || dy0==dy1 { return }
    source_width,source_height:=texture.size()
    region:=[f32((f64(sx0)+f64(x0-dx0)*f64(sx1-sx0)/f64(dx1-dx0))/f64(source_width)),
        f32((f64(sy0)+f64(y0-dy0)*f64(sy1-sy0)/f64(dy1-dy0))/f64(source_height)),
        f32(f64(x1-x0)*f64(sx1-sx0)/f64(dx1-dx0)/f64(source_width)),
        f32(f64(y1-y0)*f64(sy1-sy0)/f64(dy1-dy0)/f64(source_height))]
    type_:=if !layout.integer { 'vec4' } else if layout.signed { 'ivec4' } else { 'uvec4' }
    sampler_type:=if !layout.integer { 'sampler2D' } else if layout.signed { 'isampler2D' } else { 'usampler2D' }
    mut declarations:='';mut writes:=''
    for index in 0..8 { declarations+='layout(location=${index})out ${type_} c${index};';writes+='c${index}=value;' }
    mut program:=metal.ShaderProgram.compile(context.target,
        '#version 300 es\nuniform vec4 region;out vec2 uv;void main(){vec2 p=vec2(gl_VertexID==1?2.0:0.0,gl_VertexID==2?2.0:0.0);uv=region.xy+p*region.zw;gl_Position=vec4(p*2.0-1.0,0,1);}',
        '#version 300 es\nprecision highp float;precision highp ${sampler_type};uniform ${sampler_type} image;in vec2 uv;${declarations}void main(){if(any(lessThan(uv,vec2(0)))||any(greaterThan(uv,vec2(1))))discard;${type_} value=texture(image,uv);${if layout.components<4 { 'value.a=1;' } else { '' }}${writes}}',3)!
    defer { program.close();unsafe { free(program) } }
    program.uniform_floats('region',region)!
    mut sampler:=metal.Sampler.create(context.target,metal.SamplerOptions{min_filter:if filter==0x2601 { .linear } else { .nearest },mag_filter:if filter==0x2601 { .linear } else { .nearest }})!
    defer { sampler.close();unsafe { free(sampler) } }
    context.target.draw_with_options(program,[],.triangles,0,3,1,metal.DrawOptions{textures:[metal.TextureBinding{name:'image',texture:texture,sampler:sampler}],color_target:view.primary,color_targets:view.colors,colors_configured:view.custom,
        state:metal.RenderState{viewport:metal.Viewport{x:f64(x0),y:f64(y0),width:f64(x1-x0),height:f64(y1-y0)},scissor:if context.scissor_enabled { ?metal.ScissorRect(context.scissor) } else { ?metal.ScissorRect(none) },color_mask:15}})!
}

fn metal_service_depth_value(bytes []u8,pixel int,format metal.TextureFormat,stencil bool) f64 {
    size:=format.pixel_size();offset:=pixel*size
    if stencil { return f64(bytes[offset+if format==.depth_stencil { 4 } else { 0 }]) }
    if format==.depth16 { return f64(u32(bytes[offset])|(u32(bytes[offset+1])<<8))/65535 }
    return metal_service_read_scalar(bytes,offset,gl_float)
}

fn metal_service_write_depth_value(mut bytes []u8,pixel int,format metal.TextureFormat,stencil bool,value f64) {
    size:=format.pixel_size();offset:=pixel*size
    if stencil { bytes[offset+if format==.depth_stencil { 4 } else { 0 }]=u8(value);return }
    metal_service_put_scalar(mut bytes,offset,if format==.depth16 { 2 } else { 4 },if format==.depth16 { u32(value*65535+0.5) } else { math.f32_bits(f32(value)) })
}

fn (mut context MetalServiceContext) blit_aspect(source &MetalServiceFramebufferView,destination &MetalServiceFramebufferView,stencil bool,sx0 int,sy0 int,sx1 int,sy1 int,dx0 int,dy0 int,dx1 int,dy1 int) ! {
    if (stencil && (!source.has_stencil || !destination.has_stencil)) || (!stencil && (!source.has_depth || !destination.has_depth)) { return }
    mut original:=source.depth.texture_view(stencil)!
    defer { original.close();unsafe { free(original) } }
    mut resolved:=unsafe { &metal.Texture2D(nil) }
    if source.samples>1 { resolved=original.resolved_copy()! }
    defer { if resolved!=unsafe { nil } { resolved.close();unsafe { free(resolved) } } }
    from:=if resolved!=unsafe { nil } { resolved } else { original }
    mut to:=destination.depth.texture_view(stencil)!
    defer { to.close();unsafe { free(to) } }
    source_format:=from.pixel_format();destination_format:=to.pixel_format()
    bytes:=from.read_region(0,0,metal.TextureRegion{width:source.width,height:source.height})!
    defer { unsafe { bytes.free() } }
    mut output:=to.read_region(0,0,metal.TextureRegion{width:destination.width,height:destination.height})!
    defer { unsafe { output.free() } }
    if dx0==dx1 || dy0==dy1 { return }
    left:=if dx0<dx1 { dx0 } else { dx1 };right:=if dx0>dx1 { dx0 } else { dx1 }
    top:=if dy0<dy1 { dy0 } else { dy1 };bottom:=if dy0>dy1 { dy0 } else { dy1 }
    for y in 0..destination.height { for x in 0..destination.width {
        if x<left || x>=right || y<top || y>=bottom { continue }
        if context.scissor_enabled && (x<context.scissor.x || x>=context.scissor.x+context.scissor.width || y<context.scissor.y || y>=context.scissor.y+context.scissor.height) { continue }
        sx:=int(math.floor(f64(sx0)+(f64(x-dx0)+0.5)*f64(sx1-sx0)/f64(dx1-dx0)))
        sy:=int(math.floor(f64(sy0)+(f64(y-dy0)+0.5)*f64(sy1-sy0)/f64(dy1-dy0)))
        if sx<0 || sy<0 || sx>=source.width || sy>=source.height { continue }
        value:=metal_service_depth_value(bytes,sy*source.width+sx,source_format,stencil)
        metal_service_write_depth_value(mut output,y*destination.width+x,destination_format,stencil,value)
    } }
    to.write_region(0,0,metal.TextureRegion{width:destination.width,height:destination.height},output)!
}

fn (mut context MetalServiceContext) blit_framebuffer(sx0 int,sy0 int,sx1 int,sy1 int,dx0 int,dy0 int,dx1 int,dy1 int,mask u32,filter u32) {
    if mask & ~u32(0x4500)!=0 { metal_service_error(invalid_value);return }
    if filter !in [u32(0x2600),0x2601] { metal_service_error(invalid_enum);return }
    if filter==0x2601 && mask&0x500!=0 { metal_service_error(invalid_operation);return }
    mut source:=context.framebuffer_view(read_framebuffer) or { context.last_failure=err.msg();return }
    defer { source.close() }
    mut destination:=context.framebuffer_view(draw_framebuffer) or { context.last_failure=err.msg();return }
    defer { destination.close() }
    // GLES 3.0 forbids multisample draw destinations.
    if destination.samples>1 { metal_service_error(invalid_operation);return }
    if source.samples>1 && (sx0!=dx0 || sy0!=dy0 || sx1!=dx1 || sy1!=dy1) { metal_service_error(invalid_operation);return }
    if mask&0x100!=0 && source.has_depth && destination.has_depth && source.depth_format!=destination.depth_format { metal_service_error(invalid_operation);return }
    if mask&0x400!=0 && source.has_stencil && destination.has_stencil && source.stencil_format!=destination.stencil_format { metal_service_error(invalid_operation);return }
    if source.samples>1 && mask&0x4000!=0 {
        image:=context.read_color_image() or { return }
        source_format:=metal_service_attachment_format(image)
        if context.draw_framebuffer==1 {
            if source_format!=0x8058 { metal_service_error(invalid_operation);return }
        } else {
            fbo:=context.bound_framebuffer(draw_framebuffer) or { return }
            for point in fbo.draw_buffers { if attachment:=fbo.attachments[point] { selected:=context.attachment_image(attachment) or { return };if metal_service_attachment_format(selected)!=source_format { metal_service_error(invalid_operation);return } } }
        }
    }
    if mask&0x4000!=0 { context.blit_color(sx0,sy0,sx1,sy1,dx0,dy0,dx1,dy1,filter,&destination) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return } }
    if mask&0x100!=0 { context.blit_aspect(&source,&destination,false,sx0,sy0,sx1,sy1,dx0,dy0,dx1,dy1) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return } }
    if mask&0x400!=0 { context.blit_aspect(&source,&destination,true,sx0,sy0,sx1,sy1,dx0,dy0,dx1,dy1) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return } }
    context.invalidate_draw_textures()
}
