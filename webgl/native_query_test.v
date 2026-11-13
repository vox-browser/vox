module webgl

fn native_query_program(mut context WebGLRenderingContext) {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nvoid main() { vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2); gl_Position=vec4(p*2.0-1.0,0.0,1.0); }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; out vec4 color; void main() { color=vec4(1.0); }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	assert context.get_shader_parameter(vertex, compile_status).boolean
	assert context.get_shader_parameter(fragment, compile_status).boolean
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
}

fn test_native_occlusion_queries_report_drawn_samples_and_empty_draws() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(4, 4)
	native_query_program(mut context)
	mut visible := context.create_query()
	mut empty := context.create_query()
	assert visible.object.native_handle_ != 0
	context.begin_query(any_samples_passed, mut visible)
	context.draw_arrays(0x0004, 0, 3)
	context.end_query(any_samples_passed)
	context.begin_query(any_samples_passed_conservative, mut empty)
	context.draw_arrays(0x0004, 0, 0)
	context.end_query(any_samples_passed_conservative)
	context.finish()
	assert context.get_query_parameter(visible, query_result_available)? == 1
	assert context.get_query_parameter(visible, query_result)? == 1
	assert context.get_query_parameter(empty, query_result_available)? == 1
	assert context.get_query_parameter(empty, query_result)? == 0
	assert context.get_error() == no_error
	context.begin_query(any_samples_passed, mut visible)
	assert context.get_query_parameter(visible, query_result_available)? == 0
	assert context.get_error() == invalid_operation
	context.end_query(any_samples_passed)
	context.get_query_parameter(visible, 0xbad)
	assert context.get_error() == invalid_enum
	context.begin_query(transform_feedback_primitives_written, mut visible)
	assert context.get_error() == invalid_operation
	context.delete_query(visible)
	assert visible.object.invalidated()
	assert context.get_query_parameter(visible, query_result) == none
	assert context.get_error() == invalid_operation
	assert context.get_error() == no_error
}

fn test_native_queries_reject_foreign_objects_before_gpu_dispatch() {
	mut owner := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut query := owner.create_query()
	other.begin_query(any_samples_passed, mut query)
	assert other.get_error() == invalid_operation
	assert other.get_query_parameter(query, query_result) == none
	assert other.get_error() == invalid_operation
	other.delete_query(query)
	assert other.get_error() == invalid_operation
	assert !query.object.invalidated()
}
