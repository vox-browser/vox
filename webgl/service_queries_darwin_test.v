module webgl

fn C.vox_metal_service_no_angle() i32

fn test_direct_metal_occlusion_queries_count_actual_discard_scissor_and_depth_results() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;uniform float kill;out vec4 color;void main(){if(kill>0.5)discard;color=vec4(1,0,0,1);}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean
    context.use_program(program)
    kill:=context.get_uniform_location(mut program,'kill') or { panic('kill') }
    context.enable(scissor_test)
    for mode in 0..4 {
        context.uniform1f(kill,if mode==1 { f32(1) } else { f32(0) })
        context.scissor(0,0,if mode==2 { 0 } else { 2 },2)
        if mode==3 { context.clear_depth(0);context.clear(0x100);context.enable(depth_test) }
        mut query:=context.create_query()
        context.begin_query(any_samples_passed,mut query)
        context.draw_arrays(4,0,3)
        context.end_query(any_samples_passed)
        assert context.get_query_parameter(query,query_result_available)?==1
        assert context.get_query_parameter(query,query_result)?==if mode==0 { u64(1) } else { u64(0) }
        assert context.get_error()==no_error,metal_service_current().last_failure
    }
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}
