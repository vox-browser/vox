module webgl

import webgl.metal

fn metal_service_compare(value f64) metal.CompareFunction {
    return unsafe { metal.CompareFunction(int(value)-0x200) }
}

fn metal_service_stencil_operation(value f64) metal.StencilOperation {
    return match int(value) { 0 { .zero } 0x1e01 { .replace } 0x1e02 { .increment_clamp } 0x1e03 { .decrement_clamp } 0x150a { .invert } 0x8507 { .increment_wrap } 0x8508 { .decrement_wrap } else { .keep } }
}

fn metal_service_blend_operation(value f64) metal.BlendOperation {
    return match int(value) { 0x800a { .subtract } 0x800b { .reverse_subtract } 0x8007 { .min } 0x8008 { .max } else { .add } }
}

fn metal_service_blend_factor(value f64) metal.BlendFactor {
    return match int(value) { 1 { .one } 0x300 { .source_color } 0x301 { .one_minus_source_color } 0x302 { .source_alpha } 0x303 { .one_minus_source_alpha } 0x304 { .destination_alpha } 0x305 { .one_minus_destination_alpha } 0x306 { .destination_color } 0x307 { .one_minus_destination_color } 0x308 { .source_alpha_saturated } 0x8001 { .constant_color } 0x8002 { .one_minus_constant_color } 0x8003 { .constant_alpha } 0x8004 { .one_minus_constant_alpha } else { .zero } }
}

fn (context &MetalServiceContext) stencil_face(back_face bool) metal.StencilFace {
    p:=context.parameters
    return metal.StencilFace{
        compare:metal_service_compare(p[if back_face { stencil_back_func } else { stencil_func }][0])
        fail:metal_service_stencil_operation(p[if back_face { stencil_back_fail } else { stencil_fail }][0])
        depth_fail:metal_service_stencil_operation(p[if back_face { stencil_back_pass_depth_fail } else { stencil_pass_depth_fail }][0])
        pass:metal_service_stencil_operation(p[if back_face { stencil_back_pass_depth_pass } else { stencil_pass_depth_pass }][0])
        reference:u32(p[if back_face { stencil_back_ref } else { stencil_ref }][0])
        read_mask:u32(i32(p[if back_face { stencil_back_value_mask } else { stencil_value_mask }][0]))
        write_mask:u32(i32(p[if back_face { stencil_back_writemask } else { stencil_writemask }][0]))
    }
}

fn (context &MetalServiceContext) render_state(mode u32,has_depth bool,has_stencil bool) metal.RenderState {
    p:=context.parameters
    discard:=context.enabled[0x8c89] || (mode>=4 && context.enabled[cull_face] && u32(p[cull_face_mode][0])==front_and_back)
    scissor:=if discard { ?metal.ScissorRect(metal.ScissorRect{}) } else if context.scissor_enabled { ?metal.ScissorRect(context.scissor) } else { ?metal.ScissorRect(none) }
    return metal.RenderState{
        viewport:metal.Viewport{...context.viewport,near_depth:p[depth_range][0],far_depth:p[depth_range][1]}
        scissor:scissor
        color_mask:context.color_mask
        blend:context.enabled[blend]
        rgb_operation:metal_service_blend_operation(p[blend_equation_rgb][0])
        alpha_operation:metal_service_blend_operation(p[blend_equation_alpha][0])
        source_rgb:metal_service_blend_factor(p[blend_src_rgb][0])
        destination_rgb:metal_service_blend_factor(p[blend_dst_rgb][0])
        source_alpha:metal_service_blend_factor(p[blend_src_alpha][0])
        destination_alpha:metal_service_blend_factor(p[blend_dst_alpha][0])
        blend_color:[f32(p[blend_color][0]),f32(p[blend_color][1]),f32(p[blend_color][2]),f32(p[blend_color][3])]!
        cull:if !context.enabled[cull_face] { .none } else if u32(p[cull_face_mode][0])==front { .front } else { .back }
        front_ccw:u32(p[front_face][0])==ccw
        depth_test:has_depth && context.enabled[depth_test]
        depth_write:context.depth_mask
        depth_compare:metal_service_compare(p[depth_func][0])
        stencil_test:has_stencil && context.enabled[stencil_test]
        front_stencil:context.stencil_face(false)
        back_stencil:context.stencil_face(true)
        depth_bias:if context.enabled[polygon_offset_fill] { f32(p[polygon_offset_units][0]) } else { f32(0) }
        depth_slope:if context.enabled[polygon_offset_fill] { f32(p[polygon_offset_factor][0]) } else { f32(0) }
    }
}

