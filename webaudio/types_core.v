// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Types.h, AudioParam, AudioNode, AudioScheduledSourceNode,
// ControlMessage, and ControlMessageQueue.
module webaudio

pub const max_number_of_channels = u32(32)
pub const min_sample_rate = f32(8_000)
pub const max_sample_rate = f32(192_000)
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
	current_value   f32
	automation_rate AutomationRate
}

pub fn new_audio_param(id u64, context_id u64, default_value f32, min_value f32, max_value f32, rate AutomationRate, fixed bool) AudioParam {
	return AudioParam{
		id:              id
		context_id:      context_id
		default_value:   default_value
		min_value:       min_value
		max_value:       max_value
		current_value:   default_value
		automation_rate: rate
		fixed_rate:      fixed
	}
}

pub fn (parameter AudioParam) value() f32 {
	if parameter.current_value < parameter.min_value { return parameter.min_value }
	if parameter.current_value > parameter.max_value { return parameter.max_value }
	return parameter.current_value
}

pub fn (mut parameter AudioParam) set_value(value f32) {
	parameter.current_value = value
}

pub fn (mut parameter AudioParam) set_automation_rate(rate AutomationRate) ! {
	if parameter.fixed_rate && rate != parameter.automation_rate {
		return error('InvalidStateError: Automation rate cannot be changed')
	}
	parameter.automation_rate = rate
}

// Automation scheduling is not yet implemented upstream. These fluent calls
// deliberately preserve its no-op/self-return behavior.
pub fn (mut parameter AudioParam) set_value_at_time(_ f32, _ f64) &AudioParam {
	return &parameter
}

pub fn (mut parameter AudioParam) linear_ramp_to_value_at_time(_ f32, _ f64) &AudioParam {
	return &parameter
}

pub fn (mut parameter AudioParam) exponential_ramp_to_value_at_time(_ f32, _ f64) &AudioParam {
	return &parameter
}

pub fn (mut parameter AudioParam) set_target_at_time(_ f32, _ f64, _ f32) &AudioParam {
	return &parameter
}

pub fn (mut parameter AudioParam) set_value_curve_at_time(_ []f32, _ f64, _ f64) &AudioParam {
	return &parameter
}

pub fn (mut parameter AudioParam) cancel_scheduled_values(_ f64) &AudioParam {
	return &parameter
}

