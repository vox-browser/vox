// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/RenderNode, Rendering/RenderGraph, and the common
// rendering-side control-message plumbing.
module webaudio

import math

pub struct RenderContext {
pub:
	sample_rate         f64
	quantum_size        int
	quantum_start_frame u64
}

pub fn (context RenderContext) quantum_start_time() f64 {
	return f64(context.quantum_start_frame) / context.sample_rate
}

pub fn (context RenderContext) sample_period() f64 {
	return 1.0 / context.sample_rate
}

pub fn (context RenderContext) frame_time(frame int) f64 {
	return f64(context.quantum_start_frame + u64(frame)) / context.sample_rate
}

pub enum NodeMessageKind {
	start_source
	stop_source
	start_buffer_source
	set_buffer_source_parameters
	set_oscillator_waveform
	set_biquad_filter_type
	set_panner_parameters
	set_media_stream_source_ring
}

pub struct NodeMessage {
pub:
	node_id          u64
	kind             NodeMessageKind
	when             f64
	oscillator_type  OscillatorType = .sine
	periodic_wave    ?&PeriodicWaveData
	offset           f64
	duration         ?f64
	buffer           ?&AudioBufferContents
	loop_            bool
	loop_start       f64
	loop_end         f64
	update_buffer    bool
	biquad_type      BiquadFilterType = .lowpass
	panning_model    PanningModelType = .equalpower
	distance_model   DistanceModelType = .inverse
	ref_distance     f64 = 1
	max_distance     f64 = 10_000
	rolloff_factor   f64 = 1
	cone_inner_angle f64 = 360
	cone_outer_angle f64 = 360
	cone_outer_gain  f64
}

pub fn node_message_target(message NodeMessage) u64 {
	return message.node_id
}

pub struct RenderAudioParamInput {
pub:
	source       u64
	output_index int
}

@[heap]
pub struct RenderAudioParam {
mut:
	timeline_        &AudioParamTimeline
	min_value_       f32
	max_value_       f32
	automation_rate_ AutomationRate
	inputs_          []RenderAudioParamInput
	input_scratch_   ?&AudioBus
}

pub fn RenderAudioParam.create(timeline &AudioParamTimeline, min_value f32, max_value f32,
	automation_rate AutomationRate) &RenderAudioParam {
	return &RenderAudioParam{
		timeline_: timeline
		min_value_: min_value
		max_value_: max_value
		automation_rate_: automation_rate
	}
}

pub fn (mut parameter RenderAudioParam) set_automation_rate(automation_rate AutomationRate) {
	parameter.automation_rate_ = automation_rate
}

pub fn (parameter &RenderAudioParam) automation_rate() AutomationRate {
	return parameter.automation_rate_
}

pub fn (parameter &RenderAudioParam) inputs() []RenderAudioParamInput {
	return parameter.inputs_.clone()
}

pub fn (mut parameter RenderAudioParam) add_input(input RenderAudioParamInput) {
	parameter.inputs_ << input
}

pub fn (mut parameter RenderAudioParam) clear_inputs() {
	parameter.inputs_.clear()
}

// https://webaudio.github.io/web-audio-api/#computedvalue
pub fn (mut parameter RenderAudioParam) compute(mut graph RenderGraph,
	context RenderContext, mut output []f32) {
	if output.len == 0 { return }
	if parameter.automation_rate_ == .k_rate {
		mut first_sample := output[..1]
		parameter.timeline_.sample(context.quantum_start_time(), 0, mut first_sample)
		value := output[0]
		for frame in 0 .. output.len {
			output[frame] = value
		}
	} else {
		parameter.timeline_.sample(context.quantum_start_time(), context.sample_period(), mut output)
	}

	for input in parameter.inputs_ {
		bus := graph.pull_output(input.source, input.output_index, context) or { continue }
		mut scratch := parameter.input_scratch_ or {
			new_scratch := AudioBus.create(1, context.quantum_size)
			parameter.input_scratch_ = new_scratch
			new_scratch
		}
		if scratch.frame_count() != context.quantum_size {
			scratch = AudioBus.create(1, context.quantum_size)
			parameter.input_scratch_ = scratch
		}
		scratch.zero()
		scratch.sum_from(bus, .speakers)
		input_samples := scratch.channel(0)
		if parameter.automation_rate_ == .k_rate {
			for frame in 0 .. output.len {
				output[frame] += input_samples[0]
			}
		} else {
			for frame in 0 .. min_int(output.len, input_samples.len) {
				output[frame] += input_samples[frame]
			}
		}
	}

	default_value := parameter.timeline_.default_value()
	for frame in 0 .. output.len {
		if math.is_nan(output[frame]) {
			output[frame] = default_value
		}
		if output[frame] < parameter.min_value_ {
			output[frame] = parameter.min_value_
		}
		if output[frame] > parameter.max_value_ {
			output[frame] = parameter.max_value_
		}
	}
}

