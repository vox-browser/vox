// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Types.h, AudioParam, AudioNode, AudioScheduledSourceNode,
// ControlMessage, and ControlMessageQueue.
module webaudio

pub const max_number_of_channels = u32(32)
pub const min_sample_rate = f32(3_000)
pub const max_sample_rate = f32(768_000)
pub const render_quantum_size = u32(128)

pub enum AudioContextState {
	suspended
	running
	closed
}

pub enum ChannelCountMode {
	max
	clamped_max
	explicit
}

pub enum ChannelInterpretation {
	speakers
	discrete
}

pub enum AutomationRate {
	a_rate
	k_rate
}

pub enum BiquadFilterType {
	lowpass
	highpass
	bandpass
	lowshelf
	highshelf
	peaking
	notch
	allpass
}

pub enum OscillatorType {
	sine
	square
	sawtooth
	triangle
	custom
}

pub enum PanningModelType {
	equalpower
	hrtf
}

pub enum DistanceModelType {
	linear
	inverse
	exponential
}

pub enum NodeKind {
	destination
	analyser
	buffer_source
	biquad
	channel_merger
	channel_splitter
	constant_source
	delay
	compressor
	gain
	media_element_source
	media_stream_source
	media_stream_destination
	audio_worklet
	oscillator
	panner
	script_processor
	stereo_panner
}

pub struct AudioNodeOptions {
pub:
	channel_count          ?u32
	channel_count_mode     ?ChannelCountMode
	channel_interpretation ?ChannelInterpretation
}

@[heap]
pub struct AudioParam {
pub:
	id            u64
	context_id    u64
	default_value f32
	min_value     f32
	max_value     f32
	fixed_rate    bool
pub mut:
	graph           &AudioGraphState
	timeline        &AudioParamTimeline
	render_param_   &RenderAudioParam
	automation_rate AutomationRate
}

pub fn new_audio_param(id u64, context_id u64, graph &AudioGraphState, default_value f32,
	min_value f32, max_value f32, rate AutomationRate, fixed bool) AudioParam {
	timeline := AudioParamTimeline.create(default_value)
	render_param := RenderAudioParam.create(timeline, min_value, max_value, rate)
	mut mutable_graph := unsafe { &AudioGraphState(graph) }
	mutable_graph.render_params_[id] = render_param
	return AudioParam{
		id: id
		context_id: context_id
		default_value: default_value
		min_value: min_value
		max_value: max_value
		automation_rate: rate
		fixed_rate: fixed
		graph: graph
		timeline: timeline
		render_param_: render_param
	}
}

pub fn (parameter AudioParam) value() f32 {
	value := parameter.timeline.current_value()
	if value < parameter.min_value {
		return parameter.min_value
	}
	if value > parameter.max_value {
		return parameter.max_value
	}
	return value
}

pub fn (mut parameter AudioParam) set_value(value f32) ! {
	parameter.timeline.set_current_value(value)
	parameter.map_insert_result(parameter.timeline.set_value_at_time(value, parameter.graph.current_time))!
}

pub fn (mut parameter AudioParam) set_automation_rate(rate AutomationRate) ! {
	if parameter.fixed_rate && rate != parameter.automation_rate {
		return error('InvalidStateError: Automation rate cannot be changed')
	}
	parameter.automation_rate = rate
	parameter.render_param_.set_automation_rate(rate)
}

pub fn (parameter AudioParam) automation_rate() AutomationRate {
	return parameter.automation_rate
}

fn (parameter AudioParam) map_insert_result(result AudioParamTimelineInsertResult) ! {
	match result {
		.success {
			return
		}
		.event_contained_in_value_curve {
			return error('NotSupportedError: Cannot schedule an automation event during a value curve')
		}
		.value_curve_overlaps_event {
			return error('NotSupportedError: Cannot schedule a value curve containing an automation event')
		}
	}
}

pub fn (parameter AudioParam) intrinsic_value_at_time(time f64) f32 {
	return parameter.timeline.value_at_time(time)
}