pub fn (mut parameter AudioParam) cancel_and_hold_at_time(_ f64) &AudioParam {
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

pub struct AudioNode {
pub:
	id                u64
	context_id        u64
	kind              NodeKind
	number_of_inputs  u32
	number_of_outputs u32
pub mut:
	channel_count          u32                   = 2
	channel_count_mode     ChannelCountMode      = .max
	channel_interpretation ChannelInterpretation = .speakers
	input_connections      []AudioNodeConnection
	output_connections     []AudioNodeConnection
	param_connections      []AudioParamConnection
	source_started         bool
	onended                bool
}

pub fn (mut node AudioNode) set_channel_count(count u32) ! {
	if count == 0 || count > max_number_of_channels {
		return error('NotSupportedError: Invalid channel count')
	}
	node.channel_count = count
}

pub fn (mut node AudioNode) initialize_options(options AudioNodeOptions, default_count u32, default_mode ChannelCountMode, default_interpretation ChannelInterpretation) ! {
	node.set_channel_count(options.channel_count or { default_count })!
	node.channel_count_mode = options.channel_count_mode or { default_mode }
	node.channel_interpretation = options.channel_interpretation or { default_interpretation }
}

pub fn connect_nodes(mut source AudioNode, mut destination AudioNode, output u32, input u32) ! {
	connection := AudioNodeConnection{
		source_id:      source.id
		destination_id: destination.id
		output:         output
		input:          input
	}
	if connection in source.output_connections { return }
	if source.context_id != destination.context_id {
		return error('InvalidAccessError: Cannot connect nodes from different AudioContexts')
	}
	if output >= source.number_of_outputs {
		return error('IndexSizeError: Output index exceeds number of outputs')
	}
	if input >= destination.number_of_inputs {
		return error('IndexSizeError: Input index exceeds number of inputs')
	}
	source.output_connections << connection
	destination.input_connections << connection
}

pub fn connect_param(mut source AudioNode, parameter AudioParam, output u32) ! {
	connection := AudioParamConnection{
		source_id:    source.id
		parameter_id: parameter.id
		output:       output
	}
	if connection in source.param_connections { return }
	if source.context_id != parameter.context_id {
		return error('InvalidAccessError: Cannot connect parameter from a different AudioContext')
	}
	if output >= source.number_of_outputs {
		return error('IndexSizeError: Output index exceeds number of outputs')
	}
	source.param_connections << connection
}

pub fn (mut node AudioNode) disconnect_all() {
	node.output_connections.clear()
	node.param_connections.clear()
}

pub fn (mut node AudioNode) disconnect_output(output u32) ! {
	if output >= node.number_of_outputs {
		return error('IndexSizeError: Output index exceeds number of outputs')
	}
	node.output_connections = node.output_connections.filter(it.output != output)
	node.param_connections = node.param_connections.filter(it.output != output)
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
	before := node.output_connections.len
	node.output_connections = node.output_connections.filter(!(it.destination_id == destination_id
		&& (!has_output || it.output == output_value) && (!has_input || it.input == input_value)))
	if before == node.output_connections.len {
		return error('InvalidAccessError: No matching AudioNode connection')
	}
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
	has_output := output != none
	has_input := input != none
	output_value := output or { u32(0) }
	input_value := input or { u32(0) }
	before := source.output_connections.len
	source.output_connections = source.output_connections.filter(!(
		it.destination_id == destination.id && (!has_output || it.output == output_value)
		&& (!has_input || it.input == input_value)))
	if before == source.output_connections.len {
		return error('InvalidAccessError: No matching AudioNode connection')
	}
	destination.input_connections = destination.input_connections.filter(!(
		it.source_id == source.id && (!has_output || it.output == output_value)
		&& (!has_input || it.input == input_value)))
}

pub fn (mut node AudioNode) disconnect_parameter(parameter_id u64, output ?u32) ! {
	if actual := output {
		if actual >= node.number_of_outputs {
			return error('IndexSizeError: Output index exceeds number of outputs')
		}
	}
	has_output := output != none
	output_value := output or { u32(0) }
	before := node.param_connections.len
	node.param_connections = node.param_connections.filter(!(it.parameter_id == parameter_id
		&& (!has_output || it.output == output_value)))
	if before == node.param_connections.len {
		return error('InvalidAccessError: No matching AudioParam connection')
	}
}

pub fn (mut node AudioNode) start(when f64) ! {
	if node.source_started {
		return error('InvalidStateError: AudioScheduledSourceNode has already been started')
	}
	if when < 0 { return error('RangeError: when must not be negative') }
	node.source_started = true
}

pub fn (node AudioNode) stop(when f64) ! {
	if !node.source_started {
		return error('InvalidStateError: AudioScheduledSourceNode has not been started')
	}
	if when < 0 { return error('RangeError: when must not be negative') }
}

pub enum ControlMessageKind {
	start_source
	stop_source
}
pub struct ControlMessage {
pub:
	kind    ControlMessageKind
	node_id u64
	when    f64
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
	node.start(when)!
	context.control_messages.enqueue(ControlMessage{
		kind:    .start_source
		node_id: node.id
		when:    when
	})
}

pub fn stop_scheduled_source(mut context BaseAudioContext, node AudioNode, when f64) ! {
	node.stop(when)!
	context.control_messages.enqueue(ControlMessage{
		kind:    .stop_source
		node_id: node.id
		when:    when
	})
}
