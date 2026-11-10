module webaudio

@[heap]
struct RenderGraphTestObservation {
mut:
	source_calls int
	messages     []NodeMessageKind
}

fn render_graph_source_process(mut node RenderNode, _ mut RenderGraph,
	context RenderContext) {
	mut output := unsafe { &AudioBus(node.output(0)) }
	output.set_channel_count(2)
	output.set_channel(0, []f32{len: context.quantum_size, init: 2})
	output.set_channel(1, []f32{len: context.quantum_size, init: 4})
}

fn render_graph_destination_process(mut node RenderNode, mut graph RenderGraph,
	context RenderContext) {
	input := node.pull_input(mut graph, context, 0)
	mut output := unsafe { &AudioBus(node.output(0)) }
	output.copy_from(input)
}

fn test_render_context_times_frames_exactly() {
	context := RenderContext{
		sample_rate: 48_000
		quantum_size: 128
		quantum_start_frame: 256
	}
	assert context.quantum_start_time() == 256.0 / 48_000.0
	assert context.sample_period() == 1.0 / 48_000.0
	assert context.frame_time(8) == 264.0 / 48_000.0
}

fn test_render_graph_applies_connections_channel_configuration_and_messages() {
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, 4, 1)
	mut destination := RenderNode.create(2, 1, 1, 4, 1)
	source.set_process_callback(render_graph_source_process)
	destination.set_process_callback(render_graph_destination_process)
	mut observed := &RenderGraphTestObservation{}
	destination.set_message_callback(fn [mut observed] (_ mut RenderNode, message NodeMessage) {
		observed.messages << message.kind
	})
	graph.apply_control_messages([
		ControlMessage{
			kind: .add_node
			render_node: source
		},
		ControlMessage{
			kind: .add_node
			render_node: destination
		},
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [
				OutgoingNodeConnection{
					destination: 2
					output_index: 0
					input_index: 0
				},
			]
		},
		ControlMessage{
			kind: .set_channel_config
			node_id: 2
			channel_count: 1
			channel_count_mode: .explicit
			channel_interpretation: .speakers
		},
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: 2
				kind: .start_source
				when: 0.5
			}
		},
	])
	graph.set_destination(2)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: 4
	})
	assert destination.input_connections(0) == [RenderNodeConnection{
		source: 1
		output_index: 0
	}]
	assert destination.output(0).channel_count() == 1
	assert destination.output(0).channel(0) == [f32(3), 3, 3, 3]
	assert observed.messages == [.start_source]
	assert node_message_target(NodeMessage{ node_id: 9 }) == 9
}

fn test_render_audio_param_combines_timeline_and_mono_input() {
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, 4, 1)
	source.set_process_callback(fn (mut node RenderNode, _ mut RenderGraph, context RenderContext) {
		mut output := unsafe { &AudioBus(node.output(0)) }
		output.set_channel(0, []f32{len: context.quantum_size, init: 2})
	})
	timeline := AudioParamTimeline.create(1)
	mut parameter := RenderAudioParam.create(timeline, 0, 10, .a_rate)
	mut holder := RenderNode.create(2, 0, 1, 4, 1)
	holder.add_param(parameter)
	graph.apply_control_messages([
		ControlMessage{
			kind: .add_node
			render_node: source
		},
		ControlMessage{
			kind: .add_node
			render_node: holder
		},
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			param_connections: [
				OutgoingParamConnection{
					destination: parameter
					output_index: 0
				},
			]
		},
	])
	context := RenderContext{
		sample_rate: 48_000
		quantum_size: 4
	}
	graph.render_quantum(context)
	assert parameter.inputs() == [RenderAudioParamInput{
		source: 1
		output_index: 0
	}]
	mut output := []f32{len: 4}
	parameter.compute(mut graph, context, mut output)
	assert output == [f32(3), 3, 3, 3]
	parameter.set_automation_rate(.k_rate)
	assert parameter.automation_rate() == .k_rate
	parameter.compute(mut graph, context, mut output)
	assert output == [f32(3), 3, 3, 3]
}

fn test_render_graph_reports_ended_nodes_once_and_removes_them() {
	mut graph := RenderGraph.create()
	mut node := RenderNode.create(7, 0, 1, 4, 1)
	graph.apply_control_messages([ControlMessage{
		kind: .add_node
		render_node: node
	}])
	assert graph.take_ended_nodes().len == 0
	node.mark_ended()
	assert graph.take_ended_nodes() == [u64(7)]
	assert graph.node(7) == none
	assert graph.take_ended_nodes().len == 0
}

fn test_audio_param_owns_synchronized_render_parameter() {
	mut parameter := new_audio_param(1, 1, &AudioGraphState{}, 1, 0, 2, .a_rate, false)
	assert parameter.render_param().automation_rate() == .a_rate
	parameter.set_automation_rate(.k_rate)!
	assert parameter.render_param().automation_rate() == .k_rate
}

fn test_zero_channel_output_is_pulled_as_mono_silence() {
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, 4, 0)
	mut destination := RenderNode.create(2, 1, 1, 4, 1)
	destination.set_process_callback(render_graph_destination_process)
	graph.apply_control_messages([
		ControlMessage{kind: .add_node, render_node: source},
		ControlMessage{kind: .add_node, render_node: destination},
		ControlMessage{kind: .replace_connections, node_id: 1, node_connections: [OutgoingNodeConnection{destination: 2}]},
	])
	graph.set_destination(2)
	graph.render_quantum(RenderContext{sample_rate: 48_000, quantum_size: 4})
	assert destination.output(0).channel_count() == 1
	assert destination.output(0).channel(0) == [f32(0), 0, 0, 0]
}