pub fn (parameter AudioParam) timeline() &AudioParamTimeline {
	return parameter.timeline
}

pub fn (parameter AudioParam) render_param() &RenderAudioParam {
	return parameter.render_param_
}

pub fn (mut parameter AudioParam) set_value_at_time(value f32, start_time f64) !&AudioParam {
	if start_time < 0 {
		return error('RangeError: startTime must not be negative')
	}
	clamped_time := if start_time < parameter.graph.current_time {
		parameter.graph.current_time
	} else {
		start_time
	}
	parameter.map_insert_result(parameter.timeline.set_value_at_time(value, clamped_time))!
	return &parameter
}

pub fn (mut parameter AudioParam) linear_ramp_to_value_at_time(value f32, end_time f64) !&AudioParam {
	if end_time < 0 {
		return error('RangeError: endTime must not be negative')
	}
	current_time := parameter.graph.current_time
	clamped_time := if end_time < current_time { current_time } else { end_time }
	parameter.map_insert_result(parameter.timeline.linear_ramp_to_value_at_time(value, clamped_time, current_time, parameter.timeline.current_value()))!
	return &parameter
}

pub fn (mut parameter AudioParam) exponential_ramp_to_value_at_time(value f32,
	end_time f64) !&AudioParam {
	if value == 0 {
		return error('RangeError: value must not be zero')
	}
	if end_time < 0 {
		return error('RangeError: endTime must not be negative')
	}
	current_time := parameter.graph.current_time
	clamped_time := if end_time < current_time { current_time } else { end_time }
	parameter.map_insert_result(parameter.timeline.exponential_ramp_to_value_at_time(value, clamped_time, current_time, parameter.timeline.current_value()))!
	return &parameter
}

pub fn (mut parameter AudioParam) set_target_at_time(target f32, start_time f64,
	time_constant f32) !&AudioParam {
	if start_time < 0 {
		return error('RangeError: startTime must not be negative')
	}
	if time_constant < 0 {
		return error('RangeError: timeConstant must not be negative')
	}
	clamped_time := if start_time < parameter.graph.current_time {
		parameter.graph.current_time
	} else {
		start_time
	}
	parameter.map_insert_result(parameter.timeline.set_target_at_time(target, clamped_time, time_constant))!
	return &parameter
}

pub fn (mut parameter AudioParam) set_value_curve_at_time(values []f32, start_time f64,
	duration f64) !&AudioParam {
	if values.len < 2 {
		return error('InvalidStateError: values must contain at least two elements')
	}
	if start_time < 0 {
		return error('RangeError: startTime must not be negative')
	}
	if duration <= 0 {
		return error('RangeError: duration must be positive')
	}
	clamped_time := if start_time < parameter.graph.current_time {
		parameter.graph.current_time
	} else {
		start_time
	}
	parameter.map_insert_result(parameter.timeline.set_value_curve_at_time(values, clamped_time, duration))!
	return &parameter
}

pub fn (mut parameter AudioParam) cancel_scheduled_values(cancel_time f64) !&AudioParam {
	if cancel_time < 0 {
		return error('RangeError: cancelTime must not be negative')
	}
	clamped_time := if cancel_time < parameter.graph.current_time {
		parameter.graph.current_time
	} else {
		cancel_time
	}
	parameter.timeline.cancel_scheduled_values(clamped_time)
	return &parameter
}

pub fn (mut parameter AudioParam) cancel_and_hold_at_time(cancel_time f64) !&AudioParam {
	if cancel_time < 0 {
		return error('RangeError: cancelTime must not be negative')
	}
	clamped_time := if cancel_time < parameter.graph.current_time {
		parameter.graph.current_time
	} else {
		cancel_time
	}
	parameter.timeline.cancel_and_hold_at_time(clamped_time)
	return &parameter
}

pub struct AudioNodeConnection {
pub:
	source_id      u64
	destination_id u64
	output         u32
	input          u32
}

