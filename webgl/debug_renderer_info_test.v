module webgl

fn test_debug_renderer_info_factory_keeps_its_context() {
	context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	extension := WebGLDebugRendererInfo.create(context)
	assert extension.context_identity() == context.identity()
}

fn test_debug_renderer_info_enables_unmasked_string_queries() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	assert 'WEBGL_debug_renderer_info' in context.get_supported_extensions(false)
	assert context.get_parameter(unmasked_vendor_webgl).kind == .none
	assert context.get_error() == invalid_enum

	extension := context.get_extension('webgl_DEBUG_renderer_INFO', false) or {
		panic('debug renderer info extension should be available')
	}
	assert extension.name == 'WEBGL_debug_renderer_info'
	assert extension.context_id == context.identity()
	debug_info := extension.debug_renderer_info or { panic('typed extension should be created') }
	assert debug_info.context_identity() == context.identity()
	assert context.get_extension('WEBGL_debug_renderer_info', false) or {
		panic('cached debug renderer info extension should be available')
	} == extension

	vendor := context.get_parameter(unmasked_vendor_webgl)
	renderer := context.get_parameter(unmasked_renderer_webgl)
	assert vendor.kind == .string_
	context.native.make_current()
	assert vendor.text == native_gl_string(0x1f00)
	assert vendor.text.len > 0
	assert renderer.kind == .string_
	assert renderer.text == native_gl_string(0x1f01)
	assert renderer.text.len > 0
	assert context.get_error() == no_error
}
