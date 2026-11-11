module webaudio

fn test_offline_render_can_retry_after_buffer_validation_fails() {
	mut context := new_offline_audio_context(1, 1, 8, 48_000) or { panic(err) }
	// Use the public model state to make allocation fail without exhausting memory.
	context.length = 0
	failed := context.start_rendering()
	assert failed.promise.state == .rejected
	assert !context.rendering_started
	context.length = 8
	result := context.start_rendering()
	assert result.promise.state == .fulfilled
	assert (result.buffer or { panic('missing rendered buffer') }).length == 8
	assert context.rendering_started
}
