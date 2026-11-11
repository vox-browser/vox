module webgl

fn test_native_extension_discovery_caches_requested_extension_support() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	before := context.native.get_supported_opengl_extensions()
	assert before.len > 0
	assert 'GL_OES_vertex_array_object' in before
	assert 'OES_vertex_array_object' in context.get_supported_extensions(false)
	context.get_extension('OES_vertex_array_object', false) or { panic('native VAO') }
	// A native core context need not list the promoted OES extension; the
	// adapter exposes the capability without querying deprecated GL_EXTENSIONS.
	assert 'GL_OES_vertex_array_object' in native_gl_extensions()
	assert context.native.get_supported_opengl_extensions() == before
	context.get_extension('OES_vertex_array_object', false) or { panic('cached VAO') }
	assert context.native.requested_extensions_.filter(it == 'GL_OES_vertex_array_object').len == 1
	assert context.get_error() == no_error
}
