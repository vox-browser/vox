module webgl

fn test_shader_program_and_uniform_parent_validation() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex shader') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment shader') }
	context.shader_source(mut vertex, 'uniform vec4 color; void main() { gl_Position = color; }')
	context.shader_source(mut fragment, 'precision mediump float; void main() { gl_FragColor = vec4(1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	context.use_program(program)
	location := context.get_uniform_location(mut program, 'color') or { panic('location') }
	assert location.relevant_global_impl() or { panic('relevant global expected') } == context.identity()
	context.set_uniform(location, [f32(1), 0, 0, 1])
	assert context.get_error() == no_error
	mut other_program := context.create_program()
	context.current_program = other_program
	context.set_uniform(location, [f32(0)])
	assert context.get_error() == invalid_operation
	detached_location := WebGLUniformLocation.create(10, none)
	assert detached_location.relevant_global_impl() == none
	assert available_webgl_extensions().contains('WEBGL_debug_renderer_info')
	assert context.realm() == context.relevant_global_impl()
}

fn test_extension_filtering_caching_and_compressed_formats() {
	native_extensions := ['GL_ANGLE_instanced_arrays', 'GL_EXT_texture_compression_dxt1',
		'GL_ANGLE_texture_compression_dxt3', 'GL_ANGLE_texture_compression_dxt5']
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, native_extensions)
	supported := context.get_supported_extensions(false)
	assert 'ANGLE_instanced_arrays' in supported
	assert 'WEBGL_compressed_texture_s3tc' in supported
	first := context.get_extension('webgl_COMPRESSED_texture_s3tc', false) or { panic('extension') }
	second := context.get_extension('WEBGL_compressed_texture_s3tc', false) or {
		panic('extension')
	}
	assert first == second
	assert context.enabled_compressed_texture_formats().len == 4
}

fn test_experimental_extension_registry_matches_upstream_factory_filtering() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [
		'GL_EXT_frag_depth',
	])
	assert 'EXT_frag_depth' !in context.get_supported_extensions(false)
	assert 'EXT_frag_depth' in context.get_supported_extensions(true)
	// Upstream exposes the name experimentally but has no factory yet.
	assert context.get_extension('EXT_frag_depth', true) == none
	mut webgl2 := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [
		'GL_EXT_frag_depth',
	])
	assert 'EXT_frag_depth' !in webgl2.get_supported_extensions(true)
}
