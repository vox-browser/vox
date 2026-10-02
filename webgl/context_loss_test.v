module webgl

import webidl

@[heap]
struct ContextLossXRTasks {
mut:
	steps []fn ()
}

fn (mut tasks ContextLossXRTasks) run_next() {
	step := tasks.steps[0]
	tasks.steps.delete(0)
	step()
}

fn test_compositor_loss_reports_one_shot_error_and_suppresses_commands() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.native.set_native_call_recording(true)
	context.lose_context_from_compositor_loss()
	assert context.is_context_lost()
	assert context.native.is_lost()
	assert context.get_error() == context_lost_webgl
	assert context.get_error() == no_error
	assert context.take_context_events().map(it.type_) == ['webglcontextlost']

	context.clear(0x4000)
	assert context.native.native_calls().len == 0
	assert !context.prepare_for_compositing()
	assert !context.restore_context_after_compositor_reconnect()
}

fn test_requested_context_restore_advances_generation_and_resets_state() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	old_buffer := context.create_buffer()
	context.pixel_storei(unpack_alignment, 8)
	context.pixel_storei(unpack_row_length, 12)
	context.lose_context_from_compositor_loss()
	context.request_context_restore()
	assert context.restore_context_after_compositor_reconnect()

	assert !context.is_context_lost()
	assert !context.native.is_lost()
	assert context.context_generation() == 1
	assert !context.is_buffer(old_buffer)
	assert context.get_parameter(unpack_alignment).integer == 4
	assert context.get_parameter(unpack_row_length).integer == 0
	assert context.take_context_events().map(it.type_) == ['webglcontextlost', 'webglcontextrestored']
}

fn test_context_size_clamping_content_updates_and_xr_compatibility() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(0, max_webgl_drawing_buffer_dimension + 1)
	assert context.drawing_buffer_width() == 1
	assert context.drawing_buffer_height() == max_webgl_drawing_buffer_dimension

	context.did_update_canvas_content()
	assert context.needs_to_present()
	mut tasks := &ContextLossXRTasks{}
	schedule := fn [mut tasks] (steps fn ()) { tasks.steps << steps }
	promise := context.make_xr_compatible(webidl.PromiseContext{}, schedule, schedule)
	assert promise.state == .pending
	assert !context.xr_compatible()
	tasks.run_next()
	assert promise.state == .pending
	assert !context.xr_compatible()
	tasks.run_next()
	assert promise.state == .fulfilled
	assert context.xr_compatible()

	context.lose_context_from_compositor_loss()
	rejected := context.make_xr_compatible(webidl.PromiseContext{}, schedule, schedule)
	assert rejected.state == .pending
	tasks.run_next()
	assert context.xr_compatible()
	tasks.run_next()
	assert rejected.state == .rejected
	exception := rejected.result.dom_exception_ or { panic('DOMException') }
	assert exception.name() == 'InvalidStateError'
	assert exception.message() == 'The WebGL context has been lost.'
	assert !context.xr_compatible()
}
