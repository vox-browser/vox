// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct VertexPointerSourceCase {
	index      GLuint
	size       int    = 2
	type_      GLenum = gl_float
	normalized bool
	stride     int
	offset     i64
}

fn vertex_pointer_source_driver_state() []i64 {
	mut values := []i64{}
	for pname in [vertex_attrib_array_size, vertex_attrib_array_type, vertex_attrib_array_normalized,
		vertex_attrib_array_stride, vertex_attrib_array_buffer_binding] {
		values << i64(C.vox_gl_vertex_attrib_parameter(0, pname))
	}
	values << C.vox_gl_vertex_attrib_offset(0)
	return values
}

fn test_vertex_pointer_preserves_only_source_retained_slot_gate_and_native_validation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		buffer := context.create_buffer()
		cases := [VertexPointerSourceCase{},
			VertexPointerSourceCase{ size: 4, type_: unsigned_byte, normalized: true, stride: 16, offset: 4 },
			VertexPointerSourceCase{ size: 0 }, VertexPointerSourceCase{ size: 5 },
			VertexPointerSourceCase{ stride: -1 }, VertexPointerSourceCase{ stride: 256 },
			VertexPointerSourceCase{ offset: -1 }, VertexPointerSourceCase{ offset: 1 },
			VertexPointerSourceCase{ size: 0, stride: -1, offset: 4 },
			VertexPointerSourceCase{ type_: GLenum(0xffff) },
			VertexPointerSourceCase{ index: GLuint(0xffff_ffff) }]
		for bound in [false, true] {
			if bound {
				context.bind_buffer(array_buffer, buffer)
			} else {
				context.bind_buffer(array_buffer, none)
			}
			for item in cases {
				context.native.make_current()
				C.vox_gl_bind_buffer(array_buffer, buffer.object.native_handle_)
				C.vox_gl_vertex_attrib_pointer(0, 4, gl_float, 0, 0, 0)
				C.vox_gl_bind_buffer(array_buffer, if bound {
					buffer.object.native_handle_
				} else {
					0
				})
				assert C.vox_gl_get_error() == no_error
				if !bound && item.offset != 0 {
					other.native.make_current()
					context.vertex_attrib_pointer(item.index, item.size, item.type_, item.normalized, item.stride, item.offset)
					mut selected := [i32(0), 0, 0, 0]!
					C.vox_gl_int_parameter(viewport, &selected[0])
					assert selected == [i32(9), 10, 11, 12]!
					assert context.error_ == invalid_operation
					assert context.get_error() == invalid_operation
					assert other.get_error() == no_error
					continue
				}
				C.vox_gl_vertex_attrib_pointer(item.index, item.size, item.type_, int(item.normalized), item.stride, item.offset)
				expected_error := C.vox_gl_get_error()
				expected := vertex_pointer_source_driver_state()
				C.vox_gl_bind_buffer(array_buffer, buffer.object.native_handle_)
				C.vox_gl_vertex_attrib_pointer(0, 4, gl_float, 0, 0, 0)
				C.vox_gl_bind_buffer(array_buffer, if bound {
					buffer.object.native_handle_
				} else {
					0
				})
				context.set_error(invalid_operation)
				other.native.make_current()
				context.vertex_attrib_pointer(item.index, item.size, item.type_, item.normalized, item.stride, item.offset)
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(viewport, &selected[0])
				assert selected == [i32(1), 2, 3, 4]!
				assert vertex_pointer_source_driver_state() == expected
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_operation
				assert context.get_error() == no_error
				assert other.get_error() == no_error
			}
		}
		// The Source slot retains the actual invalidated object after deletion;
		// that non-null record still allows the pointer command to reach GL.
		context.delete_buffer(buffer)
		C.vox_gl_vertex_attrib_pointer(0, 2, gl_float, 0, 0, 4)
		deleted_driver_error := C.vox_gl_get_error()
		C.vox_gl_vertex_attrib_pointer(0, 4, gl_float, 0, 0, 0)
		assert C.vox_gl_get_error() == no_error
		other.native.make_current()
		context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 4)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == deleted_driver_error
	}
}
