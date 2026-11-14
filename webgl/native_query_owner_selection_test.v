// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct QueryOwnerSelectionCase {
	name  string
	steps fn () @[required]
	error GLenum
}

fn run_query_owner_selection_case(mut owner WebGLRenderingContext, mut other WebGLRenderingContext, test_case QueryOwnerSelectionCase) {
	other.native.make_current()
	test_case.steps()
	mut viewport_state := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &viewport_state[0])
	// These reviewed Source bodies return before issuing a sync query. Other
	// historical cases stay scoped to their separate implementation reviews.
	expected_owner := if test_case.name in ['getRenderbufferParameter(unknown)',
		'getTexParameter(unknown)', 'getAttribLocation(foreign)', 'getSyncParameter(foreign)', 'isShader(null)', 'isProgram(null)',
		'getParameter(browser state)', 'getParameter(unknown)'] {
		[i32(9), 10, 11, 12]!
	} else {
		[i32(1), 2, 3, 4]!
	}
	if viewport_state != expected_owner {
		panic('${test_case.name} selected ${viewport_state}; expected ${expected_owner}')
	}
	actual_error := owner.get_error()
	assert actual_error == test_case.error
	remaining := owner.get_error()
	assert remaining == no_error
}

fn test_queries_preserve_reviewed_early_return_and_native_driver_owners() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		foreign_buffer := other.create_buffer()
		foreign_program := other.create_program()
		mut cases := [
			QueryOwnerSelectionCase{'isBuffer(null)', fn [mut owner] () { owner.is_buffer(none) }, no_error},
			QueryOwnerSelectionCase{'isFramebuffer(null)', fn [mut owner] () {
				owner.is_framebuffer(none)
			}, no_error},
			QueryOwnerSelectionCase{'isRenderbuffer(null)', fn [mut owner] () {
				owner.is_renderbuffer(none)
			}, no_error},
			QueryOwnerSelectionCase{'isTexture(null)', fn [mut owner] () { owner.is_texture(none) }, no_error},
			QueryOwnerSelectionCase{'isShader(null)', fn [mut owner] () { owner.is_shader(none) }, no_error},
			QueryOwnerSelectionCase{'isProgram(null)', fn [mut owner] () { owner.is_program(none) }, no_error},
			QueryOwnerSelectionCase{'isBuffer(foreign)', fn [mut owner, foreign_buffer] () {
				owner.is_buffer(foreign_buffer)
			}, invalid_operation},
			QueryOwnerSelectionCase{'getParameter(browser state)', fn [mut owner] () {
				owner.get_parameter(unpack_flip_y_webgl)
			}, no_error},
			QueryOwnerSelectionCase{'getParameter(unknown)', fn [mut owner] () {
				owner.get_parameter(GLenum(0xbad))
			}, invalid_enum},
			QueryOwnerSelectionCase{'getRenderbufferParameter(unknown)', fn [mut owner] () {
				owner.get_renderbuffer_parameter(renderbuffer, GLenum(0xbad))
			}, invalid_enum},
			QueryOwnerSelectionCase{'getTexParameter(unknown)', fn [mut owner] () {
				owner.get_tex_parameter(texture_2d, GLenum(0xbad))
			}, invalid_enum},
			QueryOwnerSelectionCase{'getFramebufferAttachmentParameter(unknown target)', fn [mut owner] () {
				owner.get_framebuffer_attachment_parameter(GLenum(0xbad), color_attachment0, framebuffer_attachment_object_type)
			}, invalid_enum},
			QueryOwnerSelectionCase{'getAttribLocation(foreign)', fn [mut owner, foreign_program] () {
				owner.get_attrib_location(foreign_program, 'position')
			}, invalid_operation},
		]
		if version == .webgl1 {
			owner.get_extension('OES_vertex_array_object', false) or { panic('owner OES extension') }
			other.get_extension('OES_vertex_array_object', false) or { panic('other OES extension') }
			foreign_oes := other.create_vertex_array_oes()
			cases << [
				QueryOwnerSelectionCase{'isVertexArrayOES(null)', fn [mut owner] () {
					owner.is_vertex_array_oes(none)
				}, no_error},
				QueryOwnerSelectionCase{'isVertexArrayOES(foreign)', fn [mut owner, foreign_oes] () {
					owner.is_vertex_array_oes(foreign_oes)
				}, no_error},
			]
		}
		if version == .webgl2 {
			foreign_query := other.create_query()
			foreign_sync := other.fence_sync(sync_gpu_commands_complete, 0) or { panic('foreign fence') }
			cases << [
				QueryOwnerSelectionCase{'isVertexArray(null)', fn [mut owner] () {
					owner.is_vertex_array(none)
				}, no_error},
				QueryOwnerSelectionCase{'getQueryParameter(foreign)', fn [mut owner, foreign_query] () {
					owner.get_query_parameter(foreign_query, query_result)
				}, invalid_operation},
				QueryOwnerSelectionCase{'getSyncParameter(foreign)', fn [mut owner, foreign_sync] () {
					owner.get_sync_parameter(foreign_sync, sync_status)
				}, invalid_operation},
				QueryOwnerSelectionCase{'getUniformIndices(foreign)', fn [mut owner, foreign_program] () {
					owner.get_uniform_indices_nullable(foreign_program, [])
				}, invalid_operation},
				QueryOwnerSelectionCase{'getActiveUniforms(foreign)', fn [mut owner, foreign_program] () {
					owner.get_active_uniforms(foreign_program, [], uniform_type)
				}, invalid_operation},
				QueryOwnerSelectionCase{'getUniformBlockIndex(foreign)', fn [mut owner, foreign_program] () {
					owner.get_uniform_block_index(foreign_program, 'Block')
				}, invalid_operation},
				QueryOwnerSelectionCase{'getActiveUniformBlockParameter(foreign)', fn [mut owner, foreign_program] () {
					owner.get_active_uniform_block_parameter(foreign_program, 0, uniform_block_binding)
				}, invalid_operation},
				QueryOwnerSelectionCase{'getActiveUniformBlockName(foreign)', fn [mut owner, foreign_program] () {
					owner.get_active_uniform_block_name(foreign_program, 0)
				}, invalid_operation},
			]
		}
		for test_case in cases { run_query_owner_selection_case(mut owner, mut other, test_case) }
		other_error := other.get_error()
		assert other_error == no_error
	}
}
