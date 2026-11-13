module webgl

fn test_nested_struct_array_uniform_locations_write_the_reflected_gpu_offsets() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[]);context.set_size(1,1)
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;struct Shade{vec3 tint;float strength;bool enabled;};struct Light{Shade shade;mat2 basis;};uniform Light lights[2];out vec4 color;void main(){color=vec4((lights[0].shade.enabled?lights[0].shade.tint:vec3(0))*lights[0].shade.strength+(lights[1].shade.enabled?lights[1].shade.tint:vec3(0))*lights[1].shade.strength+vec3(lights[1].basis[0],0),1);}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or { '' }
    context.use_program(program)
    for index in 0..2 {
        tint:=context.get_uniform_location(mut program,'lights[${index}].shade.tint') or { panic('nested tint') }
        strength:=context.get_uniform_location(mut program,'lights[${index}].shade.strength') or { panic('nested strength') }
        enabled:=context.get_uniform_location(mut program,'lights[${index}].shade.enabled') or { panic('nested bool') }
        context.uniform1i(enabled,-1)
        context.uniform3fv(tint,if index==0 { [f32(1),0,0] } else { [f32(0),1,0] })
        context.uniform1f(strength,if index==0 { f32(0.25) } else { f32(0.5) })
    }
    indices:=context.get_uniform_indices_nullable(program,['lights[0].shade.enabled','lights[1].shade.enabled']) or { panic('boolean indices') }
    assert context.get_active_uniforms(program,indices,uniform_type).integers==[i64(0x8b56),0x8b56]
    matrix:=context.get_uniform_location(mut program,'lights[1].basis') or { panic('nested matrix') }
    context.uniform_matrix2fv(matrix,false,[f32(0),0,0,0])
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(64),128,0,255]
}
