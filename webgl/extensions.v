// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLRenderingContextBase extension discovery and all
// WebGL/Extensions implementation units.
module webgl

struct ExtensionDescriptor {
	name               string
	required_native    []string
	version            ?WebGLVersion
	implemented        bool
	creates_empty_object bool
	compressed_formats []GLenum
}

const available_extensions = [
	ExtensionDescriptor{
		name:            'ANGLE_instanced_arrays'
		required_native: ['GL_ANGLE_instanced_arrays']
		version:         WebGLVersion.webgl1
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'EXT_blend_minmax'
		required_native: ['GL_EXT_blend_minmax']
		version:         WebGLVersion.webgl1
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'EXT_frag_depth'
		required_native: ['GL_EXT_frag_depth']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'EXT_shader_texture_lod'
		required_native: ['GL_EXT_shader_texture_lod']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'EXT_color_buffer_float'
		required_native: ['GL_EXT_color_buffer_float']
		version:         WebGLVersion.webgl2
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'EXT_render_snorm'
		required_native: ['GL_EXT_render_snorm']
		version:         WebGLVersion.webgl2
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'EXT_texture_filter_anisotropic'
		required_native: ['GL_EXT_texture_filter_anisotropic']
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'EXT_texture_norm16'
		required_native: ['GL_EXT_texture_norm16']
		version:         WebGLVersion.webgl2
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'OES_element_index_uint'
		required_native: ['GL_OES_element_index_uint']
		version:         WebGLVersion.webgl1
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'OES_standard_derivatives'
		required_native: ['GL_OES_standard_derivatives']
		version:         WebGLVersion.webgl1
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'OES_texture_float'
		required_native: ['GL_OES_texture_float']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'OES_texture_float_linear'
		required_native: ['GL_OES_texture_float_linear']
		creates_empty_object: true
	},
	ExtensionDescriptor{
		name:            'OES_texture_half_float'
		required_native: ['GL_OES_texture_half_float']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'OES_texture_half_float_linear'
		required_native: ['GL_OES_texture_half_float_linear']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'OES_vertex_array_object'
		required_native: ['GL_OES_vertex_array_object']
		version:         WebGLVersion.webgl1
		implemented:     true
	},
	ExtensionDescriptor{
		name:               'WEBGL_compressed_texture_s3tc'
		required_native:    ['GL_EXT_texture_compression_dxt1', 'GL_ANGLE_texture_compression_dxt3',
			'GL_ANGLE_texture_compression_dxt5']
		implemented:        true
		compressed_formats: [compressed_rgb_s3tc_dxt1_ext, compressed_rgba_s3tc_dxt1_ext,
			compressed_rgba_s3tc_dxt3_ext, compressed_rgba_s3tc_dxt5_ext]
	},
	ExtensionDescriptor{
		name:               'WEBGL_compressed_texture_s3tc_srgb'
		required_native:    ['GL_EXT_texture_compression_s3tc_srgb']
		implemented:        true
		compressed_formats: [compressed_srgb_s3tc_dxt1_ext, compressed_srgb_alpha_s3tc_dxt1_ext,
			compressed_srgb_alpha_s3tc_dxt3_ext, compressed_srgb_alpha_s3tc_dxt5_ext]
	},
	ExtensionDescriptor{
		name:            'WEBGL_draw_buffers'
		required_native: ['GL_EXT_draw_buffers']
		version:         WebGLVersion.webgl1
		implemented:     true
	},
	ExtensionDescriptor{
		name:            'WEBGL_depth_texture'
		required_native: ['GL_ANGLE_depth_texture']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'EXT_clip_control'
		required_native: ['GL_EXT_clip_control']
	},
	ExtensionDescriptor{
		name:            'EXT_color_buffer_half_float'
		required_native: ['GL_EXT_color_buffer_half_float']
	},
	ExtensionDescriptor{
		name:            'EXT_conservative_depth'
		required_native: ['GL_EXT_conservative_depth']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'EXT_depth_clamp'
		required_native: ['GL_EXT_depth_clamp']
	},
	ExtensionDescriptor{
		name:            'EXT_disjoint_timer_query'
		required_native: ['GL_EXT_disjoint_timer_query']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'EXT_disjoint_timer_query_webgl2'
		required_native: ['GL_EXT_disjoint_timer_query']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'EXT_float_blend'
		required_native: ['GL_EXT_float_blend']
		creates_empty_object: true
	},
	ExtensionDescriptor{
		name:            'EXT_polygon_offset_clamp'
		required_native: ['GL_EXT_polygon_offset_clamp']
	},
	ExtensionDescriptor{
		name:            'EXT_sRGB'
		required_native: ['GL_EXT_sRGB']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'EXT_texture_compression_bptc'
		required_native: ['GL_EXT_texture_compression_bptc']
	},
	ExtensionDescriptor{
		name:            'EXT_texture_compression_rgtc'
		required_native: ['GL_EXT_texture_compression_rgtc']
	},
	ExtensionDescriptor{
		name:            'EXT_texture_mirror_clamp_to_edge'
		required_native: ['GL_EXT_texture_mirror_clamp_to_edge']
	},
	ExtensionDescriptor{
		name:            'KHR_parallel_shader_compile'
		required_native: ['GL_KHR_parallel_shader_compile']
	},
	ExtensionDescriptor{
		name:            'NV_shader_noperspective_interpolation'
		required_native: ['GL_NV_shader_noperspective_interpolation']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'OES_draw_buffers_indexed'
		required_native: ['GL_OES_draw_buffers_indexed']
	},
	ExtensionDescriptor{
		name:            'OES_fbo_render_mipmap'
		required_native: ['GL_OES_fbo_render_mipmap']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'OES_sample_variables'
		required_native: ['GL_OES_sample_variables']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'OES_shader_multisample_interpolation'
		required_native: ['GL_OES_shader_multisample_interpolation']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'OVR_multiview2'
		required_native: ['GL_OVR_multiview2']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'WEBGL_blend_func_extended'
		required_native: ['GL_EXT_blend_func_extended']
	},
	ExtensionDescriptor{
		name:            'WEBGL_clip_cull_distance'
		required_native: ['GL_EXT_clip_cull_distance']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'WEBGL_color_buffer_float'
		required_native: ['EXT_color_buffer_half_float', 'OES_texture_float']
		version:         WebGLVersion.webgl1
	},
	ExtensionDescriptor{
		name:            'WEBGL_compressed_texture_astc'
		required_native: ['KHR_texture_compression_astc_hdr', 'KHR_texture_compression_astc_ldr']
	},
	ExtensionDescriptor{
		name:            'WEBGL_compressed_texture_etc'
		required_native: ['GL_ANGLE_compressed_texture_etc']
	},
	ExtensionDescriptor{
		name:            'WEBGL_compressed_texture_etc1'
		required_native: ['GL_OES_compressed_ETC1_RGB8_texture']
	},
	ExtensionDescriptor{
		name:            'WEBGL_compressed_texture_pvrtc'
		required_native: ['GL_IMG_texture_compression_pvrtc']
	},
	ExtensionDescriptor{
		name:            'WEBGL_multi_draw'
		required_native: ['GL_ANGLE_multi_draw']
	},
	ExtensionDescriptor{
		name:            'WEBGL_polygon_mode'
		required_native: ['GL_ANGLE_polygon_mode']
	},
	ExtensionDescriptor{
		name:            'WEBGL_provoking_vertex'
		required_native: ['GL_ANGLE_provoking_vertex']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'WEBGL_render_shared_exponent'
		required_native: ['GL_QCOM_render_shared_exponent']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:            'WEBGL_stencil_texturing'
		required_native: ['GL_ANGLE_stencil_texturing']
		version:         WebGLVersion.webgl2
	},
	ExtensionDescriptor{
		name:        'WEBGL_debug_renderer_info'
		implemented: true
	},
	ExtensionDescriptor{
		name: 'WEBGL_debug_shaders'
	},
	ExtensionDescriptor{
		name: 'WEBGL_lose_context'
	},
]

