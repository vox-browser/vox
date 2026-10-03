module webgl

fn native_draw_float_bytes(values []f32) []u8 {
	return unsafe { (&u8(values.data)).vbytes(values.len * 4).clone() }
}

fn native_draw_program(mut context WebGLRenderingContext, vertex_source string, fragment_source string) &WebGLProgram {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, vertex_source)
	context.shader_source(mut fragment, fragment_source)
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	assert vertex.compiled_
	assert fragment.compiled_
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.bind_attrib_location(program, 0, 'position')
	context.link_program(mut program)
	assert program.linked_
	context.use_program(program)
	return program
}

fn native_draw_assert_pixels(mut context WebGLRenderingContext, expected []u8) {
	pixels := context.read_pixels(0, 0, 8, 8, rgba, unsigned_byte)
	assert pixels.len == 8 * 8 * 4
	for offset := 0; offset < pixels.len; offset += 4 {
		assert pixels[offset..offset + 4] == expected
	}
	assert context.get_error() == no_error
}

fn test_native_buffers_are_uploaded_copied_mapped_and_validate_real_ranges() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	source := context.create_buffer()
	destination := context.create_buffer()
	assert source.object.native_handle_ != 0
	context.bind_buffer(copy_read_buffer, source)
	context.buffer_data(copy_read_buffer, [u8(1), 2, 3, 4, 5, 6], 0x88e4)
	context.bind_buffer(copy_write_buffer, destination)
	context.buffer_data_size(copy_write_buffer, 6, 0x88e8)
	mut zeros := []u8{len: 6, init: 255}
	context.get_buffer_sub_data(copy_write_buffer, 0, mut zeros, 0, 0)
	assert zeros == []u8{len: 6}
	context.copy_buffer_sub_data(copy_read_buffer, copy_write_buffer, 1, 2, 3)
	context.buffer_sub_data(copy_write_buffer, 0, [u8(9), 8])
	mut bytes := []u8{len: 8, init: 255}
	context.get_buffer_sub_data(copy_write_buffer, 0, mut bytes, 1, 6)
	assert bytes == [u8(255), 9, 8, 2, 3, 4, 0, 255]
	assert context.get_buffer_parameter(copy_write_buffer, buffer_size).integer == 6
	assert context.get_buffer_parameter(copy_write_buffer, buffer_usage).integer == 0x88e8
	assert context.get_error() == no_error
	context.bind_buffer(copy_read_buffer, destination)
	context.copy_buffer_sub_data(copy_read_buffer, copy_write_buffer, 0, 1, 4)
	assert context.get_error() == invalid_value
	context.buffer_sub_data(copy_write_buffer, 5, [u8(1), 2])
	assert context.get_error() == invalid_value
	context.buffer_data_size(copy_write_buffer, 100, 0)
	assert context.get_error() == invalid_enum
	assert context.get_buffer_parameter(copy_write_buffer, buffer_size).integer == 6
	mut mutable_destination := unsafe { &WebGLBuffer(destination) }
	mutable_destination.data_ = []u8{len: 6, init: 99}
	context.get_buffer_sub_data(copy_write_buffer, 0, mut bytes, 1, 6)
	assert bytes == [u8(255), 9, 8, 2, 3, 4, 0, 255]
	context.get_buffer_sub_data(copy_write_buffer, 6, mut bytes, 0, 1)
	assert context.get_error() == invalid_value
	context.delete_buffer(destination)
	assert context.get_parameter(copy_write_buffer).object == destination.object.handle_
	assert context.get_error() == no_error
}

