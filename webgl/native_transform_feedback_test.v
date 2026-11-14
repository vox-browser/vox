module webgl

fn test_native_transform_feedback_flags_are_webgl2_only_and_initially_false() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	assert !context.is_context_lost()
	for parameter in [transform_feedback_active, transform_feedback_paused] {
		value := context.get_parameter(parameter)
		assert value.kind == .boolean
		assert !value.boolean
	}
	assert context.get_error() == no_error

	mut legacy := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	assert !legacy.is_context_lost()
	for parameter in [transform_feedback_active, transform_feedback_paused] {
		assert legacy.get_parameter(parameter).kind == .none
		assert legacy.get_error() == invalid_enum
	}
}

fn native_tf_program(mut context WebGLRenderingContext) &WebGLProgram {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nout float doubled; void main() { doubled=float(gl_VertexID+1)*2.0; gl_Position=vec4(0.0); }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; out vec4 color; void main() { color=vec4(1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.transform_feedback_varyings(program, ['doubled'], 0x8c8c)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	return program
}

fn test_native_transform_feedback_captures_gpu_outputs_and_query_counts() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	program := native_tf_program(mut context)
	assert context.get_program_parameter(program, transform_feedback_varyings).integer == 1
	assert context.get_program_parameter(program, transform_feedback_buffer_mode).integer == 0x8c8c
	mut feedback := context.create_transform_feedback()
	assert feedback.object.native_handle_ != 0
	context.bind_transform_feedback(transform_feedback, feedback)
	output := context.create_buffer()
	context.bind_buffer(transform_feedback_buffer, output)
	context.buffer_data_size(transform_feedback_buffer, 20, 0x88e8)
	context.bind_buffer_range(transform_feedback_buffer, 0, output, 4, 12)
	context.enable(rasterizer_discard)
	mut query := context.create_query()
	context.begin_query(transform_feedback_primitives_written, mut query)
	context.begin_transform_feedback(0)
	assert context.get_parameter(transform_feedback_active).boolean
	assert !context.get_parameter(transform_feedback_paused).boolean
	context.draw_arrays(0, 0, 1)
	context.pause_transform_feedback()
	assert context.get_parameter(transform_feedback_paused).boolean
	context.draw_arrays(0, 1, 1)
	context.resume_transform_feedback()
	context.draw_arrays(0, 2, 1)
	context.end_transform_feedback()
	context.end_query(transform_feedback_primitives_written)
	context.finish()
	assert context.get_query_parameter(query, query_result)? == 2
	assert !context.get_parameter(transform_feedback_active).boolean
	mut bytes := []u8{len: 20}
	context.get_buffer_sub_data(transform_feedback_buffer, 0, mut bytes, 0, 0)
	mut values := []f32{len: 5}
	for index in 0 .. values.len { values[index] = unsafe { (&f32(bytes.data))[index] } }
	assert values == [f32(0), 2, 6, 0, 0]
	assert context.get_error() == no_error
	context.delete_transform_feedback(feedback)
	assert feedback.object.invalidated()
	context.bind_transform_feedback(transform_feedback, none)
	context.bind_buffer_base(transform_feedback_buffer, 0, output)
	context.begin_transform_feedback(0)
	context.draw_arrays(0, 1, 1)
	context.end_transform_feedback()
	context.get_buffer_sub_data(transform_feedback_buffer, 0, mut bytes, 0, 0)
	assert unsafe { (&f32(bytes.data))[0] } == 4
	assert context.get_error() == no_error
}

fn test_native_transform_feedback_does_not_invent_active_success() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.begin_transform_feedback(0)
	assert context.get_error() == invalid_operation
	assert !context.get_parameter(transform_feedback_active).boolean
	context.pause_transform_feedback()
	assert context.get_error() == invalid_operation
	context.bind_buffer_base(0xbad, 0, none)
	assert context.get_error() == invalid_enum
}
