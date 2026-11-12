module webgl

fn state_native_program(mut context WebGLRenderingContext) {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nin vec2 position; void main() { gl_Position=vec4(position, -1.0, 1.0); }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; out vec4 color; void main() { color=vec4(1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.bind_attrib_location(program, 0, 'position')
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	buffer := context.create_buffer()
	context.bind_buffer(array_buffer, buffer)
	vertices := [f32(-1), -1, 3, -1, -1, 3]
	bytes := unsafe { (&u8(vertices.data)).vbytes(vertices.len * 4).clone() }
	context.buffer_data(array_buffer, bytes, 0x88e4)
	context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 0)
	context.enable_vertex_attrib_array(0)
}

fn state_native_pixel(mut context WebGLRenderingContext) []u8 {
	return context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte)
}

fn test_native_blend_cull_and_depth_commands_affect_rasterization() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(2, 2)
	state_native_program(mut context)
	context.enable(blend)
	context.blend_color(0.25, 0.75, 0.5, 1)
	context.blend_func(constant_color, gl_zero)
	context.blend_equation_separate(func_add, func_add)
	context.draw_arrays(0x0004, 0, 3)
	assert state_native_pixel(mut context) == [u8(64), 191, 128, 255]
	context.disable(blend)
	context.clear_color(0, 0, 0, 1)
	context.clear(0x4000)
	context.enable(cull_face)
	context.cull_face(front)
	context.draw_arrays(0x0004, 0, 3)
	assert state_native_pixel(mut context) == [u8(0), 0, 0, 255]
	context.front_face(cw)
	context.draw_arrays(0x0004, 0, 3)
	assert state_native_pixel(mut context) == [u8(255), 255, 255, 255]
	context.disable(cull_face)
	context.enable(depth_test)
	context.depth_range(0.25, 0.75)
	context.depth_func(greater)
	context.clear_depth(0.1)
	context.clear(0x4100)
	context.draw_arrays(0x0004, 0, 3)
	assert state_native_pixel(mut context) == [u8(255), 255, 255, 255]
	context.finish()
	context.flush()
	assert context.get_error() == no_error
}

fn test_native_fractional_state_and_integer_attributes_retain_exact_types() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.blend_color(0.25, 0.75, 0.5, 1)
	context.depth_range(0.25, 0.75)
	context.line_width(1.5)
	context.polygon_offset(0.125, -2.75)
	context.sample_coverage(0.625, true)
	mut values := []f32{len: 4}
	C.vox_gl_float_parameter(blend_color, values.data)
	assert values == [f32(0.25), 0.75, 0.5, 1]
	C.vox_gl_float_parameter(depth_range, values.data)
	assert values[..2] == [f32(0.25), 0.75]
	C.vox_gl_float_parameter(line_width, values.data)
	assert values[0] == 1.5
	C.vox_gl_float_parameter(polygon_offset_factor, values.data)
	assert values[0] == 0.125
	C.vox_gl_float_parameter(polygon_offset_units, values.data)
	assert values[0] == -2.75
	C.vox_gl_float_parameter(sample_coverage_value, values.data)
	assert values[0] == 0.625
	context.active_texture(texture0 + 3)
	mut integer := i32(0)
	C.vox_gl_int_parameter(active_texture, &integer)
	assert integer == int(texture0 + 3)
	context.active_texture(0)
	assert context.get_error() == invalid_enum
	assert context.get_parameter(active_texture).integer == texture0 + 3
	context.vertex_attrib_i4i(2, 2_000_000_001, -2_000_000_001, 7, -9)
	mut signed := []i32{len: 4}
	C.vox_gl_vertex_attrib_int_parameter(2, signed.data)
	assert signed == [i32(2_000_000_001), -2_000_000_001, 7, -9]
	context.vertex_attrib_i4ui(3, 0xffff_ffff, 0xfedc_ba98, 7, 9)
	mut unsigned := []u32{len: 4}
	C.vox_gl_vertex_attrib_uint_parameter(3, unsigned.data)
	assert unsigned == [u32(0xffff_ffff), 0xfedc_ba98, 7, 9]
	assert context.get_error() == no_error
}

fn test_native_clear_buffer_values_and_source_minimum_span_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(2, 2)
	context.clear_bufferfv(0x1800, 0, [f32(0.25), 0.75, 0.5, 1])
	assert state_native_pixel(mut context) == [u8(64), 191, 128, 255]
	context.clear_bufferfv(0x1800, 0, [f32(1), 0, 0])
	assert context.get_error() == invalid_value
	context.clear_bufferiv(0x1802, 0, []int{})
	assert context.get_error() == invalid_value
	context.clear_bufferuiv(0x1800, 0, [u32(1)])
	assert context.get_error() == invalid_value
	context.clear_bufferfv(0xdead, 0, [f32(0)])
	assert context.get_error() == invalid_enum
	assert state_native_pixel(mut context) == [u8(64), 191, 128, 255]
	assert context.get_error() == no_error
}
