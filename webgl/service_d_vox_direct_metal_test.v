module webgl

fn C.vox_metal_service_no_angle() i32

fn test_direct_metal_public_context_clears_and_painting_surface_without_angle() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{stencil:true},[])
    defer { context.native.set_lost() }
    assert !context.native.is_lost()
    context.set_size(4,4)
    context.clear_color(1,0.25,0.5,1)
    context.clear(0x4500)
    surface:=context.native.read_back_drawing_buffer() or { panic('surface') }
    assert surface.width==4 && surface.height==4
    for i:=0;i<surface.pixels.len;i+=4 { assert surface.pixels[i..i+4]==[u8(255),64,128,255] }
    assert context.get_error()==no_error
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_public_masked_scissored_clear_preserves_raw_and_painting_rows() {
    mut context:=WebGLRenderingContext.new(.webgl1,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(4,4)
    context.clear_color(0,0.5,0,1)
    context.clear(0x4000)
    context.color_mask(true,false,true,false)
    context.enable(scissor_test)
    context.scissor(0,0,2,2)
    context.clear_color(1,0,1,0)
    context.clear(0x4000)
    surface:=context.native.read_back_drawing_buffer() or { panic('surface') }
    for y in 0..4 { for x in 0..4 {
        offset:=(y*4+x)*4
        assert surface.pixels[offset..offset+4]==if x<2 && y>=2 { [u8(255),128,255,255] } else { [u8(0),128,0,255] }
    } }
    assert context.get_error()==no_error
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_public_buffers_initialize_copy_and_reject_overlaps() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    source:=context.create_buffer()
    target:=context.create_buffer()
    context.bind_buffer(copy_read_buffer,source)
    context.buffer_data(copy_read_buffer,[u8(1),2,3,4],0x88e4)
    context.bind_buffer(copy_write_buffer,target)
    context.buffer_data_size(copy_write_buffer,8,0x88e8)
    mut bytes:=[]u8{len:8,init:255}
    context.get_buffer_sub_data(copy_write_buffer,0,mut bytes,0,0)
    assert bytes==[]u8{len:8}
    context.copy_buffer_sub_data(copy_read_buffer,copy_write_buffer,1,3,3)
    context.buffer_sub_data(copy_write_buffer,0,[u8(9),8])
    context.get_buffer_sub_data(copy_write_buffer,0,mut bytes,0,0)
    assert bytes==[u8(9),8,0,2,3,4,0,0]
    assert context.get_buffer_parameter(copy_write_buffer,buffer_size).integer==8
    assert context.get_error()==no_error
    context.bind_buffer(copy_read_buffer,target)
    context.copy_buffer_sub_data(copy_read_buffer,copy_write_buffer,0,1,4)
    assert context.get_error()==invalid_value
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn metal_service_test_program(mut context WebGLRenderingContext,vertex_source string,fragment_source string) &WebGLProgram {
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,vertex_source)
    context.shader_source(mut fragment,fragment_source)
    context.compile_shader(mut vertex)
    context.compile_shader(mut fragment)
    mut program:=context.create_program()
    context.attach_shader(mut program,vertex)
    context.attach_shader(mut program,fragment)
    context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or { '' }
    context.use_program(program)
    return program
}

fn test_direct_metal_public_signed_integer_vertex_and_uniforms_draw_exact_pixels() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(4,4)
    mut program:=metal_service_test_program(mut context,
        '#version 300 es\nin ivec4 numbers;uniform ivec2 pair;flat out int correct;void main(){correct=int(all(equal(numbers,ivec4(-2000000001,2000000001,-7,9)))&&all(equal(pair,ivec2(-2000000001,2000000001))));gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision highp float;flat in int correct;out vec4 color;void main(){color=correct==1?vec4(1,0,0,1):vec4(0,1,0,1);}')
    location:=context.get_attrib_location(program,'numbers')
    assert location>=0
    context.vertex_attrib_i4iv(u32(location),[-2_000_000_001,2_000_000_001,-7,9])
    uniform:=context.get_uniform_location(mut program,'pair') or { panic('uniform') }
    context.uniform2iv(uniform,[-2_000_000_001,2_000_000_001])
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error,metal_service_current().last_failure
    pixels:=context.read_pixels(0,0,4,4,rgba,unsigned_byte)
    for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4]==[u8(255),0,0,255] }
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_public_vertex_arrays_and_instancing_keep_owners_and_divisors() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(4,4)
    program:=metal_service_test_program(mut context,
        '#version 300 es\nin vec2 position;in vec4 shade;flat out vec4 value;void main(){value=shade;gl_Position=vec4(position,0,1);}',
        '#version 300 es\nprecision mediump float;flat in vec4 value;out vec4 color;void main(){color=value;}')
    position:=u32(context.get_attrib_location(program,'position'))
    shade:=u32(context.get_attrib_location(program,'shade'))
    vao:=context.create_vertex_array()
    context.bind_vertex_array(vao)
    vertices:=context.create_buffer()
    context.bind_buffer(array_buffer,vertices)
    coordinates:=[f32(-1),-1,3,-1,-1,3]
    context.buffer_data(array_buffer,unsafe { (&u8(coordinates.data)).vbytes(coordinates.len*4).clone() },0x88e4)
    context.vertex_attrib_pointer(position,2,gl_float,false,0,0)
    context.enable_vertex_attrib_array(position)
    colors:=context.create_buffer()
    context.bind_buffer(array_buffer,colors)
    context.buffer_data(array_buffer,[u8(255),0,0,255,0,255,0,255],0x88e4)
    context.vertex_attrib_pointer(shade,4,unsigned_byte,true,0,0)
    context.vertex_attrib_divisor(shade,1)
    context.enable_vertex_attrib_array(shade)
    context.draw_arrays_instanced(4,0,3,2)
    assert context.get_error()==no_error,metal_service_current().last_failure
    assert context.read_pixels(1,1,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
    context.bind_vertex_array(none)
    assert context.get_vertex_attrib(position,vertex_attrib_array_enabled).boolean==false
    context.bind_vertex_array(vao)
    assert context.get_vertex_attrib(shade,vertex_attrib_array_divisor).integer==1
    assert context.get_error()==no_error
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_raw_readback_preserves_packing_padding_and_rejects_short_destinations() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    context.clear_color(1,0,0,1)
    context.clear(0x4000)
    context.pixel_storei(0xd02,4)
    context.pixel_storei(0xd03,1)
    context.pixel_storei(0xd04,1)
    mut bytes:=[]u8{len:48,init:77}
    C.vox_gl_read_pixels(0,0,1,2,rgba,unsigned_byte,bytes.len,bytes.data)
    for index,value in bytes {
        if index in [20,23,36,39] { assert value==255 }
        else if index in [21,22,37,38] { assert value==0 }
        else { assert value==77 }
    }
    mut short:=[]u8{len:39,init:91}
    C.vox_gl_read_pixels(0,0,1,2,rgba,unsigned_byte,short.len,short.data)
    assert context.get_error()==invalid_operation
    assert short.all(it==91)
    assert metal_service_current().unsupported.len==0
}