pub struct RenderNodeConnection {
pub:
	source       u64
	output_index int
}

pub struct OutgoingNodeConnection {
pub:
	destination  u64
	output_index int
	input_index  int
}

pub struct OutgoingParamConnection {
pub:
	destination  &RenderAudioParam
	output_index int
}

pub type RenderNodeProcessCallback = fn (mut RenderNode, mut RenderGraph, RenderContext)

pub type RenderNodeMessageCallback = fn (mut RenderNode, NodeMessage)

pub type RenderAudioParamCallback = fn (mut RenderAudioParam)

@[heap]
pub struct RenderNode {
mut:
	node_id_                    u64
	channel_count_              int = 2
	channel_count_mode_         ChannelCountMode = .max
	channel_interpretation_     ChannelInterpretation = .speakers
	input_connections_          [][]RenderNodeConnection
	input_buses_                []&AudioBus
	outputs_                    []&AudioBus
	outgoing_node_connections_  []OutgoingNodeConnection
	outgoing_param_connections_ []OutgoingParamConnection
	params_                     []&RenderAudioParam
	processed_quantum_          u64 = max_u64
	is_processing_              bool
	ended_notification_         bool
	process_callback_           ?RenderNodeProcessCallback
	message_callback_           ?RenderNodeMessageCallback
}

pub fn RenderNode.create(node_id u64, input_count int, output_count int, quantum_size int,
	output_channel_count int) &RenderNode {
	mut input_buses := []&AudioBus{cap: input_count}
	for _ in 0 .. input_count {
		input_buses << AudioBus.create(1, quantum_size)
	}
	mut outputs := []&AudioBus{cap: output_count}
	for _ in 0 .. output_count {
		outputs << AudioBus.create(output_channel_count, quantum_size)
	}
	return &RenderNode{
		node_id_: node_id
		input_connections_: [][]RenderNodeConnection{len: input_count}
		input_buses_: input_buses
		outputs_: outputs
	}
}

pub fn (node &RenderNode) node_id() u64 {
	return node.node_id_
}

pub fn (node &RenderNode) input_count() int {
	return node.input_connections_.len
}

pub fn (node &RenderNode) output_count() int {
	return node.outputs_.len
}

pub fn (node &RenderNode) output(index int) &AudioBus {
	return node.outputs_[index]
}

pub fn (mut node RenderNode) set_channel_count(channel_count int) {
	node.channel_count_ = channel_count
}

pub fn (mut node RenderNode) set_channel_count_mode(mode ChannelCountMode) {
	node.channel_count_mode_ = mode
}

pub fn (mut node RenderNode) set_channel_interpretation(
	interpretation ChannelInterpretation) {
	node.channel_interpretation_ = interpretation
}

pub fn (node &RenderNode) channel_count() int {
	return node.channel_count_
}

pub fn (node &RenderNode) channel_count_mode() ChannelCountMode {
	return node.channel_count_mode_
}

pub fn (node &RenderNode) channel_interpretation() ChannelInterpretation {
	return node.channel_interpretation_
}

pub fn (node &RenderNode) input_connections(input_index int) []RenderNodeConnection {
	return node.input_connections_[input_index].clone()
}

pub fn (mut node RenderNode) set_outgoing_connections(
	node_connections []OutgoingNodeConnection, param_connections []OutgoingParamConnection) {
	node.outgoing_node_connections_ = node_connections.clone()
	node.outgoing_param_connections_ = param_connections.clone()
}

pub fn (node &RenderNode) outgoing_node_connections() []OutgoingNodeConnection {
	return node.outgoing_node_connections_.clone()
}

pub fn (node &RenderNode) outgoing_param_connections() []OutgoingParamConnection {
	return node.outgoing_param_connections_.clone()
}

