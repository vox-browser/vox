module webaudio

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
