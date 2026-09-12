// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the compositor-backed creation helpers in
// WebGLRenderingContext.cpp. The transport itself is modeled by the proxy's
// in-memory batches; these inputs expose the host failure points explicitly.
module webgl

pub struct RemoteWebGLContextConfiguration {
pub:
	has_compositor_host  bool = true
	transport_available  bool = true
	creation_succeeds    bool = true
	canvas_width         int = 1
	canvas_height        int = 1
	supported_extensions []string
	data_region_capacity int = webgl_shared_default_data_region_capacity
}

pub struct RemoteWebGLContext {
pub:
	version                  WebGLVersion
	attributes               WebGLContextAttributes
	initial_size             WebGLIntSize
	supported_extensions     []string
	display_list_invalidated bool
	data_region_capacity     int
}

pub fn create_remote_webgl_context(configuration RemoteWebGLContextConfiguration, version WebGLVersion, attributes WebGLContextAttributes) ?RemoteWebGLContext {
	if !configuration.has_compositor_host || !configuration.transport_available
		|| !configuration.creation_succeeds || configuration.data_region_capacity <= 0 {
		return none
	}
	width, height := initial_drawing_buffer_size(configuration.canvas_width, configuration.canvas_height)
	return RemoteWebGLContext{
		version: version
		attributes: attributes
		initial_size: WebGLIntSize{ width: width, height: height }
		supported_extensions: configuration.supported_extensions.clone()
		display_list_invalidated: true
		data_region_capacity: configuration.data_region_capacity
	}
}

pub fn create_webgl_context_proxy(configuration RemoteWebGLContextConfiguration, version WebGLVersion, attributes WebGLContextAttributes) ?&WebGLContextProxyBase {
	remote := create_remote_webgl_context(configuration, version, attributes) or { return none }
	return WebGLContextProxyBase.new(remote.version, remote.supported_extensions, remote.data_region_capacity) or { none }
}

pub fn restore_webgl_context_proxy(mut proxy WebGLContextProxyBase, configuration RemoteWebGLContextConfiguration, version WebGLVersion, attributes WebGLContextAttributes) bool {
	remote := create_remote_webgl_context(configuration, version, attributes) or { return false }
	proxy.restore(remote.supported_extensions, remote.data_region_capacity) or { return false }
	return true
}
