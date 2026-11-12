// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn sampler_parameter_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_sampler_parameter_owner_precedes_handle_and_exact_parameter_name_gates() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut owned := context.create_sampler()
	mut foreign := other.create_sampler()
	for floating in [false, true] {
		other.native.make_current()
		if floating {
			context.sampler_parameterf(mut foreign, 0xbad, 1.25)
		} else {
			context.sampler_parameteri(mut foreign, 0xbad, 1)
		}
		sampler_parameter_source_owner()
		assert context.get_error() == invalid_operation
		assert C.vox_gl_get_error() == no_error
		for pname in [GLenum(0xbad), texture_max_anisotropy_ext] {
			other.native.make_current()
			if floating {
				context.sampler_parameterf(mut owned, pname, 1.25)
			} else {
				context.sampler_parameteri(mut owned, pname, 1)
			}
			sampler_parameter_source_owner()
			assert C.vox_gl_get_error() == no_error
			assert context.get_error() == invalid_enum
		}
		// A present source name zero reaches the driver after valid pname selection.
		mut zero := context.get_parameter(sampler_binding).sampler or { panic('source zero sampler') }
		assert zero.object.native_handle_ == 0
		if floating {
			C.vox_gl_sampler_parameterf(0, texture_min_lod, -2.75)
		} else {
			C.vox_gl_sampler_parameteri(0, texture_min_lod, -2)
		}
		expected_zero := C.vox_gl_get_error()
		assert expected_zero != no_error
		other.native.make_current()
		if floating {
			context.sampler_parameterf(mut zero, texture_min_lod, -2.75)
		} else {
			context.sampler_parameteri(mut zero, texture_min_lod, -2)
		}
		sampler_parameter_source_owner()
		assert context.get_error() == expected_zero
	}
	context.delete_sampler(mut owned)
	for floating in [false, true] {
		other.native.make_current()
		if floating {
			context.sampler_parameterf(mut owned, 0xbad, 1.25)
		} else {
			context.sampler_parameteri(mut owned, 0xbad, 1)
		}
		sampler_parameter_source_owner()
		assert context.get_error() == invalid_operation
	}
}

fn test_source_sampler_parameter_switches_delegate_exact_integer_and_float_values_to_driver() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut sampler := context.create_sampler()
	pnames := [texture_compare_func, texture_compare_mode, texture_mag_filter, texture_max_lod,
		texture_min_filter, texture_min_lod, texture_wrap_r, texture_wrap_s, texture_wrap_t]
	values := [0x0203, 0, 0x2600, 4, 0x2600, -2, 0x812f, 0x812f, 0x812f]
	baselines := [0x0201, 0x884e, 0x2601, 0, 0x2601, 0, 0x2901, 0x2901, 0x2901]
	for floating in [false, true] {
		for index, pname in pnames {
			parameter := if floating && pname == texture_min_lod {
				f32(-2.75)
			} else if floating && pname == texture_max_lod {
				f32(4.5)
			} else {
				f32(values[index])
			}
			context.native.make_current()
			if floating {
				C.vox_gl_sampler_parameterf(sampler.object.native_handle_, pname, parameter)
			} else {
				C.vox_gl_sampler_parameteri(sampler.object.native_handle_, pname, values[index])
			}
			expected_error := C.vox_gl_get_error()
			expected_value := C.vox_gl_sampler_parameter(sampler.object.native_handle_, pname)
			assert expected_error == no_error
			C.vox_gl_sampler_parameteri(sampler.object.native_handle_, pname, baselines[index])
			assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, pname) != expected_value
			assert C.vox_gl_get_error() == no_error
			other.native.make_current()
			if floating {
				context.sampler_parameterf(mut sampler, pname, parameter)
			} else {
				context.sampler_parameteri(mut sampler, pname, values[index])
			}
			sampler_parameter_source_owner()
			assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, pname) == expected_value
			assert context.get_error() == expected_error
		}
		context.native.make_current()
		if floating {
			C.vox_gl_sampler_parameterf(sampler.object.native_handle_, texture_mag_filter, 0x2700)
		} else {
			C.vox_gl_sampler_parameteri(sampler.object.native_handle_, texture_mag_filter, 0x2700)
		}
		expected := C.vox_gl_get_error()
		assert expected != no_error
		other.native.make_current()
		if floating {
			context.sampler_parameterf(mut sampler, texture_mag_filter, 0x2700)
		} else {
			context.sampler_parameteri(mut sampler, texture_mag_filter, 0x2700)
		}
		sampler_parameter_source_owner()
		assert context.get_error() == expected
	}
	context.get_extension('EXT_texture_filter_anisotropic', false) or { panic('native anisotropy') }
	context.sampler_parameterf(mut sampler, texture_max_anisotropy_ext, 1.5)
	assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, texture_max_anisotropy_ext) == 1.5
	context.sampler_parameteri(mut sampler, texture_max_anisotropy_ext, 2)
	assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, texture_max_anisotropy_ext) == 2
	assert context.get_error() == no_error
}