pub fn available_webgl_extensions() []string {
	return available_extensions.map(it.name)
}

@[heap]
pub struct WebGLExtension {
pub:
	name                string
	context_id          u64
	creates_empty_object bool
	debug_renderer_info ?&WebGLDebugRendererInfo
}

@[heap]
pub struct WebGLDebugRendererInfo {
mut:
	context &WebGLRenderingContext
}

pub fn WebGLDebugRendererInfo.create(context &WebGLRenderingContext) &WebGLDebugRendererInfo {
	return &WebGLDebugRendererInfo{
		context: context
	}
}

pub fn (extension &WebGLDebugRendererInfo) context_identity() u64 {
	return extension.context.identity()
}

fn find_extension_descriptor(name string) ?ExtensionDescriptor {
	for descriptor in available_extensions {
		if descriptor.name.to_lower_ascii() == name.to_lower_ascii() { return descriptor }
	}
	return none
}

pub fn (mut context WebGLRenderingContext) get_supported_extensions(experimental bool) []string {
	native := context.native.get_supported_opengl_extensions()
	mut result := []string{}
	for descriptor in available_extensions {
		if version := descriptor.version {
			if version != context.version { continue
			 }
		}
		if !descriptor.implemented && !descriptor.creates_empty_object && !experimental { continue
		 }
		mut supported := true
		for requirement in descriptor.required_native {
			if requirement !in native {
				supported = false
				break
			}
		}
		if supported { result << descriptor.name }
	}
	return result
}

