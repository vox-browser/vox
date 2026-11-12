module webgl

fn test_feedback_interleaved_and_separate_outputs_pack_matrix_padding_and_instances() {
    for mode in [u32(0x8c8c),0x8c8d] {
        mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
        defer { context.native.set_lost() }
        mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
        mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
        context.shader_source(mut vertex,'#version 300 es\nout vec3 value;out mat2 basis;void main(){value=vec3(gl_VertexID,gl_InstanceID,7);basis=mat2(1,2,3,4);gl_Position=vec4(0,0,0,1);}')
        context.shader_source(mut fragment,'#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1);}')
        context.compile_shader(mut vertex);context.compile_shader(mut fragment)
        mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment)
        context.transform_feedback_varyings(program,['value','basis'],mode)
        context.link_program(mut program)
        assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or { 'no log' }
        context.use_program(program)
        first:=context.create_buffer();second:=context.create_buffer()
        context.bind_buffer(transform_feedback_buffer,first);context.buffer_data_size(transform_feedback_buffer,176,0x88e8)
        context.bind_buffer_range(transform_feedback_buffer,0,first,4,168)
        if mode==0x8c8d {
            context.bind_buffer(transform_feedback_buffer,second);context.buffer_data_size(transform_feedback_buffer,104,0x88e8)
            context.bind_buffer_range(transform_feedback_buffer,1,second,4,96)
        }
        context.enable(rasterizer_discard)
        context.begin_transform_feedback(0)
        context.draw_arrays_instanced(0,1,3,2)
        context.use_program(none)
        assert context.get_error()==invalid_operation
        context.bind_buffer_base(transform_feedback_buffer,0,first)
        assert context.get_error()==invalid_operation
        context.draw_arrays(4,0,3)
        assert context.get_error()==invalid_operation
        context.end_transform_feedback()
        assert context.get_error()==no_error,metal_service_current().last_failure
        context.bind_buffer(transform_feedback_buffer,first)
        mut bytes:=[]u8{len:176};context.get_buffer_sub_data(transform_feedback_buffer,0,mut bytes,0,0)
        assert bytes[..4]==[u8(0),0,0,0]
        stride:=if mode==0x8c8c { 7 } else { 3 }
        for index in 0..6 {
            values:=unsafe { &f32(&bytes[4+index*stride*4]) }
            assert unsafe { values[0] }==f32(1+index%3)
            assert unsafe { values[1] }==f32(index/3)
            assert unsafe { values[2] }==7
            if mode==0x8c8c { for j in 0..4 { assert unsafe { values[3+j] }==f32(j+1) } }
        }
        if mode==0x8c8d {
            context.bind_buffer(transform_feedback_buffer,second)
            mut matrix:=[]u8{len:104};context.get_buffer_sub_data(transform_feedback_buffer,0,mut matrix,0,0)
            for index in 0..6 { for j in 0..4 { assert unsafe { *(&f32(&matrix[4+index*16+j*4])) }==f32(j+1) } }
            assert matrix[100..]==[u8(0),0,0,0]
        }
        assert context.get_error()==no_error
    }
}
