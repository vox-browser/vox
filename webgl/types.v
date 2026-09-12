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

pub const active_texture = GLenum(0x84e0)
pub const texture0 = GLenum(0x84c0)
pub const array_buffer_binding = GLenum(0x8894)
pub const element_array_buffer_binding = GLenum(0x8895)
pub const framebuffer_binding = GLenum(0x8ca6)
pub const renderbuffer_binding = GLenum(0x8ca7)
pub const texture_binding_2d = GLenum(0x8069)
pub const texture_binding_cube_map = GLenum(0x8514)
pub const texture_binding_3d = GLenum(0x806a)
pub const texture_binding_2d_array = GLenum(0x8c1d)
pub const current_program = GLenum(0x8b8d)

pub const blend = GLenum(0x0be2)
pub const cull_face = GLenum(0x0b44)
pub const depth_test = GLenum(0x0b71)
pub const dither = GLenum(0x0bd0)
pub const polygon_offset_fill = GLenum(0x8037)
pub const sample_alpha_to_coverage = GLenum(0x809e)
pub const sample_coverage = GLenum(0x80a0)
pub const scissor_test = GLenum(0x0c11)
pub const stencil_test = GLenum(0x0b90)

pub const blend_color = GLenum(0x8005)
pub const blend_dst_alpha = GLenum(0x80ca)
pub const blend_dst_rgb = GLenum(0x80c8)
pub const blend_equation_alpha = GLenum(0x883d)
pub const blend_equation_rgb = GLenum(0x8009)
pub const blend_src_alpha = GLenum(0x80cb)
pub const blend_src_rgb = GLenum(0x80c9)
pub const color_clear_value = GLenum(0x0c22)
pub const color_writemask = GLenum(0x0c23)
pub const cull_face_mode = GLenum(0x0b45)
pub const depth_clear_value = GLenum(0x0b73)
pub const depth_func = GLenum(0x0b74)
pub const depth_range = GLenum(0x0b70)
pub const depth_writemask = GLenum(0x0b72)
pub const front_face = GLenum(0x0b46)
pub const generate_mipmap_hint = GLenum(0x8192)
pub const line_width = GLenum(0x0b21)
pub const polygon_offset_factor = GLenum(0x8038)
pub const polygon_offset_units = GLenum(0x2a00)
pub const sample_coverage_invert = GLenum(0x80ab)
pub const sample_coverage_value = GLenum(0x80aa)
pub const scissor_box = GLenum(0x0c10)
pub const viewport = GLenum(0x0ba2)
pub const stencil_back_fail = GLenum(0x8801)
pub const stencil_back_func = GLenum(0x8800)
pub const stencil_back_pass_depth_fail = GLenum(0x8802)
pub const stencil_back_pass_depth_pass = GLenum(0x8803)
pub const stencil_back_ref = GLenum(0x8ca3)
pub const stencil_back_value_mask = GLenum(0x8ca4)
pub const stencil_back_writemask = GLenum(0x8ca5)
pub const stencil_clear_value = GLenum(0x0b91)
pub const stencil_fail = GLenum(0x0b94)
pub const stencil_func = GLenum(0x0b92)
pub const stencil_pass_depth_fail = GLenum(0x0b95)
pub const stencil_pass_depth_pass = GLenum(0x0b96)
pub const stencil_ref = GLenum(0x0b97)
pub const stencil_value_mask = GLenum(0x0b93)
pub const stencil_writemask = GLenum(0x0b98)
pub const pack_alignment = GLenum(0x0d05)
pub const pack_row_length = GLenum(0x0d02)
pub const pack_skip_rows = GLenum(0x0d03)
pub const pack_skip_pixels = GLenum(0x0d04)
pub const unpack_alignment = GLenum(0x0cf5)
pub const unpack_row_length = GLenum(0x0cf2)
pub const unpack_skip_rows = GLenum(0x0cf3)
pub const unpack_skip_pixels = GLenum(0x0cf4)
pub const unpack_skip_images = GLenum(0x806d)
pub const unpack_image_height = GLenum(0x806e)
pub const compressed_texture_formats = GLenum(0x86a3)
pub const pixel_pack_buffer_binding = GLenum(0x88ed)
pub const pixel_unpack_buffer_binding = GLenum(0x88ef)
pub const uniform_buffer_binding = GLenum(0x8a28)
pub const transform_feedback_buffer_binding = GLenum(0x8c8f)
pub const transform_feedback_paused = GLenum(0x8e23)
pub const transform_feedback_active = GLenum(0x8e24)
pub const transform_feedback_binding = GLenum(0x8e25)
pub const rasterizer_discard = GLenum(0x8c89)
pub const sampler_binding = GLenum(0x8919)
pub const vertex_array_binding = GLenum(0x85b5)