// Repeated case-insensitive requests return the same extension object.
pub fn (mut context WebGLRenderingContext) get_extension(name string, experimental bool) ?&WebGLExtension {
	// The source rejects non-ASCII names before extension lookup/cache access.
	for byte in name.bytes() {
		if byte > 0x7f { return none }
	}
	canonical := name.to_lower_ascii()
	if existing := context.enabled_extensions[canonical] { return existing }
	if name !in context.get_supported_extensions(experimental)
		&& context.get_supported_extensions(experimental).all(it.to_lower_ascii() != canonical) {
		return none
	}
	descriptor := find_extension_descriptor(name) or { return none }
	if !descriptor.implemented && !descriptor.creates_empty_object { return none }
	for requirement in descriptor.required_native {
		context.native.request_extension(requirement)
	}
	for format in descriptor.compressed_formats {
		context.enable_compressed_texture_format(format)
	}
	mut debug_renderer_info := ?&WebGLDebugRendererInfo(none)
	if canonical == 'webgl_debug_renderer_info' {
		debug_renderer_info = WebGLDebugRendererInfo.create(context)
	}
	extension := &WebGLExtension{
		name: descriptor.name
		context_id: context.identity()
		creates_empty_object: descriptor.creates_empty_object
		debug_renderer_info: debug_renderer_info
	}
	unsafe {
		context.enabled_extensions[canonical] = extension
	}
	return extension
}

pub fn (context &WebGLRenderingContext) extension_enabled(name string) bool {
	return name.to_lower_ascii() in context.enabled_extensions
}

pub fn (mut context WebGLRenderingContext) enable_compressed_texture_format(format GLenum) {
	if format !in context.enabled_compressed_texture_formats_ {
		context.enabled_compressed_texture_formats_ << format
	}
}

pub fn (context &WebGLRenderingContext) enabled_compressed_texture_formats() []GLenum {
	return context.enabled_compressed_texture_formats_.clone()
}

pub fn (extension &WebGLExtension) vertex_attrib_divisor_angle(mut context WebGLRenderingContext, index GLuint, divisor GLuint) {
	if extension.context_id == context.identity() {
		context.native.dispatch('vertex_attrib_divisor_angle', index, divisor)
	}
}

pub fn (extension &WebGLExtension) draw_arrays_instanced_angle(mut context WebGLRenderingContext, mode GLenum, first int, count int, instances int) {
	if extension.context_id == context.identity() {
		context.native.dispatch('draw_arrays_instanced_angle', mode, first, count, instances)
	}
}

pub fn (extension &WebGLExtension) draw_elements_instanced_angle(mut context WebGLRenderingContext, mode GLenum, count int, type_ GLenum, offset i64, instances int) {
	if extension.context_id == context.identity() {
		context.native.dispatch('draw_elements_instanced_angle', mode, count, type_, offset,
			instances)
	}
}

pub fn (extension &WebGLExtension) draw_buffers_webgl(mut context WebGLRenderingContext, buffers []GLenum) {
	if extension.context_id != context.identity() { return }
	mut args := []i64{cap: buffers.len}
	for buffer in buffers {
		args << i64(buffer)
	}
	context.native.dispatch('draw_buffers_webgl', ...args)
}
