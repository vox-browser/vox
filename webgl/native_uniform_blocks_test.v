module webgl

fn uniform_blocks_program(mut context WebGLRenderingContext) &WebGLProgram {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nlayout(std140) uniform Globals { mat4 transform; vec4 tint[2]; }; in vec2 position; uniform float ordinary; out vec4 shade; void main() { gl_Position=transform*vec4(position,0.0,1.0); shade=tint[0]+tint[1]*ordinary; }')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float; in vec4 shade; out vec4 color; void main() { color=shade; }')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert program.linked_
	return program
}

fn test_native_uniform_block_indices_layout_names_binding_and_members() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	program := uniform_blocks_program(mut context)
	block := context.get_uniform_block_index(program, 'Globals')
	assert block != u32(0xffff_ffff)
	assert context.get_uniform_block_index(program, 'made_up_block') == u32(0xffff_ffff)
	assert context.get_active_uniform_block_name(program, block)? == 'Globals'
	indices := context.get_uniform_indices(program, ['transform', 'tint[0]', 'ordinary', 'missing'])
	assert indices.len == 4
	for index in indices[..3] {
		assert index != u32(0xffff_ffff)
	}
	assert indices[3] == u32(0xffff_ffff)
	assert context.get_active_uniforms(program, indices[..3], uniform_type).integers == [
		i64(0x8b5c),
		0x8b52,
		0x1406,
	]
	assert context.get_active_uniforms(program, indices[..3], uniform_size).integers == [
		i64(1),
		2,
		1,
	]
	assert context.get_active_uniforms(program, indices[..3], uniform_block_index).integers == [
		i64(block),
		i64(block),
		-1,
	]
	assert context.get_active_uniforms(program, indices[..2], uniform_offset).integers == [
		i64(0),
		64,
	]
	assert context.get_active_uniforms(program, indices[..2], uniform_matrix_stride).integers == [
		i64(16),
		0,
	]
	assert context.get_active_uniforms(program, indices[..2], uniform_array_stride).integers == [
		i64(0),
		16,
	]
	assert context.get_active_uniforms(program, indices[..2], uniform_is_row_major).booleans == [
		false,
		false,
	]
	assert context.get_active_uniform_block_parameter(program, block, uniform_block_data_size).integer == 96
	assert context.get_active_uniform_block_parameter(program, block, uniform_block_active_uniforms).integer == 2
	assert context.get_active_uniform_block_parameter(program, block, uniform_block_referenced_by_vertex_shader).boolean
	assert !context.get_active_uniform_block_parameter(program, block, uniform_block_referenced_by_fragment_shader).boolean
	mut actual_indices := context.get_active_uniform_block_parameter(program, block, uniform_block_active_uniform_indices).integers.clone()
	mut expected_indices := indices[..2].map(i64(it))
	actual_indices.sort()
	expected_indices.sort()
	assert actual_indices == expected_indices
	context.uniform_block_binding(program, block, 3)
	assert context.get_active_uniform_block_parameter(program, block, uniform_block_binding).integer == 3
	assert context.get_error() == no_error
	assert context.get_active_uniforms(program, indices[..1], 0xdead).kind == .none
	assert context.get_error() == invalid_enum
	context.get_active_uniform_block_parameter(program, 999, uniform_block_binding)
	assert context.get_error() == invalid_value
	mut foreign := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	assert foreign.get_uniform_block_index(program, 'Globals') == u32(0xffff_ffff)
	assert foreign.get_error() == invalid_operation
	assert foreign.get_active_uniform_block_name(program, block) == none
	assert foreign.get_error() == invalid_operation
}

fn test_native_internalformat_sample_counts_are_real_and_query_errors_reject() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	counts := context.get_internalformat_parameter(renderbuffer, 0x8058, samples)
	assert counts.kind == .integers
	assert counts.integers.len > 0
	for value in counts.integers {
		assert value > 0
	}
	assert context.get_error() == no_error
	assert context.get_internalformat_parameter(renderbuffer, 0x8058, num_sample_counts).kind == .none
	assert context.get_error() == invalid_enum
}
