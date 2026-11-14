// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_active_info_preserves_fixed_name_span_empty_driver_records_and_owner_order() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut vertex := owner.create_shader(vertex_shader) or { panic('vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('fragment') }
		// Keep the ES 1.00 fixture within its compiler's identifier range.
		name_suffix_size := if version == .webgl1 { 200 } else { 300 }
		attribute := 'position_' + 'a'.repeat(name_suffix_size)
		uniform := 'tint_' + 'b'.repeat(name_suffix_size)
		vertex_source := if version == .webgl1 {
			'attribute vec2 ${attribute};void main(){gl_Position=vec4(${attribute},0,1);}'
		} else {
			'#version 300 es\nin vec2 ${attribute};void main(){gl_Position=vec4(${attribute},0,1);}'
		}
		fragment_source := if version == .webgl1 {
			'precision mediump float;uniform vec4 ${uniform};void main(){gl_FragColor=${uniform};}'
		} else {
			'#version 300 es\nprecision mediump float;uniform vec4 ${uniform};out vec4 color;void main(){color=${uniform};}'
		}
		owner.shader_source(mut vertex, vertex_source)
		owner.shader_source(mut fragment, fragment_source)
		owner.compile_shader(mut vertex)
		owner.compile_shader(mut fragment)
		mut program := owner.create_program()
		owner.attach_shader(mut program, vertex)
		owner.attach_shader(mut program, fragment)
		owner.link_program(mut program)
		assert owner.get_program_parameter(program, link_status).boolean
		other.native.make_current()
		attrib := owner.get_active_attrib(program, 0) or { panic('source attribute') }
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		other.native.make_current()
		active := owner.get_active_uniform(program, 0) or { panic('source uniform') }
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert attrib.name == attribute[..if attribute.len < 255 { attribute.len } else { 255 }]
		assert attrib.size == 1 && attrib.type_ == 0x8b50
		assert active.name == uniform[..if uniform.len < 255 { uniform.len } else { 255 }]
		assert active.size == 1 && active.type_ == 0x8b52
		assert owner.get_error() == no_error
		invalid_attrib := owner.get_active_attrib(program, 1) or { panic('source invalid attribute') }
		assert invalid_attrib.name == '' && invalid_attrib.size == 0 && invalid_attrib.type_ == 0
		assert owner.get_error() == invalid_value
		invalid_uniform := owner.get_active_uniform(program, 1) or { panic('source invalid uniform') }
		assert invalid_uniform.name == '' && invalid_uniform.size == 0 && invalid_uniform.type_ == 0
		assert owner.get_error() == invalid_value
		foreign := other.create_program()
		owner.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		assert owner.get_active_attrib(foreign, 0) == none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert owner.get_error() == invalid_value
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		assert owner.get_active_uniform(foreign, 0) == none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert owner.get_error() == invalid_operation
		owner.delete_program(program)
		other.native.make_current()
		assert owner.get_active_attrib(program, 0) == none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		assert owner.get_active_uniform(program, 0) == none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert owner.get_error() == invalid_operation
		assert owner.get_error() == no_error
	}
}
