// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_texture_getter_preserves_source_extension_version_gates_and_driver_owner() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut early_names := [GLenum(0xffff), GLenum(0x84fe)]
		mut names := [texture_mag_filter, texture_min_filter, texture_wrap_s, texture_wrap_t]
		webgl2_names := [GLenum(0x813c), 0x884d, 0x884c, 0x82df, 0x813d, 0x8072, 0x912f, 0x813b,
			0x813a]
		if version == .webgl1 {
			early_names << webgl2_names
		} else {
			names << webgl2_names
		}
		for pname in early_names {
			context.native.make_current()
			C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
			other.native.make_current()
			assert context.get_tex_parameter(GLenum(0xffff), pname).kind == .none
			mut selected := [0, 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [9, 10, 11, 12]!
			assert C.vox_gl_get_error() == no_error
			assert context.get_error() == invalid_value
			assert context.get_error() == invalid_enum
			assert context.get_error() == no_error
		}
		context.native.make_current()
		native_texture := C.vox_gl_gen_object(3)
		C.vox_gl_bind_texture(texture_2d, native_texture)
		if version == .webgl2 {
			C.vox_gl_tex_storage2d(texture_2d, 1, 0x8058, 2, 2)
			C.vox_gl_tex_parameterf(texture_2d, 0x813b, 9.5)
			C.vox_gl_tex_parameterf(texture_2d, 0x813a, -2.5)
		}
		assert texture_2d !in context.bound_texture_objects
		assert C.vox_gl_get_error() == no_error
		if _ := context.get_extension('EXT_texture_filter_anisotropic', false) {
			println('actual native anisotropy extension enabled')
			names << GLenum(0x84fe)
		}
		for target in [texture_2d, GLenum(0xffff)] {
			for pname in names {
				context.native.make_current()
				is_lod := pname in [GLenum(0x813b), GLenum(0x813a)]
				query_name := if is_lod { GLenum(0x912f) } else { pname }
				expected := if is_lod {
					f64(C.vox_gl_tex_float_parameter(target, query_name))
				} else {
					f64(C.vox_gl_tex_parameter(target, query_name))
				}
				expected_error := C.vox_gl_get_error()
				context.set_error(invalid_operation)
				other.native.make_current()
				result := context.get_tex_parameter(target, pname)
				mut selected := [0, 0, 0, 0]!
				C.vox_gl_int_parameter(viewport, &selected[0])
				assert selected == [1, 2, 3, 4]!
				if is_lod || pname == GLenum(0x912f) {
					assert result.kind == .boolean
					assert result.boolean == (expected == 1)
				} else {
					assert result.kind == .integer
					assert result.integer == i64(expected)
				}
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_operation
				assert context.get_error() == no_error
			}
		}
		context.native.make_current()
		C.vox_gl_delete_object(3, native_texture)
	}
}
