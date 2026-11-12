// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct RasterEnumSourceCase {
	method string
	args   []GLenum
}

fn raster_enum_source_state() []int {
	mut values := []int{}
	for pname in [cull_face_mode, depth_func, front_face, generate_mipmap_hint] {
		mut value := i32(0)
		C.vox_gl_int_parameter(pname, &value)
		values << value
	}
	return values
}

fn raster_enum_source_direct(operation RasterEnumSourceCase) {
	match operation.method {
		'cull' { C.vox_gl_cull_face(operation.args[0]) }
		'depth' { C.vox_gl_depth_func(operation.args[0]) }
		'front' { C.vox_gl_front_face(operation.args[0]) }
		else { C.vox_gl_hint(operation.args[0], operation.args[1]) }
	}
}

fn raster_enum_source_reset() {
	C.vox_gl_cull_face(back)
	C.vox_gl_depth_func(less)
	C.vox_gl_front_face(ccw)
	C.vox_gl_hint(generate_mipmap_hint, dont_care)
	assert C.vox_gl_get_error() == no_error
}

fn test_source_raster_enum_setters_delegate_actual_driver_state_errors_and_owner() {
	operations := [
		RasterEnumSourceCase{'cull', [GLenum(0xbad)]},
		RasterEnumSourceCase{'cull', [front]},
		RasterEnumSourceCase{'cull', [front_and_back]},
		RasterEnumSourceCase{'depth', [GLenum(0xbad)]},
		RasterEnumSourceCase{'depth', [gequal]},
		RasterEnumSourceCase{'depth', [never]},
		RasterEnumSourceCase{'front', [GLenum(0xbad)]},
		RasterEnumSourceCase{'front', [cw]},
		RasterEnumSourceCase{'front', [ccw]},
		RasterEnumSourceCase{'hint', [generate_mipmap_hint, nicest]},
		RasterEnumSourceCase{'hint', [generate_mipmap_hint, GLenum(0xbad)]},
		RasterEnumSourceCase{'hint', [GLenum(0xbad), fastest]},
		RasterEnumSourceCase{'hint', [GLenum(0xbad), GLenum(0xbad)]},
		RasterEnumSourceCase{'hint', [fragment_shader_derivative_hint, fastest]},
		RasterEnumSourceCase{'hint', [fragment_shader_derivative_hint, GLenum(0xbad)]},
	]
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for extension_requested in [false, true] {
			if extension_requested && version == .webgl1 {
				context.get_extension('OES_standard_derivatives', false) or { panic('native derivative extension') }
			}
			for operation in operations {
				context.native.make_current()
				raster_enum_source_reset()
				raster_enum_source_direct(operation)
				expected_error := C.vox_gl_get_error()
				expected_state := raster_enum_source_state()
				raster_enum_source_reset()
				context.set_error(invalid_value)
				other.native.make_current()
				match operation.method {
					'cull' { context.cull_face(operation.args[0]) }
					'depth' { context.depth_func(operation.args[0]) }
					'front' { context.front_face(operation.args[0]) }
					else { context.hint(operation.args[0], operation.args[1]) }
				}
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(viewport, &selected[0])
				assert selected == [i32(1), 2, 3, 4]!
				assert raster_enum_source_state() == expected_state
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_value
				assert context.get_error() == no_error
			}
		}
		assert other.get_error() == no_error
	}
}
