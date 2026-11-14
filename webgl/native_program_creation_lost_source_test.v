// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_create_program_retains_owned_proxy_ids_without_native_dispatch() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		original := owner.create_program()
		sentinel := other.create_program()
		assert original.object.native_name() != 0
		assert original.object.native_name() == sentinel.object.native_name()
		assert original.object.handle(owner.identity(), owner.context_generation())! == 1
		owner.lose_context_from_compositor_loss()
		assert owner.native.is_lost()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		mut records := []&WebGLProgram{}
		for index in 0 .. 3 {
			program := owner.create_program()
			assert program != original
			assert program.object.native_name() == 0
			assert owner.owns(&program.object)
			assert !program.object.invalidated()
			assert program.object.handle(owner.identity(), owner.context_generation())! == u32(index + 2)
			optional := program.object.handle_for_query(owner.identity(), owner.context_generation())!
			assert optional.has_value
			assert optional.value == u32(index + 2)
			assert owner.programs[program.object.bookkeeping_id()] == program
			for earlier in records {
				assert earlier != program
			}
			records << program
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_is_object(10, sentinel.object.native_name()) == 1
		}
		assert C.vox_gl_get_error() == invalid_value
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		owner.request_context_restore()
		assert owner.restore_context_after_compositor_reconnect()
		assert !owner.owns(&original.object)
		for program in records {
			assert !owner.owns(&program.object)
		}
		restored := owner.create_program()
		assert restored.object.handle(owner.identity(), owner.context_generation())! == 5
		assert restored.object.native_name() != 0
		assert C.vox_gl_is_object(10, restored.object.native_name()) == 1
		assert owner.get_error() == no_error
	}
}