pub struct AudioParamConnection {
pub:
	source_id    u64
	parameter_id u64
	output       u32
}

@[heap]
pub struct AudioGraphState {
pub mut:
	current_time       f64
	sample_rate        f32
	input_connections  map[u64][]AudioNodeConnection
	output_connections map[u64][]AudioNodeConnection
	param_connections  map[u64][]AudioParamConnection
	playing_sources    map[u64]bool
	ended_event_counts map[u64]u32
	onended_handlers   map[u64]bool
mut:
	control_messages_ ?&ControlMessageQueue
	render_params_    map[u64]&RenderAudioParam
}

pub struct AudioNode {
pub:
	id                u64
	context_id        u64
	kind              NodeKind
	number_of_inputs  u32
	number_of_outputs u32
pub mut:
	graph                  &AudioGraphState = &AudioGraphState{}
	channel_count          u32 = 2
	channel_count_mode     ChannelCountMode = .max
	channel_interpretation ChannelInterpretation = .speakers
	source_started         bool
	onended                bool
}

pub fn (node AudioNode) input_connection_records() []AudioNodeConnection {
	return node.graph.input_connections[node.id] or { []AudioNodeConnection{} }
}

pub fn (node AudioNode) output_connection_records() []AudioNodeConnection {
	return node.graph.output_connections[node.id] or { []AudioNodeConnection{} }
}

pub fn (node AudioNode) param_connection_records() []AudioParamConnection {
	return node.graph.param_connections[node.id] or { []AudioParamConnection{} }
}

pub fn (mut node AudioNode) set_channel_count(count u32) ! {
	if count == 0 || count > max_number_of_channels {
		return error('NotSupportedError: Invalid channel count')
	}
	node.channel_count = count
	node.queue_channel_config_update()
}

pub fn (node AudioNode) channel_count() u32 {
	return node.channel_count
}

pub fn (mut node AudioNode) initialize_options(options AudioNodeOptions, default_count u32, default_mode ChannelCountMode, default_interpretation ChannelInterpretation) ! {
	node.set_channel_count(options.channel_count or { default_count })!
	node.channel_count_mode = options.channel_count_mode or { default_mode }
	node.channel_interpretation = options.channel_interpretation or { default_interpretation }
	node.queue_channel_config_update()
}

fn (node AudioNode) enqueue_control_message(message ControlMessage) {
	queue := node.graph.control_messages_ or { return }
	mut mutable_queue := unsafe { &ControlMessageQueue(queue) }
	mutable_queue.enqueue(message)
}

pub fn (node AudioNode) queue_render_node_creation(render_node &RenderNode) {
	node.enqueue_control_message(ControlMessage{
		kind: .add_node
		render_node: render_node
	})
}

pub fn (node AudioNode) queue_connection_update() {
	mut node_connections := []OutgoingNodeConnection{cap: node.output_connection_records().len}
	for connection in node.output_connection_records() {
		node_connections << OutgoingNodeConnection{
			destination: connection.destination_id
			output_index: int(connection.output)
			input_index: int(connection.input)
		}
	}
	mut param_connections := []OutgoingParamConnection{cap: node.param_connection_records().len}
	for connection in node.param_connection_records() {
		parameter := node.graph.render_params_[connection.parameter_id] or { continue }
		param_connections << OutgoingParamConnection{
			destination: parameter
			output_index: int(connection.output)
		}
	}
	node.enqueue_control_message(ControlMessage{
		kind: .replace_connections
		node_id: node.id
		node_connections: node_connections
		param_connections: param_connections
	})
}

pub fn (node AudioNode) queue_channel_config_update() {
	node.enqueue_control_message(ControlMessage{
		kind: .set_channel_config
		node_id: node.id
		channel_count: int(node.channel_count)
		channel_count_mode: node.channel_count_mode
		channel_interpretation: node.channel_interpretation
	})
}

pub fn (node AudioNode) queue_render_node_removal() {
	node.enqueue_control_message(ControlMessage{
		kind: .remove_node
		node_id: node.id
	})
}

