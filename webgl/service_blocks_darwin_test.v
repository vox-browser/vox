module webgl

fn C.vox_metal_service_no_angle() i32

fn test_direct_metal_uniform_block_ranges_reach_gpu_and_track_reallocation_and_deletion() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nlayout(std140) uniform Shade { vec4 tint; };out vec4 value;void main(){value=tint;gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;in vec4 value;out vec4 color;void main(){color=value;}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program()
    context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment)
    context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean
    context.use_program(program)
    block:=context.get_uniform_block_index(program,'Shade')
    assert block!=~u32(0)
    context.uniform_block_binding(program,block,4)
    context.draw_arrays(4,0,3)
    assert context.get_error()==invalid_operation
    buffer:=context.create_buffer()
    context.bind_buffer(uniform_buffer,buffer)
    context.buffer_data_size(uniform_buffer,272,0x88e8)
    tint:=[f32(1),0.25,0.5,1]
    context.buffer_sub_data(uniform_buffer,256,unsafe { (&u8(tint.data)).vbytes(16).clone() })
    context.bind_buffer_range(uniform_buffer,4,buffer,256,16)
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error,metal_service_current().last_failure
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),64,128,255]
    context.buffer_data_size(uniform_buffer,268,0x88e8)
    context.draw_arrays(4,0,3)
    assert context.get_error()==invalid_operation
    context.delete_buffer(buffer)
    context.draw_arrays(4,0,3)
    assert context.get_error()==invalid_operation
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}
