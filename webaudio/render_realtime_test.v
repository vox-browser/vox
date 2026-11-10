module webaudio

struct RealtimeRendererObservation {
mut:
	ended_nodes []u64
}

fn test_realtime_renderer_fills_interleaved_device_buffers() {
	mut context := make_base_context(1, 48_000, 2, false) or { panic(err) }
	mut source := context.create_constant_source(0.25, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context, mut source.node, 0) or { panic(err) }
	mut renderer := RealtimeAudioRenderer.create(context.control_messages, destination.id, 48_000, int(render_quantum_size))
	renderer.start_rendering_with_null_output()
	mut output := []f32{len: 20}
	assert renderer.fill_output_buffer(mut output) == []f32{len: 20, init: 0.25}
	assert renderer.frames_rendered() == 128
	assert renderer.output_time_played() == 10.0 / 48_000.0
}

fn test_realtime_renderer_resamples_to_the_device_rate() {
	mut context := make_base_context(1, 48_000, 1, false) or { panic(err) }
	mut buffer := context.create_buffer(1, 256, 48_000) or { panic(err) }
	for index in 0 .. 256 {
		buffer.channels[0][index] = f32(index)
	}
	mut source := context.create_buffer_source(AudioBufferSourceOptions{ buffer: buffer }) or {
		panic(err)
	}
	mut destination := context.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	source.start(0, 0, none) or { panic(err) }
	mut renderer := RealtimeAudioRenderer.create(context.control_messages, destination.id, 48_000, int(render_quantum_size))
	renderer.start_rendering_with_null_output()
	renderer.set_playback_stream(1, 24_000)
	mut output := []f32{len: 4}
	renderer.fill_output_buffer(mut output)
	assert output == [f32(0), 2, 4, 6]
}

fn test_realtime_renderer_discards_old_channel_stride_when_device_layout_changes() {
	mut context := make_base_context(1, 48_000, 1, false) or { panic(err) }
	mut buffer := context.create_buffer(1, 512, 48_000) or { panic(err) }
	for index in 0 .. 512 { buffer.channels[0][index] = f32(index) }
	mut source := context.create_buffer_source(AudioBufferSourceOptions{buffer: buffer}) or { panic(err) }
	mut destination := context.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	source.start(0, 0, none) or { panic(err) }
	mut renderer := RealtimeAudioRenderer.create(context.control_messages, destination.id, 48_000, 128)
	renderer.start_rendering_with_null_output()
	mut stereo := []f32{len: 2}
	renderer.fill_output_buffer(mut stereo)
	assert stereo == [f32(0), 0]
	assert renderer.pending_samples_.len > 0
	renderer.set_playback_stream(2, 48_000)
	renderer.fill_output_buffer(mut stereo)
	assert stereo == [f32(1), 1]
	renderer.set_playback_stream(1, 48_000)
	mut mono := []f32{len: 2}
	renderer.fill_output_buffer(mut mono)
	assert mono == [f32(128), 129]
}

fn test_realtime_renderer_reports_ended_sources_and_stops_output() {
	mut context := make_base_context(1, 48_000, 1, false) or { panic(err) }
	mut source := context.create_constant_source(1, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context, mut source.node, 0) or { panic(err) }
	stop_scheduled_source(mut context, source.node, 0.001) or { panic(err) }
	mut renderer := RealtimeAudioRenderer.create(context.control_messages, destination.id, 48_000, int(render_quantum_size))
	mut observation := &RealtimeRendererObservation{}
	renderer.set_on_sources_ended(fn [mut observation] (node_ids []u64) {
		observation.ended_nodes << node_ids
	})
	renderer.start_rendering_with_null_output()
	mut output := []f32{len: 64}
	renderer.fill_output_buffer(mut output)
	assert observation.ended_nodes == [source.node.id]
	renderer.suspend()
	assert renderer.is_suspended()
	renderer.resume()
	assert !renderer.is_suspended()
	renderer.stop()
	assert renderer.is_shutting_down()
	assert renderer.fill_output_buffer(mut output).len == 0
}