pub const array_buffer = GLenum(0x8892)
pub const element_array_buffer = GLenum(0x8893)
pub const copy_read_buffer = GLenum(0x8f36)
pub const copy_write_buffer = GLenum(0x8f37)
pub const pixel_pack_buffer = GLenum(0x88eb)
pub const pixel_unpack_buffer = GLenum(0x88ec)
pub const transform_feedback_buffer = GLenum(0x8c8e)
pub const uniform_buffer = GLenum(0x8a11)

pub const gl_zero = GLenum(0)
pub const gl_one = GLenum(1)
pub const src_color = GLenum(0x0300)
pub const one_minus_src_color = GLenum(0x0301)
pub const src_alpha = GLenum(0x0302)
pub const one_minus_src_alpha = GLenum(0x0303)
pub const dst_alpha = GLenum(0x0304)
pub const one_minus_dst_alpha = GLenum(0x0305)
pub const dst_color = GLenum(0x0306)
pub const one_minus_dst_color = GLenum(0x0307)
pub const src_alpha_saturate = GLenum(0x0308)
pub const constant_color = GLenum(0x8001)
pub const one_minus_constant_color = GLenum(0x8002)
pub const constant_alpha = GLenum(0x8003)
pub const one_minus_constant_alpha = GLenum(0x8004)
pub const front = GLenum(0x0404)
pub const back = GLenum(0x0405)
pub const front_and_back = GLenum(0x0408)
pub const cw = GLenum(0x0900)
pub const ccw = GLenum(0x0901)
pub const never = GLenum(0x0200)
pub const less = GLenum(0x0201)
pub const equal = GLenum(0x0202)
pub const lequal = GLenum(0x0203)
pub const greater = GLenum(0x0204)
pub const notequal = GLenum(0x0205)
pub const gequal = GLenum(0x0206)
pub const always = GLenum(0x0207)
pub const keep = GLenum(0x1e00)
pub const replace = GLenum(0x1e01)
pub const incr = GLenum(0x1e02)
pub const decr = GLenum(0x1e03)
pub const invert = GLenum(0x150a)
pub const incr_wrap = GLenum(0x8507)
pub const decr_wrap = GLenum(0x8508)
pub const func_add = GLenum(0x8006)
pub const gl_min = GLenum(0x8007)
pub const gl_max = GLenum(0x8008)
pub const func_subtract = GLenum(0x800a)
pub const func_reverse_subtract = GLenum(0x800b)
pub const dont_care = GLenum(0x1100)
pub const fastest = GLenum(0x1101)
pub const nicest = GLenum(0x1102)
pub const fragment_shader_derivative_hint = GLenum(0x8b8b)

