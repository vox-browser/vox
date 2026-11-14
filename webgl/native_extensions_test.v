module webgl

fn test_native_extension_discovery_caches_requested_extension_support() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	before := context.native.get_supported_opengl_extensions()
	assert before.len > 0
	assert 'GL_OES_vertex_array_object' in before
	assert 'OES_vertex_array_object' in context.get_supported_extensions(false)
	context.get_extension('OES_vertex_array_object', false) or { panic('native VAO') }
	assert 'GL_OES_vertex_array_object' in native_gl_string(0x1f03).split(' ')
	assert context.native.get_supported_opengl_extensions() == before
	context.get_extension('OES_vertex_array_object', false) or { panic('cached VAO') }
	assert context.native.requested_extensions_.filter(it == 'GL_OES_vertex_array_object').len == 1
	assert context.get_error() == no_error
}
