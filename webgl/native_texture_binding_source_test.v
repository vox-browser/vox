// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn source_texture_native_binding(pname GLenum) int {
	mut result := i32(0)
	C.vox_gl_int_parameter(pname, &result)
	return result
}

fn test_source_texture_binds_retain_objects_before_native_target_conflicts() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		texture := context.create_texture()
		context.bind_texture(texture_2d, texture)
		context.bind_texture(texture_cube_map, texture)
		assert context.get_parameter(texture_binding_2d).texture? == texture
		assert context.get_parameter(texture_binding_cube_map).texture? == texture
		assert source_texture_native_binding(texture_binding_2d) == int(texture.object.native_handle_)
		assert source_texture_native_binding(texture_binding_cube_map) == 0
		assert context.get_error() == invalid_operation
		foreign := other.create_texture()
		context.bind_texture(0xbad, foreign)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
		context.bind_texture(0xbad, texture)
		assert context.get_error() == invalid_enum
		assert context.get_parameter(texture_binding_cube_map).texture? == texture
		for target in [texture_3d, texture_2d_array] {
			context.bind_texture(target, texture)
			if version == .webgl2 {
				pname := if target == texture_3d {
					texture_binding_3d
				} else {
					texture_binding_2d_array
				}
				assert context.get_parameter(pname).texture? == texture
				assert source_texture_native_binding(pname) == 0
				assert context.get_error() == invalid_operation
			} else {
				assert target !in context.bound_texture_objects
				assert context.get_error() == invalid_enum
			}
		}
		replacement := context.create_texture()
		C.vox_gl_bind_buffer(0xbad, 0)
		context.bind_texture(texture_2d, replacement)
		assert context.get_parameter(texture_binding_2d).texture? == replacement
		assert source_texture_native_binding(texture_binding_2d) == int(replacement.object.native_handle_)
		assert context.get_error() == invalid_enum
		context.delete_texture(texture)
		assert context.get_parameter(texture_binding_2d).texture? == replacement
		assert context.get_parameter(texture_binding_cube_map).kind == .none
		assert context.bound_texture_objects.len == 1
		assert context.get_error() == no_error
		other.native.make_current()
		context.delete_texture(texture)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
		other.native.make_current()
		context.delete_texture(foreign)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
	}
}