pub const vertex_shader = GLenum(0x8b31)
pub const fragment_shader = GLenum(0x8b30)
pub const delete_status = GLenum(0x8b80)
pub const compile_status = GLenum(0x8b81)
pub const link_status = GLenum(0x8b82)
pub const validate_status = GLenum(0x8b83)
pub const attached_shaders = GLenum(0x8b85)
pub const active_uniforms = GLenum(0x8b86)
pub const active_attributes = GLenum(0x8b89)
pub const shader_type = GLenum(0x8b4f)
pub const buffer_size = GLenum(0x8764)
pub const buffer_usage = GLenum(0x8765)
pub const current_vertex_attrib = GLenum(0x8626)
pub const vertex_attrib_array_enabled = GLenum(0x8622)
pub const vertex_attrib_array_size = GLenum(0x8623)
pub const vertex_attrib_array_stride = GLenum(0x8624)
pub const vertex_attrib_array_type = GLenum(0x8625)
pub const vertex_attrib_array_pointer = GLenum(0x8645)
pub const vertex_attrib_array_normalized = GLenum(0x886a)
pub const vertex_attrib_array_buffer_binding = GLenum(0x889f)
pub const vertex_attrib_array_integer = GLenum(0x88fd)
pub const vertex_attrib_array_divisor = GLenum(0x88fe)
pub const transform_feedback_buffer_mode = GLenum(0x8c7f)
pub const transform_feedback_varyings = GLenum(0x8c83)
pub const active_uniform_blocks = GLenum(0x8a36)
pub const gl_byte = GLenum(0x1400)
pub const unsigned_byte = GLenum(0x1401)
pub const gl_short = GLenum(0x1402)
pub const unsigned_short = GLenum(0x1403)
pub const gl_int = GLenum(0x1404)
pub const unsigned_int = GLenum(0x1405)
pub const gl_float = GLenum(0x1406)
pub const half_float = GLenum(0x140b)
pub const depth_component = GLenum(0x1902)
pub const red = GLenum(0x1903)
pub const alpha = GLenum(0x1906)
pub const rgb = GLenum(0x1907)
pub const rgba = GLenum(0x1908)
pub const luminance = GLenum(0x1909)
pub const luminance_alpha = GLenum(0x190a)
pub const unsigned_short_4_4_4_4 = GLenum(0x8033)
pub const unsigned_short_5_5_5_1 = GLenum(0x8034)
pub const unsigned_short_5_6_5 = GLenum(0x8363)
pub const unsigned_int_2_10_10_10_rev = GLenum(0x8368)
pub const unsigned_int_24_8 = GLenum(0x84fa)
pub const red_integer = GLenum(0x8d94)
pub const rgb_integer = GLenum(0x8d98)
pub const rgba_integer = GLenum(0x8d99)
pub const float_32_unsigned_int_24_8_rev = GLenum(0x8dad)
pub const rg = GLenum(0x8227)
pub const rg_integer = GLenum(0x8228)
pub const unsigned_int_10f_11f_11f_rev = GLenum(0x8c3b)
pub const unsigned_int_5_9_9_9_rev = GLenum(0x8c3e)
pub const texture_2d = GLenum(0x0de1)
pub const texture_cube_map = GLenum(0x8513)
pub const texture_3d = GLenum(0x806f)
pub const texture_2d_array = GLenum(0x8c1a)
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
	xr_compatible                    bool
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
	xr_compatible                    ?bool
}

// PixelUnpackState mirrors the byte-addressing fields used by WebGL's 2D
// ArrayBufferView texture uploads. WebGL-only flip and premultiplication flags
// are applied when a DOM image source is converted, not while sizing a view.
pub struct PixelUnpackState {
pub:
	alignment   u64 = 4
	row_length  u64
	skip_pixels u64
	skip_rows   u64
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
			else {
				return error("TypeError: invalid WebGLPowerPreference '${preference}'")
			}
		}
	} else {
		WebGLPowerPreference.default_
	}
	return WebGLContextAttributes{
		alpha: attributes.alpha or { true }
		depth: attributes.depth or { true }
		stencil: attributes.stencil or { false }
		antialias: attributes.antialias or { true }
		premultiplied_alpha: attributes.premultiplied_alpha or { true }
		preserve_drawing_buffer: attributes.preserve_drawing_buffer or { false }
		power_preference: power
		fail_if_major_performance_caveat: attributes.fail_if_major_performance_caveat or { false }
		desynchronized: attributes.desynchronized or { false }
		xr_compatible: attributes.xr_compatible or { false }
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
		type_: type_
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

pub struct VertexAttribState {
pub:
	buffer_handle GLuint
	size          int = 4
	type_         GLenum = gl_float
	normalized    bool
	stride        int
	offset        i64
	integer       bool
	divisor       GLuint
}