pub fn (mut node RenderNode) set_process_callback(callback RenderNodeProcessCallback) {
	node.process_callback_ = callback
}

pub fn (mut node RenderNode) set_message_callback(callback RenderNodeMessageCallback) {
	node.message_callback_ = callback
}

pub fn (mut node RenderNode) add_param(parameter &RenderAudioParam) {
	node.params_ << parameter
}

pub fn (mut node RenderNode) process(mut graph RenderGraph, context RenderContext) {
	if callback := node.process_callback_ {
		callback(mut node, mut graph, context)
		return
	}
	for output in node.outputs_ {
		mut mutable_output := unsafe { &AudioBus(output) }
		mutable_output.zero()
	}
}

pub fn (mut node RenderNode) handle_message(message NodeMessage) {
	if callback := node.message_callback_ {
		callback(mut node, message)
	}
}

pub fn (mut node RenderNode) for_each_param(callback RenderAudioParamCallback) {
	for parameter in node.params_ {
		mut mutable_parameter := unsafe { &RenderAudioParam(parameter) }
		callback(mut mutable_parameter)
	}
}

pub fn (mut node RenderNode) take_ended_notification() bool {
	if !node.ended_notification_ {
		return false
	}
	node.ended_notification_ = false
	return true
}

pub fn (mut node RenderNode) mark_ended() {
	node.ended_notification_ = true
}

pub fn (node &RenderNode) processed_in_quantum(quantum u64) bool {
	return node.processed_quantum_ == quantum
}

pub fn (mut node RenderNode) mark_processed_in_quantum(quantum u64) {
	node.processed_quantum_ = quantum
}

pub fn (node &RenderNode) is_processing() bool {
	return node.is_processing_
}

pub fn (mut node RenderNode) set_is_processing(is_processing bool) {
	node.is_processing_ = is_processing
}

// Pull and mix every connection to one input using the node's channel rules.
pub fn (mut node RenderNode) pull_input(mut graph RenderGraph, context RenderContext,
	input_index int) &AudioBus {
	mut source_buses := []&AudioBus{}
	for connection in node.input_connections_[input_index] {
		if bus := graph.pull_output(connection.source, connection.output_index, context) {
			if bus.channel_count() > 0 {
				source_buses << bus
			}
		}
	}
	mut input_bus := unsafe { &AudioBus(node.input_buses_[input_index]) }
	if source_buses.len == 0 {
		input_bus.set_channel_count(1)
		input_bus.zero()
		return input_bus
	}
	mut computed_channel_count := 0
	if node.channel_count_mode_ in [.max, .clamped_max] {
		for bus in source_buses {
			computed_channel_count = max_int(computed_channel_count, bus.channel_count())
		}
		if node.channel_count_mode_ == .clamped_max {
			computed_channel_count = min_int(computed_channel_count, node.channel_count_)
		}
	} else {
		computed_channel_count = node.channel_count_
	}
	input_bus.set_channel_count(computed_channel_count)
	input_bus.zero()
	for bus in source_buses {
		input_bus.sum_from(bus, node.channel_interpretation_)
	}
	return input_bus
}

@[heap]
pub struct RenderGraph {
mut:
	nodes_                      map[u64]&RenderNode
	destination_id_             u64
	current_quantum_            u64
	incoming_connections_dirty_ bool
}

pub fn RenderGraph.create() &RenderGraph {
	return &RenderGraph{}
}

pub fn (mut graph RenderGraph) apply_control_messages(messages []ControlMessage) {
	for message in messages {
		match message.kind {
			.add_node {
				render_node := message.render_node or { continue }
				graph.nodes_[render_node.node_id()] = render_node
				graph.incoming_connections_dirty_ = true
			}
			.remove_node {
				if message.node_id in graph.nodes_ {
					graph.nodes_.delete(message.node_id)
					graph.incoming_connections_dirty_ = true
				}
			}
			.replace_connections {
				if source := graph.nodes_[message.node_id] {
					mut mutable_source := unsafe { &RenderNode(source) }
					mutable_source.set_outgoing_connections(message.node_connections, message.param_connections)
					graph.incoming_connections_dirty_ = true
				}
			}
			.set_channel_config {
				if target := graph.nodes_[message.node_id] {
					mut mutable_target := unsafe { &RenderNode(target) }
					mutable_target.set_channel_count(message.channel_count)
					mutable_target.set_channel_count_mode(message.channel_count_mode)
					mutable_target.set_channel_interpretation(message.channel_interpretation)
				}
			}
			.node_message {
				node_message := message.node_message or { continue }
				if target := graph.nodes_[node_message_target(node_message)] {
					mut mutable_target := unsafe { &RenderNode(target) }
					mutable_target.handle_message(node_message)
				}
			}
			.start_source, .stop_source {
				if target := graph.nodes_[message.node_id] {
					mut mutable_target := unsafe { &RenderNode(target) }
					mutable_target.handle_message(NodeMessage{
						node_id: message.node_id
						kind: if message.kind == .start_source {
							NodeMessageKind.start_source
						} else {
							NodeMessageKind.stop_source
						}
						when: message.when
					})
				}
			}
		}
	}
}

