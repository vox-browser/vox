// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGL/Types.{h,idl}, EventNames and shared GL vocabulary.
module webgl

pub type GLenum = u32
pub type GLuint = u32
pub type GLint = int
pub type GLsizei = int
pub type GLintptr = i64
pub type GLsizeiptr = i64

pub const no_error = GLenum(0)
pub const invalid_enum = GLenum(0x0500)
pub const invalid_value = GLenum(0x0501)
pub const invalid_operation = GLenum(0x0502)
pub const out_of_memory = GLenum(0x0505)
pub const invalid_framebuffer_operation = GLenum(0x0506)
pub const context_lost_webgl = GLenum(0x9242)

pub const array_buffer = GLenum(0x8892)
pub const element_array_buffer = GLenum(0x8893)
pub const copy_read_buffer = GLenum(0x8f36)
pub const copy_write_buffer = GLenum(0x8f37)
pub const pixel_pack_buffer = GLenum(0x88eb)
pub const pixel_unpack_buffer = GLenum(0x88ec)
pub const transform_feedback_buffer = GLenum(0x8c8e)
pub const uniform_buffer = GLenum(0x8a11)

pub const vertex_shader = GLenum(0x8b31)
pub const fragment_shader = GLenum(0x8b30)
pub const texture_2d = GLenum(0x0de1)
pub const texture_cube_map = GLenum(0x8513)
pub const framebuffer = GLenum(0x8d40)
pub const renderbuffer = GLenum(0x8d41)
pub const transform_feedback = GLenum(0x8e22)
pub const texture_compare_func = GLenum(0x884d)
pub const texture_compare_mode = GLenum(0x884c)
pub const texture_mag_filter = GLenum(0x2800)
pub const texture_min_filter = GLenum(0x2801)
pub const texture_max_lod = GLenum(0x813b)
pub const texture_min_lod = GLenum(0x813a)
pub const texture_wrap_r = GLenum(0x8072)
pub const texture_wrap_s = GLenum(0x2802)
pub const texture_wrap_t = GLenum(0x2803)
pub const texture_max_anisotropy_ext = GLenum(0x84fe)

pub const unpack_flip_y_webgl = GLenum(0x9240)
pub const unpack_premultiply_alpha_webgl = GLenum(0x9241)
pub const unpack_colorspace_conversion_webgl = GLenum(0x9243)
pub const browser_default_webgl = GLenum(0x9244)
pub const max_client_wait_timeout_webgl = GLenum(0x9247)

pub const query_result = GLenum(0x8866)
pub const query_result_available = GLenum(0x8867)
pub const current_query = GLenum(0x8865)
pub const any_samples_passed = GLenum(0x8c2f)
pub const any_samples_passed_conservative = GLenum(0x8d6a)
pub const transform_feedback_primitives_written = GLenum(0x8c88)

pub const sync_gpu_commands_complete = GLenum(0x9117)
pub const already_signaled = GLenum(0x911a)
pub const timeout_expired = GLenum(0x911b)
pub const condition_satisfied = GLenum(0x911c)
pub const wait_failed = GLenum(0x911d)

pub const compressed_rgb_s3tc_dxt1_ext = GLenum(0x83f0)
pub const compressed_rgba_s3tc_dxt1_ext = GLenum(0x83f1)
pub const compressed_rgba_s3tc_dxt3_ext = GLenum(0x83f2)
pub const compressed_rgba_s3tc_dxt5_ext = GLenum(0x83f3)
pub const compressed_srgb_s3tc_dxt1_ext = GLenum(0x8c4c)
pub const compressed_srgb_alpha_s3tc_dxt1_ext = GLenum(0x8c4d)
pub const compressed_srgb_alpha_s3tc_dxt3_ext = GLenum(0x8c4e)
pub const compressed_srgb_alpha_s3tc_dxt5_ext = GLenum(0x8c4f)

pub const event_names = ['webglcontextcreationerror', 'webglcontextlost', 'webglcontextrestored']

pub enum WebGLVersion {
	webgl1
	webgl2
}

pub enum WebGLPowerPreference {
	default_
	high_performance
	low_power
}

pub struct WebGLContextAttributes {
pub:
	alpha                            bool = true
	depth                            bool = true
	stencil                          bool
	antialias                        bool = true
	premultiplied_alpha              bool = true
	preserve_drawing_buffer          bool
	power_preference                 WebGLPowerPreference = .default_
	fail_if_major_performance_caveat bool
	desynchronized                   bool
}

pub struct ContextAttributeInput {
pub:
	alpha                            ?bool
	depth                            ?bool
	stencil                          ?bool
	antialias                        ?bool
	premultiplied_alpha              ?bool
	preserve_drawing_buffer          ?bool
	power_preference                 ?string
	fail_if_major_performance_caveat ?bool
	desynchronized                   ?bool
}

// convert_value_to_context_attributes_dictionary preserves WebIDL defaults
// and throws for an invalid enumeration token.
pub fn convert_context_attributes(input ?ContextAttributeInput) !WebGLContextAttributes {
	attributes := input or { return WebGLContextAttributes{} }
	power := if preference := attributes.power_preference {
		match preference {
			'default' { WebGLPowerPreference.default_ }
			'high-performance' { WebGLPowerPreference.high_performance }
			'low-power' { WebGLPowerPreference.low_power }
			else { return error("TypeError: invalid WebGLPowerPreference '${preference}'") }
		}
	} else {
		WebGLPowerPreference.default_
	}
	return WebGLContextAttributes{
		alpha:                            attributes.alpha or { true }
		depth:                            attributes.depth or { true }
		stencil:                          attributes.stencil or { false }
		antialias:                        attributes.antialias or { true }
		premultiplied_alpha:              attributes.premultiplied_alpha or { true }
		preserve_drawing_buffer:          attributes.preserve_drawing_buffer or { false }
		power_preference:                 power
		fail_if_major_performance_caveat: attributes.fail_if_major_performance_caveat or { false }
		desynchronized:                   attributes.desynchronized or { false }
	}
}

pub struct WebGLContextEventInit {
pub:
	status_message string
}

pub struct WebGLContextEvent {
pub:
	type_          string
	status_message string
}

pub fn WebGLContextEvent.new(type_ string, init WebGLContextEventInit) WebGLContextEvent {
	return WebGLContextEvent{
		type_:          type_
		status_message: init.status_message
	}
}

pub struct WebGLActiveInfo {
pub:
	name  string
	type_ GLenum
	size  GLsizei
}

pub struct WebGLShaderPrecisionFormat {
pub:
	range_min int
	range_max int
	precision int
}
