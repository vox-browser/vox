module webaudio

fn channel_splitter_test_source(mut node RenderNode, _ mut RenderGraph,
	_ RenderContext) {
	mut output := unsafe { &AudioBus(node.output(0)) }
	output.set_channel_count(2)
	output.set_channel(0, [f32(1), 2, 3, 4])
	output.set_channel(1, [f32(5), 6, 7, 8])
}

fn test_channel_splitter_render_node_routes_each_channel_to_a_mono_output() {
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, 4, 1)
	source.set_process_callback(channel_splitter_test_source)
	splitter := ChannelSplitterRenderNode.create(2, 4, 3)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: splitter.render_node() },
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
		sample_rate: 48_000
		quantum_size: 4
	})
	assert splitter.render_node().output_count() == 3
	assert splitter.render_node().output(0).channel_count() == 1
	assert splitter.render_node().output(0).channel(0) == [f32(1), 2, 3, 4]
	assert splitter.render_node().output(1).channel(0) == [f32(5), 6, 7, 8]
	assert splitter.render_node().output(2).channel(0) == [f32(0), 0, 0, 0]
}

fn test_channel_splitter_render_node_uses_explicit_discrete_input_rules() {
	splitter := ChannelSplitterRenderNode.create(1, 4, 4)
	assert splitter.render_node().channel_count() == 4
	assert splitter.render_node().channel_count_mode() == .explicit
	assert splitter.render_node().channel_interpretation() == .discrete
}
