module webaudio

import math

@[heap]
struct GraphParamObservation {
mut:
	count int
}

fn test_audio_node_connections_are_unique_validated_and_disconnectable() {
	mut first_context := new_audio_context(1, 44100, true) or { panic(err) }
	mut source := first_context.base.create_gain(1, AudioNodeOptions{}) or { panic(err) }
	mut destination := first_context.base.create_gain(1, AudioNodeOptions{}) or { panic(err) }
	connect_nodes(mut source.node, mut destination.node, 0, 0) or { panic(err) }
	connect_nodes(mut source.node, mut destination.node, 0, 0) or { panic(err) }
	assert source.node.output_connection_records().len == 1
	assert destination.node.input_connection_records().len == 1
	connect_param(mut source.node, destination.gain, 0) or { panic(err) }
	assert source.node.param_connection_records().len == 1
	disconnect_nodes(mut source.node, mut destination.node, 0, 0) or { panic(err) }
	source.node.disconnect_parameter(destination.gain.id, 0) or { panic(err) }
	assert source.node.output_connection_records().len == 0
	assert destination.node.input_connection_records().len == 0
	connect_nodes(mut source.node, mut destination.node, 0, 0) or { panic(err) }
	connect_param(mut source.node, destination.gain, 0) or { panic(err) }
	source.node.disconnect_all()
	assert source.node.output_connection_records().len == 0
	assert source.node.param_connection_records().len == 0
	assert destination.node.input_connection_records().len == 0
	mut second_context := new_audio_context(2, 44100, true) or { panic(err) }
	mut other := second_context.base.create_gain(1, AudioNodeOptions{}) or { panic(err) }
	connect_nodes(mut source.node, mut other.node, 0, 0) or {
		assert err.msg().contains('different AudioContexts')
		return
	}
	assert false
}

fn test_audio_param_clamps_visible_value_and_fixed_rate() {
	mut parameter := new_audio_param(1, 1, &AudioGraphState{}, 2, -1, 1, .k_rate, true)
	assert parameter.value() == 1
	parameter.set_value(-4)!
	assert parameter.value() == -1
	parameter.set_automation_rate(.a_rate) or {
		assert err.msg().contains('cannot be changed')
		return
	}
	assert false
}

fn test_scheduled_source_enforces_one_shot_lifecycle() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.control_messages.drain()
	mut node := AudioNode{
		id: 1
		context_id: 1
		kind: .oscillator
		number_of_outputs: 1
	}
	start_scheduled_source(mut context.base, mut node, 0.25) or { panic(err) }
	stop_scheduled_source(mut context.base, node, 0.75) or { panic(err) }
	assert context.base.control_messages.messages.map(it.kind) == [.start_source, .stop_source]
	assert context.base.control_messages.messages.map(it.when) == [0.25, 0.75]
	start_scheduled_source(mut context.base, mut node, 0) or {
		assert err.msg().contains('already been started')
		return
	}
	assert false
}

fn test_audio_context_queues_its_destination_render_node_first() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	messages := context.base.control_messages.drain()
	assert messages.len == 1
	assert messages[0].kind == .add_node
	render_node := messages[0].render_node or { panic('missing destination render node') }
	assert render_node.node_id() == context.base.destination.id
	assert render_node.channel_count() == 2
	assert render_node.channel_count_mode() == .explicit
}

fn test_audio_node_queues_render_graph_creation_and_configuration() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut node := context.base.allocate_node(.gain, 1, 1, AudioNodeOptions{}, 2, .max, .speakers) or { panic(err) }
	context.base.control_messages.drain()
	render_node := RenderNode.create(node.id, 1, 1, int(render_quantum_size), 1)
	node.queue_render_node_creation(render_node)
	node.set_channel_count(1) or { panic(err) }
	messages := context.base.control_messages.drain()
	assert messages.map(it.kind) == [.add_node, .set_channel_config]
	assert messages[0].render_node or { panic('missing render node') } == render_node
	assert messages[1].node_id == node.id
	assert messages[1].channel_count == 1
}

fn test_audio_node_queues_render_graph_connection_snapshots() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_gain(1, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.create_gain(1, AudioNodeOptions{}) or { panic(err) }
	context.base.control_messages.drain()
	connect_nodes(mut source.node, mut destination.node, 0, 0) or { panic(err) }
	connect_param(mut source.node, destination.gain, 0) or { panic(err) }
	messages := context.base.control_messages.drain()
	assert messages.len == 2
	assert messages[0].kind == .replace_connections
	assert messages[0].node_connections == [OutgoingNodeConnection{
		destination: destination.node.id
	}]
	assert messages[1].param_connections.len == 1
	assert messages[1].param_connections[0].destination == destination.gain.render_param()
	source.node.disconnect_all()
	disconnect_message := context.base.control_messages.drain()[0]
	assert disconnect_message.node_connections.len == 0
	assert disconnect_message.param_connections.len == 0
}

fn test_gain_factory_queues_a_parameterized_render_node() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	context.base.control_messages.drain()
	gain := context.base.create_gain(0.25, AudioNodeOptions{}) or { panic(err) }
	messages := context.base.control_messages.drain()
	add_message := messages.filter(it.kind == .add_node)[0]
	render_node := add_message.render_node or { panic('missing gain render node') }
	assert render_node.node_id() == gain.node.id
	mut parameter_count := &GraphParamObservation{}
	mut mutable_render_node := unsafe { &RenderNode(render_node) }
	mutable_render_node.for_each_param(fn [mut parameter_count] (_ mut RenderAudioParam) {
		parameter_count.count++
	})
	assert parameter_count.count == 1
}

fn test_constant_source_factory_messages_render_through_the_context_destination() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(0.25, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	assert output.output(0).channel_count() == 2
	assert output.output(0).channel(0) == []f32{len: int(render_quantum_size), init: 0.25}
	assert output.output(0).channel(1) == []f32{len: int(render_quantum_size), init: 0.25}
}

fn test_delay_factory_messages_render_through_the_context_destination() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(0.5, AudioNodeOptions{}) or { panic(err) }
	mut delay := context.base.create_delay(1, 0, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut delay.node, 0, 0) or { panic(err) }
	connect_nodes(mut delay.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	assert output.output(0).channel(0) == []f32{len: int(render_quantum_size), init: 0.5}
	assert output.output(0).channel(1) == []f32{len: int(render_quantum_size), init: 0.5}
}

fn test_stereo_panner_factory_messages_render_through_the_context_destination() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(0.5, AudioNodeOptions{}) or { panic(err) }
	mut panner := context.base.create_stereo_panner(1, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut panner.node, 0, 0) or { panic(err) }
	connect_nodes(mut panner.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	for sample in output.output(0).channel(0) {
		assert math.abs(sample) < 0.00001
	}
	assert output.output(0).channel(1) == []f32{len: int(render_quantum_size), init: 0.5}
}