pub fn connect_nodes(mut source AudioNode, mut destination AudioNode, output u32, input u32) ! {
	connection := AudioNodeConnection{
		source_id: source.id
		destination_id: destination.id
		output: output
		input: input
	}
	mut output_connections := source.output_connection_records()
	if connection in output_connections {
		return
	}
	if source.context_id != destination.context_id {
		return error('InvalidAccessError: Cannot connect nodes from different AudioContexts')
	}
	if output >= source.number_of_outputs {
		return error('IndexSizeError: Output index exceeds number of outputs')
	}
	if input >= destination.number_of_inputs {
		return error('IndexSizeError: Input index exceeds number of inputs')
	}
	output_connections << connection
	source.graph.output_connections[source.id] = output_connections
	mut input_connections := destination.input_connection_records()
	input_connections << connection
	destination.graph.input_connections[destination.id] = input_connections
	source.queue_connection_update()
}

pub fn connect_param(mut source AudioNode, parameter AudioParam, output u32) ! {
	connection := AudioParamConnection{
		source_id: source.id
		parameter_id: parameter.id
		output: output
	}
	mut param_connections := source.param_connection_records()
	if connection in param_connections {
		return
	}
	if source.context_id != parameter.context_id {
		return error('InvalidAccessError: Cannot connect parameter from a different AudioContext')
	}
	if output >= source.number_of_outputs {
		return error('IndexSizeError: Output index exceeds number of outputs')
	}
	param_connections << connection
	source.graph.param_connections[source.id] = param_connections
	source.queue_connection_update()
}

pub fn (mut node AudioNode) disconnect_all() {
	for connection in node.output_connection_records() {
		mut reverse_connections := node.graph.input_connections[connection.destination_id] or {
			[]AudioNodeConnection{}
		}
		reverse_connections = reverse_connections.filter(it.source_id != node.id)
		node.graph.input_connections[connection.destination_id] = reverse_connections
	}
	node.graph.output_connections[node.id] = []
	node.graph.param_connections[node.id] = []
	node.queue_connection_update()
}

pub fn (mut node AudioNode) disconnect_output(output u32) ! {
	if output >= node.number_of_outputs {
		return error('IndexSizeError: Output index exceeds number of outputs')
	}
	mut output_connections := node.output_connection_records()
	for connection in output_connections {
		if connection.output != output {
			continue
		}
		mut reverse_connections := node.graph.input_connections[connection.destination_id] or {
			[]AudioNodeConnection{}
		}
		reverse_connections = reverse_connections.filter(!(it.source_id == node.id && it.output == output))
		node.graph.input_connections[connection.destination_id] = reverse_connections
	}
	output_connections = output_connections.filter(it.output != output)
	node.graph.output_connections[node.id] = output_connections
	node.graph.param_connections[node.id] = node.param_connection_records().filter(it.output != output)
	node.queue_connection_update()
}

pub fn (mut node AudioNode) disconnect_destination(destination_id u64, output ?u32, input ?u32) ! {
	if actual := output {
		if actual >= node.number_of_outputs {
			return error('IndexSizeError: Output index exceeds number of outputs')
		}
	}
	has_output := output != none
	has_input := input != none
	output_value := output or { u32(0) }
	input_value := input or { u32(0) }
	mut output_connections := node.output_connection_records()
	before := output_connections.len
	removed := output_connections.filter(it.destination_id == destination_id && (!has_output || it.output == output_value) && (!has_input || it.input == input_value))
	output_connections = output_connections.filter(!(it.destination_id == destination_id && (!has_output || it.output == output_value) && (!has_input || it.input == input_value)))
	if before == output_connections.len {
		return error('InvalidAccessError: No matching AudioNode connection')
	}
	node.graph.output_connections[node.id] = output_connections
	mut reverse_connections := node.graph.input_connections[destination_id] or {
		[]AudioNodeConnection{}
	}
	for connection in removed {
		reverse_connections = reverse_connections.filter(!(it.source_id == node.id && it.output == connection.output && it.input == connection.input))
	}
	node.graph.input_connections[destination_id] = reverse_connections
	node.queue_connection_update()
}

