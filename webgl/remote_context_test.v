module webgl

fn test_remote_context_creation_clamps_size_and_invalidates_display_list() {
	configuration := RemoteWebGLContextConfiguration{
		canvas_width: 0
		canvas_height: 20000
		supported_extensions: ['GL_EXT_test']
		data_region_capacity: 256
	}
	remote := create_remote_webgl_context(configuration, .webgl2, WebGLContextAttributes{
		depth: false
	}) or { panic('remote context should be created') }
	assert remote.version == .webgl2
	assert remote.attributes.depth == false
	assert remote.initial_size == WebGLIntSize{
		width: 1
		height: max_webgl_drawing_buffer_dimension
	}
	assert remote.display_list_invalidated

	proxy := create_webgl_context_proxy(configuration, .webgl2, WebGLContextAttributes{}) or {
		panic('proxy should be created')
	}
	assert proxy.webgl_version() == .webgl2
	assert proxy.get_supported_opengl_extensions() == ['GL_EXT_test']
	assert proxy.default_framebuffer() == 0
	assert proxy.default_renderbuffer() == 0
	proxy.make_current()
	proxy.notify_content_will_change()
}

fn test_remote_context_creation_preserves_each_host_failure() {
	assert create_remote_webgl_context(RemoteWebGLContextConfiguration{
		has_compositor_host: false
	}, .webgl1, WebGLContextAttributes{}) == none
	assert create_remote_webgl_context(RemoteWebGLContextConfiguration{
		transport_available: false
	}, .webgl1, WebGLContextAttributes{}) == none
	assert create_remote_webgl_context(RemoteWebGLContextConfiguration{
		creation_succeeds: false
	}, .webgl1, WebGLContextAttributes{}) == none
}

fn test_remote_context_restore_replaces_transport_state() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, ['before'], 64)!
	proxy.set_lost()
	assert restore_webgl_context_proxy(mut proxy, RemoteWebGLContextConfiguration{
		supported_extensions: ['after']
		data_region_capacity: 128
	}, .webgl1, WebGLContextAttributes{})
	assert !proxy.is_lost()
	assert proxy.get_supported_opengl_extensions() == ['after']

	proxy.set_lost()
	assert !restore_webgl_context_proxy(mut proxy, RemoteWebGLContextConfiguration{
		creation_succeeds: false
	}, .webgl1, WebGLContextAttributes{})
	assert proxy.is_lost()
}