fn metal_service_vertex_format(type_ u32) !metal.VertexFormat {
    return match type_ { 0x1400 { .int8 } 0x1401 { .uint8 } 0x1402 { .int16 } 0x1403 { .uint16 } 0x1404 { .int32 } 0x1405 { .uint32 } 0x1406 { .float32 } 0x140b,0x8d61 { .float16 } else { return error('Packed vertex formats are not implemented') } }
}

fn (mut context MetalServiceContext) draw(mode u32,first int,count int,instances int,indexed bool,type_ u32,offset i64,range_end ?u32) {
    if mode>6 { metal_service_error(invalid_enum); return }
    if first<0 || count<0 || instances<0 { metal_service_error(invalid_value); return }
    if indexed && type_ !in [unsigned_byte,unsigned_short,unsigned_int] { metal_service_error(invalid_enum); return }
    index_width:=if type_==unsigned_byte { 1 } else if type_==unsigned_short { 2 } else { 4 }
    if indexed && (offset<0 || offset%i64(index_width)!=0) { metal_service_error(invalid_operation); return }
    object:=context.objects[context.current_program] or { metal_service_error(invalid_operation); return }
    if !object.linked || object.program==unsafe { nil } { metal_service_error(invalid_operation); return }
    mut framebuffer_view:=context.framebuffer_view(framebuffer) or { context.last_failure=err.msg();return }
    defer { framebuffer_view.close() }
    mut vao:=context.vao()
    mut maximum:=u64(first)+u64(if count>0 { count-1 } else { 0 })
    mut indices:=?metal.IndexBinding(none)
    mut element_bytes:=[]u8{}
    mut allocated:=[]&metal.GPUBuffer{}
    defer {
        for mut buffer in allocated { buffer.close(); unsafe { free(buffer) } }
        unsafe { allocated.free(); element_bytes.free() }
    }
    if indexed {
        element:=context.objects[vao.element_buffer] or { metal_service_error(invalid_operation); return }
        if element.gpu_buffer==unsafe { nil } || offset>element.gpu_buffer.size() || u64(count)*u64(index_width)>u64(element.gpu_buffer.size()-int(offset)) { metal_service_error(invalid_operation); return }
        element_bytes=element.gpu_buffer.read(int(offset),count*index_width) or { metal_service_error(invalid_operation); return }
        maximum=0
        restart:=if index_width==1 { u32(255) } else if index_width==2 { u32(65535) } else { u32(0xffffffff) }
        for i in 0..count {
            mut value:=u32(0)
            for j in 0..index_width { value|=u32(element_bytes[i*index_width+j])<<(8*j) }
            if context.version==3 && value==restart { continue }
            if end:=range_end { if value>end { metal_service_error(invalid_operation); return } }
            if value>maximum { maximum=value }
        }
        indices=metal.IndexBinding{buffer:element.gpu_buffer,offset:int(offset),format:if index_width==1 { .u8 } else if index_width==2 { .u16 } else { .u32 },restart:context.version==3}
    }
    // Line loops and triangle fans have no Metal primitive. Expand each restart
    // segment into an equivalent indexed list, preserving original vertex IDs.
    mut primitive:=match mode { 0 { metal.Primitive.points } 1,2 { .lines } 3 { .line_strip } 5 { .triangle_strip } else { .triangles } }
    mut draw_count:=count
    mut draw_first:=first
    if mode in [u32(2),6] && count>0 {
        mut expanded:=[]u32{}
        defer { unsafe { expanded.free() } }
        mut segment:=[]u32{}
        defer { unsafe { segment.free() } }
        for i in 0..count+1 {
            mut value:=u32(first+i)
            mut boundary:=i==count
            if indexed && !boundary {
                value=0
                for j in 0..index_width { value|=u32(element_bytes[i*index_width+j])<<(8*j) }
                restart:=if index_width==1 { u32(255) } else if index_width==2 { u32(65535) } else { u32(0xffffffff) }
                boundary=context.version==3 && value==restart
            }
            if boundary {
                if mode==2 && segment.len>1 { for j in 0..segment.len { expanded<<segment[j];expanded<<segment[(j+1)%segment.len] } }
                if mode==6 && segment.len>2 { for j in 1..segment.len-1 { expanded<<segment[0];expanded<<segment[j];expanded<<segment[j+1] } }
                segment.clear()
            } else { segment<<value }
        }
        mut buffer:=metal.GPUBuffer.create(context.target,expanded.len*4) or { metal_service_error(out_of_memory);return }
        allocated<<buffer
        buffer.write(0,unsafe { (&u8(expanded.data)).vbytes(expanded.len*4) }) or { metal_service_error(out_of_memory);return }
        indices=metal.IndexBinding{buffer:buffer,format:.u32,restart:context.version==3}
        draw_count=expanded.len;draw_first=0
    } else if indexed { draw_first=0 }
    mut streams:=[]metal.VertexStream{}
    defer { unsafe { streams.free() } }
    for info in object.attributes {
        resource:=info.resource
        for part in u32(0)..resource.columns*resource.array_length {
            location:=resource.location+part
            if location>=16 { metal_service_error(invalid_operation); return }
            attribute:=vao.attributes[int(location)]
            if attribute.enabled {
                source:=context.objects[attribute.buffer] or { metal_service_error(invalid_operation); return }
                if source.gpu_buffer==unsafe { nil } { metal_service_error(invalid_operation); return }
                format:=metal_service_vertex_format(attribute.type_) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
                scalar:=metal_service_vertex_scalar_size(attribute.type_)
                stride:=if attribute.stride==0 { attribute.size*scalar } else { attribute.stride }
                last:=if attribute.divisor>0 { u64(if instances>0 { instances-1 } else { 0 })/attribute.divisor } else { maximum }
                if attribute.offset<0 || attribute.offset>source.gpu_buffer.size() || (count>0 && instances>0 && (last*u64(stride)+u64(attribute.size*scalar)>u64(source.gpu_buffer.size()-int(attribute.offset)))) { metal_service_error(invalid_operation);return }
                if stride<attribute.size*scalar { context.last_failure='Overlapping vertex strides are not implemented';metal_service_error(invalid_operation);return }
                streams<<metal.VertexStream{buffer:source.gpu_buffer,location:int(location),components:attribute.size,offset:int(attribute.offset),stride:stride,divisor:int(attribute.divisor),format:format,normalized:attribute.normalized,integer:attribute.integer}
            } else {
                current:=context.current_attributes[int(location)]
                mut buffer:=metal.GPUBuffer.create(context.target,16) or { metal_service_error(out_of_memory); return }
                allocated<<buffer
                data:=if current.kind==7 { unsafe { (&u8(&current.signed[0])).vbytes(16) } } else if current.kind==8 { unsafe { (&u8(&current.unsigned[0])).vbytes(16) } } else { unsafe { (&u8(&current.floats[0])).vbytes(16) } }
                buffer.write(0,data) or { metal_service_error(out_of_memory);return }
                streams<<metal.VertexStream{buffer:buffer,location:int(location),format:if current.kind==7 { .int32 } else if current.kind==8 { .uint32 } else { .float32 },integer:current.kind!=13,constant:true}
            }
        }
    }
    blocks:=context.uniform_block_bindings(object) or { context.last_failure=err.msg();return }
    defer { unsafe { blocks.free() } }
    mut textures:=context.texture_bindings(object) or { context.last_failure=err.msg();return }
    defer { textures.close() }
    context.target.draw_with_options(object.program,streams,primitive,draw_first,draw_count,instances,metal.DrawOptions{textures:textures.bindings,color_target:framebuffer_view.primary,color_targets:framebuffer_view.colors,colors_configured:framebuffer_view.custom,uniform_blocks:blocks,indices:indices,depth_stencil:framebuffer_view.depth,state:context.render_state(mode,framebuffer_view.has_depth,framebuffer_view.has_stencil)}) or {
        context.last_failure=err.msg();metal_service_error(invalid_operation);return
    }
    context.invalidate_draw_textures()
}