// Faithful two-sided form of the AudioNode destination overload. Callers that
// keep nodes as values pass both endpoints so reverse connection state can be
// updated just as upstream's shared GC objects are.
pub fn disconnect_nodes(mut source AudioNode, mut destination AudioNode, output ?u32, input ?u32) ! {
	if actual := output {
		if actual >= source.number_of_outputs {
			return error('IndexSizeError: Output index exceeds number of outputs')
		}
	}
	if actual := input {
		if actual >= destination.number_of_inputs {
			return error('IndexSizeError: Input index exceeds number of inputs')
		}
	}
	source.disconnect_destination(destination.id, output, input)!
}

pub fn (mut node AudioNode) disconnect_parameter(parameter_id u64, output ?u32) ! {
	if actual := output {
		if actual >= node.number_of_outputs {
			return error('IndexSizeError: Output index exceeds number of outputs')
		}
	}
	has_output := output != none
	output_value := output or { u32(0) }
	mut connections := node.param_connection_records()
	before := connections.len
	connections = connections.filter(!(it.parameter_id == parameter_id && (!has_output || it.output == output_value)))
	if before == connections.len {
		return error('InvalidAccessError: No matching AudioParam connection')
	}
	node.graph.param_connections[node.id] = connections
	node.queue_connection_update()
}

pub fn (mut node AudioNode) start(when f64) ! {
	if node.source_started {
		return error('InvalidStateError: AudioScheduledSourceNode has already been started')
	}
	if when < 0 {
		return error('RangeError: when must not be negative')
	}
	node.source_started = true
	node.graph.playing_sources[node.id] = true
	node.enqueue_control_message(ControlMessage{
		kind: .start_source
		node_id: node.id
		when: when
	})
}

pub fn (node AudioNode) stop(when f64) ! {
	if !node.source_started {
		return error('InvalidStateError: AudioScheduledSourceNode has not been started')
	}
	if when < 0 {
		return error('RangeError: when must not be negative')
	}
	node.enqueue_control_message(ControlMessage{
		kind: .stop_source
		node_id: node.id
		when: when
	})
}

pub enum ControlMessageKind {
	add_node
	remove_node
	replace_connections
	set_channel_config
	node_message
	start_source
	stop_source
}

pub struct ControlMessage {
pub:
	kind                   ControlMessageKind
	node_id                u64
	when                   f64
	render_node            ?&RenderNode
	node_connections       []OutgoingNodeConnection
	param_connections      []OutgoingParamConnection
	channel_count          int
	channel_count_mode     ChannelCountMode
	channel_interpretation ChannelInterpretation
	node_message           ?NodeMessage
}

pub struct ControlMessageQueue {
pub mut:
	messages []ControlMessage
}

pub fn (mut queue ControlMessageQueue) enqueue(message ControlMessage) {
	queue.messages << message
}

pub fn (mut queue ControlMessageQueue) drain() []ControlMessage {
	messages := queue.messages.clone()
	queue.messages.clear()
	return messages
}

// These helpers retain the context association that is implicit in upstream's
// GC-backed AudioScheduledSourceNode and enqueue the same control messages.
pub fn start_scheduled_source(mut context BaseAudioContext, mut node AudioNode, when f64) ! {
	has_node_queue := node.graph.control_messages_ != none
	node.start(when)!
	if !has_node_queue {
		context.control_messages.enqueue(ControlMessage{
			kind: .start_source
			node_id: node.id
			when: when
		})
	}
	context.add_playing_source(node)
}

pub fn stop_scheduled_source(mut context BaseAudioContext, node AudioNode, when f64) ! {
	has_node_queue := node.graph.control_messages_ != none
	node.stop(when)!
	if !has_node_queue {
		context.control_messages.enqueue(ControlMessage{
			kind: .stop_source
			node_id: node.id
			when: when
		})
	}
}
