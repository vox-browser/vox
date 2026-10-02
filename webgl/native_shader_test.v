module webgl

fn test_native_shader_compilation_linking_and_real_reflection() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut vertex := context.create_shader(vertex_shader) or { panic('native shader') }
	mut fragment := context.create_shader(fragment_shader) or { panic('native shader') }
	context.shader_source(mut vertex, 'attribute vec2 position; attribute vec2 unused; uniform vec4 colors[2]; varying vec4 v_color; void main() { gl_Position = vec4(position, 0.0, 1.0) + colors[1]; v_color = colors[0]; }')
	context.shader_source(mut fragment, 'precision mediump float; varying vec4 v_color; void main() { gl_FragColor = v_color; }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	assert context.get_shader_parameter(vertex, compile_status).boolean
	assert context.get_shader_parameter(fragment, compile_status).boolean
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.bind_attrib_location(program, 5, 'position')
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	assert context.get_program_parameter(program, active_attributes).integer == 1
	assert context.get_program_parameter(program, active_uniforms).integer == 1
	attribute := context.get_active_attrib(program, 0) or { panic('active attribute') }
	assert attribute.name() == 'position'
	assert attribute.type_() == GLenum(0x8b50) // FLOAT_VEC2
	assert attribute.size() == 1
	assert context.get_attrib_location(program, 'position') == 5
	assert context.get_attrib_location(program, 'unused') == -1
	assert context.get_attrib_location(program, 'invented') == -1
	uniform := context.get_active_uniform(program, 0) or { panic('active uniform') }
	assert uniform.name() == 'colors[0]'
	assert uniform.type_() == GLenum(0x8b52) // FLOAT_VEC4
	assert uniform.size() == 2
	assert context.get_uniform_location(mut program, 'colors') != none
	assert context.get_uniform_location(mut program, 'colors[1]') != none
	assert context.get_uniform_location(mut program, 'invented') == none
	assert context.get_active_attrib(program, 1) == none
	assert context.get_error() == invalid_value
	assert context.get_active_uniform(program, 1) == none
	assert context.get_error() == invalid_value
}

fn test_nonempty_invalid_shader_and_varying_link_failure_are_native_results() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut vertex := context.create_shader(vertex_shader) or { panic('shader') }
	context.shader_source(mut vertex, 'This is nonempty invalid GLSL')
	context.compile_shader(mut vertex)
	assert !context.get_shader_parameter(vertex, compile_status).boolean
	assert (context.get_shader_info_log(vertex) or { '' }).len > 0
	assert context.get_error() == no_error
	context.shader_source(mut vertex, 'varying vec4 mismatch; void main() { gl_Position = vec4(1.0); mismatch = vec4(1.0); }')
	context.compile_shader(mut vertex)
	mut fragment := context.create_shader(fragment_shader) or { panic('shader') }
	context.shader_source(mut fragment, 'precision mediump float; varying vec3 mismatch; void main() { gl_FragColor = vec4(mismatch, 1.0); }')
	context.compile_shader(mut fragment)
	assert context.get_shader_parameter(vertex, compile_status).boolean
	assert context.get_shader_parameter(fragment, compile_status).boolean
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert !context.get_program_parameter(program, link_status).boolean
	assert (context.get_program_info_log(program) or { '' }).len > 0
	context.use_program(program)
	assert context.get_error() == invalid_operation
}
