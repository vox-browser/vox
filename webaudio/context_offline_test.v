module webaudio

import encoding.base64

fn test_audio_context_supports_the_full_nominal_sample_rate_range() {
	low := new_audio_context(1, 3_000, true) or { panic(err) }
	high := new_audio_context(2, 768_000, true) or { panic(err) }
	assert low.base.sample_rate == 3_000
	assert high.base.sample_rate == 768_000
	new_audio_context(3, 2_999, true) or {
		assert err.msg().contains('allowed range')
		new_audio_context(4, 768_001, true) or {
			assert err.msg().contains('allowed range')
			return
		}
	}
	assert false
}

fn test_offline_destination_max_channel_count_matches_its_fixed_width() {
	context := new_offline_audio_context(91, 6, 128, 48_000) or { panic(err) }
	assert context.base.destination.channel_count == 6
	assert context.base.destination.max_channel_count() == 6

	realtime := new_audio_context(92, 48_000, true) or { panic(err) }
	assert realtime.base.destination.max_channel_count() == 2
}

fn test_realtime_context_state_transitions_and_destination_constraints() {
	mut context := new_audio_context(1, none, true) or { panic(err) }
	assert context.base.sample_rate == 44100
	assert context.base.state == .running
	assert context.base.destination.channel_count_mode == .explicit
	assert context.base.render_quantum_size() == 128
	assert context.base.onstatechange_count == 1
	assert context.suspend().state == .fulfilled
	assert context.suspended_by_user
	assert context.base.state == .suspended
	assert context.base.onstatechange_count == 1
	assert context.resume().state == .fulfilled
	assert !context.suspended_by_user
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

fn test_realtime_context_renderer_drives_current_time_and_output_timestamp() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(0.5, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut output := []f32{len: 20}
	assert context.fill_output_buffer(mut output) == []f32{len: 20, init: 0.5}
	assert context.current_time() == 128.0 / 48_000.0
	timestamp := context.get_output_timestamp()
	assert timestamp.context_time == 10.0 / 48_000.0
	assert timestamp.performance_time > 0
	assert context.suspend().state == .fulfilled
	assert context.fill_output_buffer(mut output).len == 0
	assert context.resume().state == .fulfilled
	assert context.fill_output_buffer(mut output).len == 20
}

fn test_realtime_context_stops_renderer_when_document_becomes_inactive() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	context.document_became_inactive()
	assert !context.fully_active
	renderer := context.renderer or { panic('missing realtime renderer') }
	assert renderer.is_shutting_down()
	assert context.resume().state == .rejected
}

fn test_realtime_context_dispatches_ended_from_the_renderer() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(1, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	source.node.start(0) or { panic(err) }
	source.node.stop(0.001) or { panic(err) }
	mut output := []f32{len: 64}
	context.fill_output_buffer(mut output)
	assert source.node.ended_event_count() == 1
}

fn test_listener_decode_and_media_element_boundaries() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.listener.set_position(1, 2, 3) or { panic(err) }
	assert context.base.listener.position_z.value() == 3
	decoded := context.base.decode_audio_data(pcm16_stereo_wave_fixture(), true)
	assert decoded.promise.state == .fulfilled
	buffer := decoded.buffer or { panic('missing') }
	assert buffer.number_of_channels() == 2
	assert buffer.sample_rate == 44_100
	assert buffer.length == 11
	assert buffer.channels[0][0] == 0
	assert buffer.channels[0].last() == -1
	assert buffer.channels[1][0] == f32(32767.0 / 32768.0)
	assert buffer.channels[1].last() == 0.5
	assert context.base.media_element_tasks == 1
	failed := context.base.decode_audio_data([u8(1), 2], true)
	assert failed.promise.state == .rejected
	assert failed.promise.message.contains('EncodingError')
	assert context.base.media_element_tasks == 2
	source := context.create_media_element_source('media') or { panic(err) }
	assert source.node.number_of_inputs == 0
}

fn pcm16_stereo_wave_fixture() []u8 {
	return base64.decode('UklGRiwAAABXQVZFZm10IBAAAAABAAIAQB8AAAB9AAAEABAAZGF0YQgAAAAAAP9/AIAAQA==')
}

fn test_offline_rendering_is_single_use_and_dispatches_completion() {
	mut context := new_offline_audio_context(3, 2, 128, 8000) or { panic(err) }
	mut source := context.base.create_constant_source(0.25, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	result := context.start_rendering()
	assert result.promise.state == .fulfilled
	buffer := result.buffer or { panic('missing') }
	assert buffer.length == 128
	assert buffer.channels[0] == []f32{len: 128, init: 0.25}
	assert buffer.channels[1] == []f32{len: 128, init: 0.25}
	assert (result.event or { panic('missing') }).event_type == 'complete'
	assert context.base.state == .closed
	assert context.base.current_time() == 128.0 / 8000.0
	assert context.oncomplete_count == 1
	assert context.start_rendering().promise.state == .rejected
	context.resume() or {
		assert err.msg().contains('not suspended')
		return
	}
	assert false
}

fn test_offline_context_suspends_and_resumes_rendering() {
	mut context := new_offline_audio_context(3, 1, 256, 48_000) or { panic(err) }
	mut source := context.base.create_constant_source(0.5, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	context.suspend(128.0 / 48_000.0) or { panic(err) }
	result := context.start_rendering()
	assert result.promise.state == .pending
	assert context.base.state == .suspended
	assert context.base.current_time() == 128.0 / 48_000.0
	context.resume() or { panic(err) }
	assert context.base.state == .closed
	assert context.base.current_time() == 256.0 / 48_000.0
	assert context.oncomplete_count == 1
	buffer := context.rendered_buffer or { panic('missing rendered buffer') }
	assert buffer.channels[0] == []f32{len: 256, init: 0.5}
}

fn test_offline_context_validates_suspend_times_and_boundaries() {
	mut context := new_offline_audio_context(3, 1, 256, 48_000) or { panic(err) }
	mut rejected_negative := false
	context.suspend(-1) or {
		assert err.msg().contains('finite, non-negative')
		rejected_negative = true
	}
	assert rejected_negative
	mut rejected_past_end := false
	context.suspend(1) or {
		assert err.msg().contains('less than the duration')
		rejected_past_end = true
	}
	assert rejected_past_end
	context.suspend(0) or { panic(err) }
	context.suspend(0) or {
		assert err.msg().contains('already scheduled')
		return
	}
	assert false
}
