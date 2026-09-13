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

fn test_scheduled_source_tracks_playing_lifetime_and_dispatches_ended_once() {
	mut context := new_audio_context(1, 44_100, true) or { panic(err) }
	mut node := context.base.allocate_node(.oscillator, 0, 1, AudioNodeOptions{}, 2,
		.max, .speakers) or { panic(err) }
	context.base.control_messages.drain()
	node.set_onended(true)
	node.start(0.25) or { panic(err) }
	assert context.base.control_messages.drain().map(it.kind) == [.start_source]
	assert node.id in context.base.graph.playing_sources
	context.base.handle_ended_sources([node.id, u64(999)])
	assert node.ended_event_count() == 1
	assert node.id !in context.base.graph.playing_sources
	assert context.base.media_element_tasks == 1
	context.base.handle_ended_sources([node.id])
	assert node.ended_event_count() == 1
	assert context.base.media_element_tasks == 1
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

fn test_spatial_panner_factory_messages_render_through_the_context_destination() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(0.5, AudioNodeOptions{}) or { panic(err) }
	mut panner := context.base.create_panner(PannerOptions{ position_x: 1 }) or { panic(err) }
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

fn test_spatial_panner_setters_queue_complete_render_configuration() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut panner := context.base.create_panner(PannerOptions{}) or { panic(err) }
	context.base.control_messages.drain()
	panner.set_distance_model(.linear)
	panner.set_ref_distance(2) or { panic(err) }
	panner.set_max_distance(20) or { panic(err) }
	panner.set_cone_outer_angle(180)
	messages := context.base.control_messages.drain()
	assert messages.len == 4
	last := messages.last().node_message or { panic('missing panner parameters') }
	assert last.kind == .set_panner_parameters
	assert last.distance_model == .linear
	assert last.ref_distance == 2
	assert last.max_distance == 20
	assert last.cone_outer_angle == 180
}

fn test_dynamics_compressor_factory_queues_upstream_passthrough_renderer() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(0.75, AudioNodeOptions{}) or { panic(err) }
	mut compressor := context.base.create_dynamics_compressor(DynamicsCompressorOptions{}) or {
		panic(err)
	}
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut compressor.node, 0, 0) or { panic(err) }
	connect_nodes(mut compressor.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	assert output.output(0).channel(0) == []f32{len: int(render_quantum_size), init: 0.75}
	assert output.output(0).channel(1) == []f32{len: int(render_quantum_size), init: 0.75}
}

fn test_channel_merger_factory_queues_its_multi_input_render_node() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	context.base.control_messages.drain()
	merger := context.base.create_channel_merger(4, AudioNodeOptions{}) or { panic(err) }
	messages := context.base.control_messages.drain()
	add_messages := messages.filter(it.kind == .add_node)
	assert add_messages.len == 1
	render_node := add_messages[0].render_node or { panic('missing merger render node') }
	assert render_node.node_id() == merger.node.id
	assert render_node.input_count() == 4
	assert render_node.output(0).channel_count() == 4
}

fn test_channel_splitter_factory_queues_its_multi_output_render_node() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	context.base.control_messages.drain()
	splitter := context.base.create_channel_splitter(4, AudioNodeOptions{}) or { panic(err) }
	messages := context.base.control_messages.drain()
	add_messages := messages.filter(it.kind == .add_node)
	assert add_messages.len == 1
	render_node := add_messages[0].render_node or { panic('missing splitter render node') }
	assert render_node.node_id() == splitter.node.id
	assert render_node.output_count() == 4
	assert render_node.channel_count() == 4
	assert render_node.channel_interpretation() == .discrete
}

fn test_biquad_factory_type_message_renders_through_the_context_destination() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_constant_source(1, AudioNodeOptions{}) or { panic(err) }
	mut filter := context.base.create_biquad_filter(BiquadFilterOptions{
		type_: .highpass
		frequency: 12_000
		q: 0
	}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut filter.node, 0, 0) or { panic(err) }
	connect_nodes(mut filter.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	assert math.abs(output.output(0).channel(0)[0] - f32(1.0 / 3.0)) < 0.00001
	assert math.abs(output.output(0).channel(0)[1] + f32(1.0 / 3.0)) < 0.00001
}

fn test_oscillator_factory_waveform_message_renders_through_the_context_destination() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut oscillator := context.base.create_oscillator(OscillatorOptions{
		frequency: 12_000
	}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut oscillator.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut oscillator.node, 0) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	actual := output.output(0).channel(0)
	assert math.abs(actual[0]) < 0.00001
	assert math.abs(actual[1] - 1) < 0.00001
	assert math.abs(actual[2]) < 0.00001
	assert math.abs(actual[3] + 1) < 0.00001
}

fn test_buffer_source_factory_start_message_renders_acquired_contents() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut buffer := context.base.create_buffer(1, 4, 48_000) or { panic(err) }
	buffer.copy_to_channel([f32(1), 2, 3, 4], 0, 0) or { panic(err) }
	mut source := context.base.create_buffer_source(AudioBufferSourceOptions{
		buffer: buffer
	}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	source.start(0, 0, none) or { panic(err) }
	mut graph := RenderGraph.create()
	graph.apply_control_messages(context.base.control_messages.drain())
	graph.set_destination(destination.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := graph.destination() or { panic('missing destination') }
	assert output.output(0).channel(0)[..4] == [f32(1), 2, 3, 4]
	assert output.output(0).channel(1)[..4] == [f32(1), 2, 3, 4]
	assert output.output(0).channel(0)[4..] == []f32{len: int(render_quantum_size) - 4}
}

fn test_buffer_source_setters_queue_live_parameter_and_buffer_updates() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut source := context.base.create_buffer_source(AudioBufferSourceOptions{}) or { panic(err) }
	context.base.control_messages.drain()
	source.set_loop(true)
	source.set_loop_start(0.25)
	source.set_loop_end(0.75)
	messages := context.base.control_messages.drain()
	assert messages.len == 3
	last_parameters := messages[2].node_message or { panic('missing buffer parameters') }
	assert last_parameters.loop_
	assert last_parameters.loop_start == 0.25
	assert last_parameters.loop_end == 0.75
	source.start(0, 0, none) or { panic(err) }
	context.base.control_messages.drain()
	buffer := context.base.create_buffer(1, 4, 48_000) or { panic(err) }
	source.set_buffer(buffer) or { panic(err) }
	update := context.base.control_messages.drain()[0].node_message or {
		panic('missing live buffer update')
	}
	assert update.update_buffer
	assert update.buffer != none
}
