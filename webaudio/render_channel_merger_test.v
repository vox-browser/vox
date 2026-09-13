module webaudio

fn channel_merger_test_source(node_id u64, samples []f32) &RenderNode {
	mut source := RenderNode.create(node_id, 0, 1, samples.len, 1)
	source.set_process_callback(fn [samples] (mut node RenderNode, _ mut RenderGraph, _ RenderContext) {
		mut output := unsafe { &AudioBus(node.output(0)) }
		output.set_channel(0, samples)
	})
	return source
}

fn test_channel_merger_render_node_routes_mono_inputs_to_output_channels() {
	mut graph := RenderGraph.create()
	first := channel_merger_test_source(1, [f32(1), 2, 3, 4])
	second := channel_merger_test_source(2, [f32(5), 6, 7, 8])
	merger := ChannelMergerRenderNode.create(3, 4, 3)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: first },
		ControlMessage{ kind: .add_node, render_node: second },
		ControlMessage{ kind: .add_node, render_node: merger.render_node() },
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [OutgoingNodeConnection{
				destination: 3
				input_index: 0
			}]
		},
		ControlMessage{
			kind: .replace_connections
			node_id: 2
			node_connections: [OutgoingNodeConnection{
				destination: 3
				input_index: 2
			}]
		},
	])
	graph.set_destination(3)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: 4
	})
	output := merger.render_node().output(0)
	assert output.channel_count() == 3
	assert output.channel(0) == [f32(1), 2, 3, 4]
	assert output.channel(1) == [f32(0), 0, 0, 0]
	assert output.channel(2) == [f32(5), 6, 7, 8]
}

fn test_channel_merger_render_node_uses_explicit_mono_input_rules() {
	merger := ChannelMergerRenderNode.create(1, 4, 6)
	assert merger.render_node().input_count() == 6
	assert merger.render_node().output(0).channel_count() == 6
	assert merger.render_node().channel_count() == 1
	assert merger.render_node().channel_count_mode() == .explicit
}
