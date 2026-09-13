module webaudio

@[heap]
struct RenderParamVisitObservation {
mut:
	found bool
}

fn render_basic_source_process(mut node RenderNode, _ mut RenderGraph,
	context RenderContext) {
	mut output := unsafe { &AudioBus(node.output(0)) }
	output.set_channel_count(2)
	output.set_channel(0, []f32{len: context.quantum_size, init: 2})
	output.set_channel(1, []f32{len: context.quantum_size, init: 4})
}

fn test_gain_and_destination_render_nodes_process_connected_graph() {
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, 4, 1)
	source.set_process_callback(render_basic_source_process)
	gain_param := RenderAudioParam.create(AudioParamTimeline.create(0.5), 0, 1, .a_rate)
	gain := GainRenderNode.create(2, 4, gain_param)
	destination := DestinationRenderNode.create(3, 1, 4)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: gain.render_node() },
		ControlMessage{ kind: .add_node, render_node: destination.render_node() },
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [OutgoingNodeConnection{
				destination: 2
			}]
		},
		ControlMessage{
			kind: .replace_connections
			node_id: 2
			node_connections: [OutgoingNodeConnection{
				destination: 3
			}]
		},
	])
	graph.set_destination(3)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: 4
	})
	assert gain.render_node().output(0).channel_count() == 2
	assert gain.render_node().output(0).channel(0) == [f32(1), 1, 1, 1]
	assert gain.render_node().output(0).channel(1) == [f32(2), 2, 2, 2]
	assert destination.render_node().output(0).channel_count() == 1
	assert destination.render_node().output(0).channel(0) == [f32(1.5), 1.5, 1.5, 1.5]
}

fn test_passthrough_render_node_preserves_channels_and_samples() {
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, 4, 1)
	source.set_process_callback(render_basic_source_process)
	passthrough := PassthroughRenderNode.create(2, 4)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: passthrough.render_node() },
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
	assert passthrough.render_node().output(0).channel_count() == 2
	assert passthrough.render_node().output(0).channel(0) == [f32(2), 2, 2, 2]
	assert passthrough.render_node().output(0).channel(1) == [f32(4), 4, 4, 4]
}

fn test_gain_render_node_exposes_its_render_parameter() {
	parameter := RenderAudioParam.create(AudioParamTimeline.create(1), 0, 2, .a_rate)
	mut gain := GainRenderNode.create(1, 4, parameter)
	mut observed := &RenderParamVisitObservation{}
	gain.for_each_param(fn [mut observed, parameter] (mut current RenderAudioParam) {
		observed.found = voidptr(&current) == voidptr(parameter)
	})
	assert observed.found
}
