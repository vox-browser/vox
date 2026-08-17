module webaudio

fn test_realtime_context_state_transitions_and_destination_constraints() {
	mut context := new_audio_context(1, none, true) or { panic(err) }
	assert context.base.sample_rate == 44100
	assert context.base.state == .running
	assert context.base.destination.channel_count_mode == .explicit
	assert context.base.render_quantum_size() == 128
	assert context.base.onstatechange_count == 1
	assert context.suspend().state == .fulfilled
	assert context.base.state == .suspended
	assert context.base.onstatechange_count == 1
	assert context.resume().state == .fulfilled
	assert context.base.onstatechange_count == 1
	assert context.close().state == .fulfilled
	assert context.base.onstatechange_count == 2
	assert context.resume().state == .rejected
	context.base.set_destination_channel_count(3, false) or {
		assert err.msg().contains('IndexSizeError')
		return
	}
	assert false
}

fn test_listener_decode_and_media_element_boundaries() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.listener.set_position(1, 2, 3)
	assert context.base.listener.position_z.value() == 3
	decoded := context.base.decode_audio_data([u8(1), 2], true)
	assert decoded.promise.state == .fulfilled
	assert (decoded.buffer or { panic('missing') }).number_of_channels() == 2
	source := context.create_media_element_source('media') or { panic(err) }
	assert source.node.number_of_inputs == 0
}

fn test_offline_rendering_is_single_use_and_dispatches_completion() {
	mut context := new_offline_audio_context(3, 2, 128, 8000) or { panic(err) }
	result := context.start_rendering()
	assert result.promise.state == .fulfilled
	assert (result.buffer or { panic('missing') }).length == 128
	assert (result.event or { panic('missing') }).event_type == 'complete'
	assert context.base.state == .suspended
	assert context.start_rendering().promise.state == .rejected
	context.resume() or {
		assert err.msg().contains('NotSupportedError')
		return
	}
	assert false
}
