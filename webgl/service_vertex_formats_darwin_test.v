module webgl

fn packed_vertex_program(mut context WebGLRenderingContext,expression string,components int) {
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nin vec${components} inputValue;out vec4 value;void main(){value=${expression};gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;in vec4 value;out vec4 color;void main(){color=value;}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.bind_attrib_location(program,0,'inputValue');context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean
    context.use_program(program)
}

fn test_packed_unsigned_and_signed_vertex_formats_keep_normalized_and_integer_values() {
    mut differences:=[]string{}
    for signed in [false,true] { for normalized in [false,true] {
        mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[]);context.set_size(1,1)
        expression:=if signed { if normalized { 'inputValue*0.5+0.5' } else { '(inputValue/vec4(511,511,511,1))*0.5+0.5' } } else { if normalized { 'inputValue' } else { 'inputValue/vec4(1023,1023,1023,3)' } }
        packed_vertex_program(mut context,expression,4)
        bits:=if signed { u32(512)|(u32(511)<<20)|(u32(2)<<30) } else { u32(1023)|(u32(512)<<20)|(u32(3)<<30) }
        words:=[bits,bits,bits]
        buffer:=context.create_buffer();context.bind_buffer(array_buffer,buffer);context.buffer_data(array_buffer,unsafe { (&u8(words.data)).vbytes(12).clone() },0x88e4)
        context.vertex_attrib_pointer(0,4,if signed { u32(0x8d9f) } else { u32(0x8368) },normalized,0,0);context.enable_vertex_attrib_array(0);context.draw_arrays(4,0,3)
        assert context.get_error()==no_error
        actual:=context.read_pixels(0,0,1,1,rgba,unsigned_byte)
        expected:=if signed { [u8(0),128,255,0] } else { [u8(255),0,128,255] }
        if actual!=expected { differences<<'signed=${signed}, normalized=${normalized}, actual=${actual}, expected=${expected}' }
    } }
    assert differences.len==0,differences.join('\n')
}

fn test_normalized_i32_and_overlapping_float_vertex_strides() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[]);context.set_size(1,1)
    packed_vertex_program(mut context,'inputValue*0.5+0.5',4)
    values:=[i32(-2147483647-1),0,2147483647,2147483647].repeat(3)
    buffer:=context.create_buffer();context.bind_buffer(array_buffer,buffer);context.buffer_data(array_buffer,unsafe { (&u8(values.data)).vbytes(values.len*4).clone() },0x88e4)
    context.vertex_attrib_pointer(0,4,gl_int,true,0,0);context.enable_vertex_attrib_array(0);context.draw_arrays(4,0,3)
    assert context.get_error()==no_error
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),128,255,255]
    packed_vertex_program(mut context,'vec4(inputValue,0,1)',2)
    floats:=[f32(0),0.5,1,0.25]
    context.buffer_data(array_buffer,unsafe { (&u8(floats.data)).vbytes(16).clone() },0x88e4)
    context.vertex_attrib_pointer(0,2,gl_float,false,4,0);context.draw_arrays(4,0,3)
    assert context.get_error()==no_error
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(96),143,0,255]
}