fn test_webgl1_native_array_indexed_and_constant_attribute_draws() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.set_size(8, 8)
	program := native_draw_program(mut context,
		'attribute vec2 position; attribute vec4 color; varying vec4 v; void main() { gl_Position=vec4(position,0.0,1.0); v=color; }',
		'precision mediump float; varying vec4 v; void main() { gl_FragColor=v; }')
	color := context.get_attrib_location(program, 'color')
	assert color >= 0
	context.vertex_attrib4f(u32(color), 1, 0.25, 0.5, 1)
	vertices := context.create_buffer()
	context.bind_buffer(array_buffer, vertices)
	context.buffer_data(array_buffer, native_draw_float_bytes([f32(-1), -1, 3, -1, -1, 3]), 0x88e4)
	context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 0)
	context.enable_vertex_attrib_array(0)
	context.draw_arrays(0x0004, 0, 3)
	native_draw_assert_pixels(mut context, [u8(255), 64, 128, 255])
	context.buffer_data(array_buffer, native_draw_float_bytes([f32(-1), -1, 1, -1, -1, 1, 1, 1]), 0x88e4)
	indices := context.create_buffer()
	context.bind_buffer(element_array_buffer, indices)
	context.buffer_data(element_array_buffer, [u8(0), 1, 2, 2, 1, 3], 0x88e4)
	context.vertex_attrib4f(u32(color), 0, 1, 0, 1)
	context.draw_elements(0x0004, 6, unsigned_byte, 0)
	native_draw_assert_pixels(mut context, [u8(0), 255, 0, 255])
	context.draw_elements(0x0004, 7, unsigned_byte, 0)
	assert context.get_error() == invalid_operation
	context.draw_arrays(0x0004, 0, 5)
	assert context.get_error() == invalid_operation
	context.bind_buffer(copy_read_buffer, vertices)
	assert context.get_error() == invalid_enum
}

fn test_webgl2_native_instanced_draws_use_divisor_and_instance_id() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(8, 8)
	program := native_draw_program(mut context,
		'#version 300 es\nin vec2 position; in float offset; flat out int instance; void main() { gl_Position=vec4(position.x*0.5+offset,position.y,0.0,1.0); instance=gl_InstanceID; }',
		'#version 300 es\nprecision mediump float; flat in int instance; out vec4 color; void main() { color=instance==0?vec4(1,0,0,1):vec4(0,1,0,1); }')
	vertices := context.create_buffer()
	context.bind_buffer(array_buffer, vertices)
	context.buffer_data(array_buffer, native_draw_float_bytes([f32(-1), -1, 1, -1, -1, 1, 1, 1]), 0x88e4)
	context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 0)
	context.enable_vertex_attrib_array(0)
	offsets := context.create_buffer()
	context.bind_buffer(array_buffer, offsets)
	context.buffer_data(array_buffer, native_draw_float_bytes([f32(-0.5), 0.5]), 0x88e4)
	offset_location := u32(context.get_attrib_location(program, 'offset'))
	context.vertex_attrib_pointer(offset_location, 1, gl_float, false, 0, 0)
	context.enable_vertex_attrib_array(offset_location)
	context.vertex_attrib_divisor(offset_location, 1)
	context.draw_arrays_instanced(0x0005, 0, 4, 2)
	mut pixels := context.read_pixels(0, 0, 8, 8, rgba, unsigned_byte)
	for y in 0 .. 8 {
		for x in 0 .. 8 {
			assert pixels[(y * 8 + x) * 4..(y * 8 + x + 1) * 4] == if x < 4 {
				[u8(255), 0, 0, 255]
			} else {
				[u8(0), 255, 0, 255]
			}
		}
	}
	indices := context.create_buffer()
	context.bind_buffer(element_array_buffer, indices)
	context.buffer_data(element_array_buffer, [u8(0), 1, 2, 2, 1, 3], 0x88e4)
	context.clear_color(0, 0, 0, 1)
	context.clear(0x4000)
	context.draw_elements_instanced(0x0004, 6, unsigned_byte, 0, 2)
	pixels = context.read_pixels(0, 0, 8, 8, rgba, unsigned_byte)
	for y in 0 .. 8 {
		for x in 0 .. 8 {
			assert pixels[(y * 8 + x) * 4..(y * 8 + x + 1) * 4] == if x < 4 {
				[u8(255), 0, 0, 255]
			} else {
				[u8(0), 255, 0, 255]
			}
		}
	}
	assert context.get_error() == no_error
}
