module webaudio

fn buffer_source_test_node(quantum_size int, buffer &AudioBufferContents) &AudioBufferSourceRenderNode {
	playback_rate := RenderAudioParam.create(AudioParamTimeline.create(1), -100, 100, .k_rate)
	detune := RenderAudioParam.create(AudioParamTimeline.create(0), -2400, 2400, .k_rate)
	mut source := AudioBufferSourceRenderNode.create(1, quantum_size, playback_rate, detune)
	source.handle_message(NodeMessage{
		node_id: 1
		kind: .start_buffer_source
		buffer: buffer
	})
	return source
}

fn test_audio_buffer_source_renders_bit_exact_at_unity_rate() {
	buffer := &AudioBufferContents{
		channels: [[f32(1), 2, 3, 4]]
		sample_rate: 4
	}
	mut graph := RenderGraph.create()
	source := buffer_source_test_node(4, buffer)
	graph.apply_control_messages([ControlMessage{
		kind: .add_node
		render_node: source.render_node()
	}])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert source.render_node().output(0).channel(0) == [f32(1), 2, 3, 4]
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
		quantum_start_frame: 4
	})
	assert source.render_node().output(0).is_silent()
	assert source.scheduled_source().content_ended()
}

fn test_audio_buffer_source_honors_start_offset_and_duration() {
	buffer := &AudioBufferContents{
		channels: [[f32(1), 2, 3, 4]]
		sample_rate: 4
	}
	mut graph := RenderGraph.create()
	mut source := buffer_source_test_node(4, buffer)
	source.handle_message(NodeMessage{
		node_id: 1
		kind: .start_buffer_source
		when: 0.25
		offset: 0.25
		duration: 0.5
		buffer: buffer
	})
	graph.apply_control_messages([ControlMessage{
		kind: .add_node
		render_node: source.render_node()
	}])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert source.render_node().output(0).channel(0) == [f32(0), 2, 3, 0]
	assert source.scheduled_source().content_ended()
}

fn test_audio_buffer_source_resamples_with_linear_interpolation() {
	buffer := &AudioBufferContents{
		channels: [[f32(0), 10, 20]]
		sample_rate: 2
	}
	mut graph := RenderGraph.create()
	source := buffer_source_test_node(4, buffer)
	graph.apply_control_messages([ControlMessage{
		kind: .add_node
		render_node: source.render_node()
	}])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert source.render_node().output(0).channel(0) == [f32(0), 5, 10, 15]
}

fn test_audio_buffer_source_wraps_interpolation_at_loop_boundary() {
	buffer := &AudioBufferContents{
		channels: [[f32(0), 10, 20, 30]]
		sample_rate: 4
	}
	mut graph := RenderGraph.create()
	mut source := buffer_source_test_node(4, buffer)
	source.handle_message(NodeMessage{
		node_id: 1
		kind: .set_buffer_source_parameters
		loop_: true
		loop_start: 0.25
		loop_end: 0.75
		update_buffer: true
		buffer: buffer
	})
	source.handle_message(NodeMessage{
		node_id: 1
		kind: .start_buffer_source
		offset: 0.5
		buffer: buffer
	})
	graph.apply_control_messages([ControlMessage{
		kind: .add_node
		render_node: source.render_node()
	}])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert source.render_node().output(0).channel(0) == [f32(20), 10, 20, 10]
}
