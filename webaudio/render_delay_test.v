module webaudio

fn delay_test_source(samples []f32) &RenderNode {
	mut source := RenderNode.create(1, 0, 1, samples.len, 1)
	source.set_process_callback(fn [samples] (mut node RenderNode, _ mut RenderGraph, _ RenderContext) {
		mut output := unsafe { &AudioBus(node.output(0)) }
		output.set_channel(0, samples)
	})
	return source
}

fn render_delay_fixture(samples []f32, delay_seconds f32) &DelayRenderNode {
	mut graph := RenderGraph.create()
	source := delay_test_source(samples)
	delay_time := RenderAudioParam.create(AudioParamTimeline.create(delay_seconds), 0, 1, .a_rate)
	delay := DelayRenderNode.create(2, samples.len, delay_time, 1)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: delay.render_node() },
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [OutgoingNodeConnection{
				destination: 2
			}]
		},
	])
	graph.set_destination(2)
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: samples.len
	})
	return delay
}

fn test_delay_render_node_delays_by_integral_frames() {
	delay := render_delay_fixture([f32(1), 0, 0, 0], 0.5)
	assert delay.render_node().output(0).channel(0) == [f32(0), 0, 1, 0]
}

fn test_delay_render_node_interpolates_fractional_frames() {
	delay := render_delay_fixture([f32(1), 0, 0, 0], 0.125)
	assert delay.render_node().output(0).channel(0) == [f32(0.5), 0.5, 0, 0]
}

fn test_delay_render_node_zero_delay_is_bit_exact() {
	delay := render_delay_fixture([f32(1), 2, 3, 4], 0)
	assert delay.render_node().output(0).channel(0) == [f32(1), 2, 3, 4]
}