pub fn (mut graph RenderGraph) render_quantum(context RenderContext) {
	graph.current_quantum_++
	if graph.incoming_connections_dirty_ {
		graph.rebuild_incoming_connections()
		graph.incoming_connections_dirty_ = false
	}
	if destination := graph.destination() {
		graph.pull_output(destination.node_id(), 0, context)
	}
	node_ids := graph.nodes_.keys()
	for node_id in node_ids {
		graph_node := graph.nodes_[node_id] or { continue }
		if graph_node.output_count() > 0 {
			graph.pull_output(node_id, 0, context)
		}
	}
}

pub fn (mut graph RenderGraph) pull_output(source u64, output_index int,
	context RenderContext) ?&AudioBus {
	source_node := graph.nodes_[source] or { return none }
	if output_index < 0 || output_index >= source_node.output_count() {
		return none
	}
	mut mutable_source := unsafe { &RenderNode(source_node) }
	if !mutable_source.processed_in_quantum(graph.current_quantum_) {
		if mutable_source.is_processing() {
			return mutable_source.output(output_index)
		}
		mutable_source.set_is_processing(true)
		mutable_source.process(mut graph, context)
		mutable_source.set_is_processing(false)
		mutable_source.mark_processed_in_quantum(graph.current_quantum_)
	}
	return mutable_source.output(output_index)
}

pub fn (graph &RenderGraph) node(node_id u64) ?&RenderNode {
	return graph.nodes_[node_id] or { return none }
}

pub fn (mut graph RenderGraph) set_destination(node_id u64) {
	graph.destination_id_ = node_id
}

pub fn (graph &RenderGraph) destination() ?&RenderNode {
	return graph.node(graph.destination_id_)
}

pub fn (mut graph RenderGraph) take_ended_nodes() []u64 {
	mut ended_nodes := []u64{}
	for node_id, graph_node in graph.nodes_ {
		mut mutable_node := unsafe { &RenderNode(graph_node) }
		if mutable_node.take_ended_notification() {
			ended_nodes << node_id
		}
	}
	for node_id in ended_nodes {
		graph.nodes_.delete(node_id)
	}
	if ended_nodes.len > 0 {
		graph.incoming_connections_dirty_ = true
	}
	return ended_nodes
}

pub fn (mut graph RenderGraph) rebuild_incoming_connections() {
	for _, graph_node in graph.nodes_ {
		mut mutable_node := unsafe { &RenderNode(graph_node) }
		for input in 0 .. mutable_node.input_connections_.len {
			mutable_node.input_connections_[input].clear()
		}
		for parameter in mutable_node.params_ {
			mut mutable_parameter := unsafe { &RenderAudioParam(parameter) }
			mutable_parameter.clear_inputs()
		}
	}
	for node_id, graph_node in graph.nodes_ {
		for connection in graph_node.outgoing_node_connections_ {
			if destination := graph.nodes_[connection.destination] {
				if connection.input_index >= 0
					&& connection.input_index < destination.input_count() {
					mut mutable_destination := unsafe { &RenderNode(destination) }
					mutable_destination.input_connections_[connection.input_index] << RenderNodeConnection{
						source: node_id
						output_index: connection.output_index
					}
				}
			}
		}
		for connection in graph_node.outgoing_param_connections_ {
			mut parameter := unsafe { &RenderAudioParam(connection.destination) }
			parameter.add_input(RenderAudioParamInput{
				source: node_id
				output_index: connection.output_index
			})
		}
	}
}
