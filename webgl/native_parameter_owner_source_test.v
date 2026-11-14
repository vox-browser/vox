// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn parameter_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_get_parameter_cpu_retained_browser_and_error_paths_preserve_other_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		buffer := owner.create_buffer()
		texture := owner.create_texture()
		framebuffer_object := owner.create_framebuffer()
		renderbuffer_object := owner.create_renderbuffer()
		program := owner.create_program()
		owner.bind_buffer(array_buffer, buffer)
		owner.bind_texture(texture_2d, texture)
		owner.bind_framebuffer(framebuffer, framebuffer_object)
		owner.bind_renderbuffer(renderbuffer, renderbuffer_object)
		owner.use_program(program)
		assert owner.get_error() == invalid_operation
		owner.pixel_storei(unpack_flip_y_webgl, 1)
		owner.pixel_storei(unpack_premultiply_alpha_webgl, 1)
		owner.pixel_storei(unpack_colorspace_conversion_webgl, -1)
		owner.delete_buffer(buffer)
		assert buffer.object.invalidated()
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		for pname in [array_buffer_binding, element_array_buffer_binding, framebuffer_binding,
			renderbuffer_binding, current_program, texture_binding_2d, texture_binding_cube_map,
			compressed_texture_formats, unpack_flip_y_webgl, unpack_premultiply_alpha_webgl,
			unpack_colorspace_conversion_webgl] {
			result := owner.get_parameter(pname)
			parameter_source_owner([i32(9), 10, 11, 12]!)
			match pname {
				array_buffer_binding {
					assert result.buffer or { panic('actual invalidated buffer') } == buffer
				}
				framebuffer_binding {
					assert result.framebuffer or { panic('actual framebuffer') } == framebuffer_object
				}
				renderbuffer_binding {
					assert result.renderbuffer or { panic('actual renderbuffer') } == renderbuffer_object
				}
				current_program {
					assert result.program or { panic('actual rejected program') } == program
				}
				texture_binding_2d {
					assert result.texture or { panic('actual texture') } == texture
				}
				unpack_flip_y_webgl, unpack_premultiply_alpha_webgl {
					assert result.boolean
				}
				unpack_colorspace_conversion_webgl {
					assert result.integer == i64(0xffff_ffff)
				}
				compressed_texture_formats {
					assert result.kind == .integers
				}
				else {
					assert result.kind == .none
				}
			}
		}
		mut invalid_names := [GLenum(0xbad), unmasked_vendor_webgl, unmasked_renderer_webgl,
			GLenum(0x84ff)]
		if version == .webgl1 {
			invalid_names << [fragment_shader_derivative_hint, vertex_array_binding, sampler_binding,
				GLenum(0x8a30)]
		}
		for pname in invalid_names {
			other.native.make_current()
			assert owner.get_parameter(pname).kind == .none
			parameter_source_owner([i32(9), 10, 11, 12]!)
			assert owner.get_error() == invalid_enum
			parameter_source_owner([i32(1), 2, 3, 4]!)
		}
		other.native.make_current()
		if version == .webgl2 {
			for pname in [texture_binding_3d, texture_binding_2d_array, copy_read_buffer,
				copy_write_buffer, pixel_pack_buffer_binding, pixel_unpack_buffer_binding,
				uniform_buffer_binding, transform_feedback_buffer_binding, transform_feedback_binding,
				vertex_array_binding] {
				assert owner.get_parameter(pname).kind == .none
				parameter_source_owner([i32(9), 10, 11, 12]!)
			}
		}
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		// Genuine numeric/array sync queries select their actual Owner driver.
		assert owner.get_parameter(viewport).integers == [i64(1), 2, 3, 4]
		parameter_source_owner([i32(1), 2, 3, 4]!)
		owner.enable(blend)
		other.native.make_current()
		assert owner.get_parameter(blend).boolean
		parameter_source_owner([i32(1), 2, 3, 4]!)
		if version == .webgl2 {
			sampler := owner.create_sampler()
			owner.bind_sampler(0, sampler)
			other.native.make_current()
			queried := owner.get_parameter(sampler_binding).sampler or { panic('actual queried sampler record') }
			parameter_source_owner([i32(1), 2, 3, 4]!)
			assert queried != sampler
			assert queried.object.native_name() == sampler.object.native_name()
		}
		assert owner.get_error() == no_error
	}
}
