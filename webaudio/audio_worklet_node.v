// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioWorkletNode and Rendering/AudioWorkletRenderNode,
// including the AudioWorkletGlobalScope rendering pump.
module webaudio

import html

const audio_worklet_target_latency_ms = u32(100)

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}

pub struct AudioWorkletNodeOptions {
pub:
	node                 AudioNodeOptions
	number_of_inputs     u32 = 1
	number_of_outputs    u32 = 1
	output_channel_count ?[]u32
	parameter_data       map[string]f64
	processor_options    map[string]string
}

pub type AudioWorkletProcessorErrorCallback = fn (string)

pub type AudioWorkletParamCallback = fn (&AudioParam)

@[heap]
pub struct AudioWorkletProcessorSlot {
pub:
	node_id         u64
	processor       &AudioWorkletProcessor
	processor_port  &html.MessagePort
	node            &AudioWorkletNode
	pipe            &AudioWorkletPipe
	parameter_names []string
mut:
	failed bool
}

@[heap]
pub struct AudioWorkletRenderNode {
pub:
	node_id                   u64
	input_count               u32
	output_count              u32
	quantum_size              int
	output_channel_capacities []u32
mut:
	pipe_                  &AudioWorkletPipe
	params_                []&AudioParam
	output_channel_counts_ []u32
}

fn new_audio_worklet_render_node(node_id u64, input_count u32, output_count u32,
	quantum_size int, output_channel_capacities []u32, pipe &AudioWorkletPipe,
	params []&AudioParam) &AudioWorkletRenderNode {
	return &AudioWorkletRenderNode{
		node_id: node_id
		input_count: input_count
		output_count: output_count
		quantum_size: quantum_size
		output_channel_capacities: output_channel_capacities.clone()
		pipe_: pipe
		params_: params.clone()
		output_channel_counts_: []u32{len: int(output_count), init: 1}
	}
}

pub fn (render_node &AudioWorkletRenderNode) for_each_param(
	callback AudioWorkletParamCallback) {
	for parameter in render_node.params_ {
		callback(parameter)
	}
}

fn audio_worklet_parameter_block(parameter &AudioParam, start_frame u64, sample_rate f32,
	quantum_size int) []f32 {
	block_length := if parameter.automation_rate == .a_rate { quantum_size } else { 1 }
	mut block := []f32{len: block_length}
	mut timeline := unsafe { &AudioParamTimeline(parameter.timeline) }
	period := if parameter.automation_rate == .a_rate { 1.0 / f64(sample_rate) } else { 0.0 }
	timeline.sample(f64(start_frame) / f64(sample_rate), period, mut block)
	for index, value in block {
		block[index] = if value < parameter.min_value { parameter.min_value }
			else if value > parameter.max_value { parameter.max_value } else { value }
	}
	return block
}

@[heap]
struct AudioWorkletRenderedOutput {
mut:
	channels [][][]f32
}

fn silent_audio_worklet_outputs(channel_counts []u32, quantum_size int) [][][]f32 {
	mut outputs := [][][]f32{cap: channel_counts.len}
	for channel_count in channel_counts {
		outputs << [][]f32{len: int(channel_count), init: []f32{len: quantum_size}}
	}
	return outputs
}

// Exchanges one render quantum with the worklet pump. As upstream does, this
// consumes already-produced output and emits silence during an underrun.
pub fn (mut render_node AudioWorkletRenderNode) process(inputs [][][]f32,
	start_frame u64) [][][]f32 {
	config := render_node.pipe_.config()
	params := render_node.params_.clone()
	mut pipe := unsafe { &AudioWorkletPipe(render_node.pipe_) }
	pipe.try_push_input(fn [inputs, params, config, start_frame] (mut slot AudioWorkletInputSlot) {
		slot.set_start_frame(start_frame)
		for input in 0 .. int(config.input_count) {
			if input >= inputs.len || inputs[input].len == 0 {
				slot.set_actual_channel_count(input, 0)
				continue
			}
			channel_count := min_int(inputs[input].len, int(config.input_channel_capacity[input]))
			slot.set_actual_channel_count(input, u32(channel_count))
			for channel in 0 .. channel_count {
				mut samples := []f32{len: config.quantum_size}
				frames := min_int(inputs[input][channel].len, config.quantum_size)
				for frame in 0 .. frames {
					samples[frame] = inputs[input][channel][frame]
				}
				slot.set_input_channel(input, channel, samples)
			}
		}
		for parameter, audio_param in params {
			slot.set_param_block(parameter, audio_worklet_parameter_block(audio_param, start_frame, config.sample_rate, config.quantum_size))
		}
	})
	pipe.request_wakeup()

	mut rendered := &AudioWorkletRenderedOutput{
		channels: silent_audio_worklet_outputs(render_node.output_channel_counts_, render_node.quantum_size)
	}
	popped := pipe.try_pop_output(fn [mut rendered, config] (slot AudioWorkletOutputSlot) {
		mut channel_counts := []u32{cap: int(config.output_count)}
		for output in 0 .. int(config.output_count) {
			channel_count := min_int(int(slot.actual_channel_count(output)), int(config.output_channel_capacity[output]))
			channel_counts << u32(max_int(channel_count, 1))
		}
		rendered.channels = silent_audio_worklet_outputs(channel_counts, config.quantum_size)
		for output in 0 .. int(config.output_count) {
			channel_count := int(slot.actual_channel_count(output))
			for channel in 0 .. min_int(channel_count, rendered.channels[output].len) {
				source := slot.output_channel(output, channel)
				for frame in 0 .. min_int(source.len, rendered.channels[output][channel].len) {
					rendered.channels[output][channel][frame] = source[frame]
				}
			}
		}
	})
	if !popped {
		return rendered.channels
	}
	for output in 0 .. rendered.channels.len {
		render_node.output_channel_counts_[output] = u32(rendered.channels[output].len)
	}
	if pipe.output_occupancy() > config.prime_level {
		pipe.discard_outputs_down_to(config.prime_level)
	}
	return rendered.channels
}

@[heap]
pub struct AudioWorkletNode {
pub mut:
	node AudioNode
mut:
	name_                     string
	parameter_map_            &AudioParamMap
	port_                     &html.MessagePort
	processor_                ?&AudioWorkletProcessor
	processor_errored_        bool
	processor_error_messages_ []string
	onprocessorerror_         ?AudioWorkletProcessorErrorCallback
	pipe_                     &AudioWorkletPipe
	render_node_              &AudioWorkletRenderNode
	global_scope_             &AudioWorkletGlobalScope
}

pub fn AudioWorkletNode.create(mut context BaseAudioContext, name string,
	options AudioWorkletNodeOptions) !&AudioWorkletNode {
	mut worklet := context.audio_worklet()
	definition := worklet.find_definition(name) or {
		return error("InvalidStateError: No AudioWorkletProcessor named '${name}' is registered")
	}
	if options.number_of_inputs == 0 && options.number_of_outputs == 0 {
		return error('NotSupportedError: AudioWorkletNode must have at least one input or output')
	}
	has_explicit_output_channels := options.output_channel_count != none
	output_channel_counts := options.output_channel_count or { []u32{} }
	if has_explicit_output_channels {
		if output_channel_counts.len != int(options.number_of_outputs) {
			return error('IndexSizeError: outputChannelCount length must equal numberOfOutputs')
		}
		for channel_count in output_channel_counts {
			if channel_count == 0 || channel_count > max_number_of_channels {
				return error('NotSupportedError: outputChannelCount entries must be between 1 and 32')
			}
		}
	}

	node_base := context.allocate_node(.audio_worklet, options.number_of_inputs, options.number_of_outputs, options.node, 2, .max, .speakers)!
	mut parameter_map := AudioParamMap.create()
	for descriptor in definition.parameter_descriptors {
		mut parameter := context.allocate_param(descriptor.default_value, descriptor.min_value, descriptor.max_value, descriptor.automation_rate, false)
		if override := options.parameter_data[descriptor.name] {
			parameter.set_value(f32(override))!
		}
		parameter_map.set_entry(descriptor.name, &parameter)
	}

	mut node_port := html.MessagePort.create()
	mut processor_port := html.MessagePort.create()
	node_port.entangle_with(processor_port)
	node_port.enable()
	scope := worklet.audio_worklet_global_scope() or {
		return error('InvalidStateError: AudioWorklet has no global scope')
	}

	mut pipe_config := AudioWorkletPipeConfig{
		quantum_size: int(render_quantum_size)
		sample_rate: context.sample_rate
		input_count: options.number_of_inputs
		output_count: options.number_of_outputs
		input_channel_capacity: []u32{len: int(options.number_of_inputs), init: max_number_of_channels}
		output_channel_count_matches_input: options.number_of_inputs == 1
			&& options.number_of_outputs == 1 && !has_explicit_output_channels
		param_count: u32(definition.parameter_descriptors.len)
		param_is_a_rate: definition.parameter_descriptors.map(it.automation_rate == .a_rate)
	}
	for output in 0 .. int(options.number_of_outputs) {
		pipe_config.output_channel_capacity << if has_explicit_output_channels {
			output_channel_counts[output]
		} else if pipe_config.output_channel_count_matches_input {
			max_number_of_channels
		} else {
			u32(1)
		}
	}
	sizing := AudioWorkletPipeConfig.ring_sizing_for_device_latency(audio_worklet_target_latency_ms, context.sample_rate, int(render_quantum_size))
	pipe_config.ring_capacity = sizing.ring_capacity
	pipe_config.prime_level = sizing.prime_level
	mut pipe := AudioWorkletPipe.create(pipe_config)!
	pipe.prime_outputs_with_silence(pipe_config.prime_level)
	params := parameter_map.values()
	render_node := new_audio_worklet_render_node(node_base.id, options.number_of_inputs, options.number_of_outputs, int(render_quantum_size), pipe_config.output_channel_capacity, pipe, params)
	mut node := &AudioWorkletNode{
		node: node_base
		name_: name
		parameter_map_: parameter_map
		port_: node_port
		pipe_: pipe
		render_node_: render_node
		global_scope_: scope
	}
	scope_pointer := scope
	node_id := node.node.id
	pipe.set_pump_callback(fn [scope_pointer, node_id] () {
		mut mutable_scope := unsafe { &AudioWorkletGlobalScope(scope_pointer) }
		mutable_scope.pump(node_id)
	})

	processor_options := AudioWorkletProcessorOptions{
		number_of_inputs: options.number_of_inputs
		number_of_outputs: options.number_of_outputs
		output_channel_count: output_channel_counts.clone()
		parameter_data: options.parameter_data.clone()
		processor_options: options.processor_options.clone()
	}
	node_pointer := node
	scope_pointer_for_constructor := scope
	processor_port_pointer := processor_port
	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), none, fn [node_pointer, scope_pointer_for_constructor, processor_port_pointer, processor_options] () {
		mut mutable_node := unsafe { &AudioWorkletNode(node_pointer) }
		mutable_node.invoke_processor_constructor(scope_pointer_for_constructor, processor_port_pointer, processor_options)
	})
	return node
}

pub fn AudioWorkletNode.construct_impl(mut context BaseAudioContext, name string,
	options AudioWorkletNodeOptions) !&AudioWorkletNode {
	return AudioWorkletNode.create(mut context, name, options)
}

fn (mut node AudioWorkletNode) invoke_processor_constructor(scope &AudioWorkletGlobalScope,
	processor_port &html.MessagePort, options AudioWorkletProcessorOptions) {
	definition := scope.find_definition(node.name_) or {
		node.fail_processor("No AudioWorkletProcessor named '${node.name_}' is registered")
		return
	}
	mut mutable_scope := unsafe { &AudioWorkletGlobalScope(scope) }
	mutable_scope.set_pending_processor_construction_data(PendingProcessorConstructionData{
		port: processor_port
	})
	processor := definition.factory(options, scope) or {
		_ = mutable_scope.take_pending_processor_construction_data()
		node.fail_processor(err.msg())
		return
	}
	_ = mutable_scope.take_pending_processor_construction_data()
	node.processor_ = processor
	mutable_scope.add_processor_slot(&AudioWorkletProcessorSlot{
		node_id: node.node.id
		processor: processor
		processor_port: processor_port
		node: &node
		pipe: node.pipe_
		parameter_names: node.parameter_map_.keys()
	})
	mut mutable_port := unsafe { &html.MessagePort(processor_port) }
	mutable_port.enable()
}

fn (mut node AudioWorkletNode) fail_processor(message string) {
	node.processor_errored_ = true
	mut pipe := unsafe { &AudioWorkletPipe(node.pipe_) }
	pipe.set_state(.failed)
	node.fire_processor_error(message)
}

pub fn (mut node AudioWorkletNode) fire_processor_error(message string) {
	node_pointer := unsafe { &node }
	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), none, fn [node_pointer, message] () {
		mut mutable_node := unsafe { &AudioWorkletNode(node_pointer) }
		mutable_node.processor_error_messages_ << message
		if callback := mutable_node.onprocessorerror_ {
			callback(message)
		}
	})
}

pub fn (node &AudioWorkletNode) parameters() &AudioParamMap {
	return node.parameter_map_
}

pub fn (node &AudioWorkletNode) port() &html.MessagePort {
	return node.port_
}

pub fn (node &AudioWorkletNode) processor() ?&AudioWorkletProcessor {
	return node.processor_
}

pub fn (node &AudioWorkletNode) pipe() &AudioWorkletPipe {
	return node.pipe_
}

pub fn (node &AudioWorkletNode) number_of_inputs() u32 {
	return node.node.number_of_inputs
}

pub fn (node &AudioWorkletNode) number_of_outputs() u32 {
	return node.node.number_of_outputs
}

pub fn (node &AudioWorkletNode) processor_errored() bool {
	return node.processor_errored_
}

pub fn (node &AudioWorkletNode) processor_error_messages() []string {
	return node.processor_error_messages_.clone()
}

pub fn (mut node AudioWorkletNode) set_onprocessorerror(
	callback AudioWorkletProcessorErrorCallback) {
	node.onprocessorerror_ = callback
}

pub fn (node &AudioWorkletNode) onprocessorerror() ?AudioWorkletProcessorErrorCallback {
	return node.onprocessorerror_
}

pub fn (mut node AudioWorkletNode) clear_onprocessorerror() {
	node.onprocessorerror_ = none
}

pub fn (mut node AudioWorkletNode) render(inputs [][][]f32, start_frame u64) [][][]f32 {
	return node.render_node_.process(inputs, start_frame)
}

pub fn (mut node AudioWorkletNode) finalize() {
	mut pipe := unsafe { &AudioWorkletPipe(node.pipe_) }
	pipe.clear_pump_callback()
	pipe.request_shutdown()
	mut scope := unsafe { &AudioWorkletGlobalScope(node.global_scope_) }
	scope.remove_processor_slot(node.node.id)
}

pub fn (mut scope AudioWorkletGlobalScope) add_processor_slot(slot &AudioWorkletProcessorSlot) {
	scope.processor_slots_[slot.node_id] = slot
}

pub fn (mut scope AudioWorkletGlobalScope) remove_processor_slot(node_id u64) {
	scope.processor_slots_.delete(node_id)
}

pub fn (scope &AudioWorkletGlobalScope) has_processor_slot(node_id u64) bool {
	return node_id in scope.processor_slots_
}

@[heap]
struct AudioWorkletPumpIteration {
mut:
	processed       bool
	output_full     bool
	failure_message ?string
}

pub fn (mut scope AudioWorkletGlobalScope) pump(node_id u64) {
	mut slot := scope.processor_slots_[node_id] or { return }
	mut pipe := unsafe { &AudioWorkletPipe(slot.pipe) }
	pipe.clear_wakeup_flag()
	if pipe.state() == .shut_down {
		scope.remove_processor_slot(node_id)
		return
	}
	if slot.failed {
		return
	}
	config := pipe.config()
	for {
		if pipe.output_occupancy() == config.ring_capacity {
			break
		}
		mut iteration := &AudioWorkletPumpIteration{}
		pipe.try_pop_input(fn [mut iteration, slot, config, mut scope, mut pipe] (input_slot AudioWorkletInputSlot) {
			iteration.processed = true
			scope.set_current_frame_and_time(input_slot.start_frame(), f64(input_slot.start_frame()) / f64(config.sample_rate))
			mut inputs := [][][]f32{cap: int(config.input_count)}
			for input in 0 .. int(config.input_count) {
				mut channels := [][]f32{cap: int(input_slot.actual_channel_count(input))}
				for channel in 0 .. int(input_slot.actual_channel_count(input)) {
					channels << input_slot.input_channel(input, channel).clone()
				}
				inputs << channels
			}
			mut output_channel_counts := []u32{cap: int(config.output_count)}
			mut outputs := [][][]f32{cap: int(config.output_count)}
			for output in 0 .. int(config.output_count) {
				channel_count := if config.output_channel_count_matches_input {
					max_int(int(input_slot.actual_channel_count(0)), 1)
				} else {
					int(config.output_channel_capacity[output])
				}
				output_channel_counts << u32(channel_count)
				outputs << [][]f32{len: channel_count, init: []f32{len: config.quantum_size}}
			}
			mut parameters := map[string][]f32{}
			for parameter in 0 .. int(config.param_count) {
				parameters[slot.parameter_names[parameter]] = input_slot.param_block(parameter).clone()
			}
			mut processor := unsafe { &AudioWorkletProcessor(slot.processor) }
			processor_active := processor.process(inputs, mut outputs, parameters) or {
				iteration.failure_message = err.msg()
				return
			}
			if pipe.state() == .shut_down {
				return
			}
			pushed := pipe.try_push_output(fn [outputs, output_channel_counts, processor_active, input_slot] (mut output_slot AudioWorkletOutputSlot) {
				output_slot.set_start_frame(input_slot.start_frame())
				output_slot.set_processor_active(processor_active)
				for output in 0 .. outputs.len {
					output_slot.set_actual_channel_count(output, output_channel_counts[output])
					for channel in 0 .. outputs[output].len {
						output_slot.set_output_channel(output, channel, outputs[output][channel])
					}
				}
			})
			if !pushed {
				iteration.output_full = true
			}
		})
		if message := iteration.failure_message {
			slot.failed = true
			pipe.set_state(.failed)
			mut node := unsafe { &AudioWorkletNode(slot.node) }
			node.processor_errored_ = true
			node.fire_processor_error(message)
			return
		}
		if pipe.state() == .shut_down || iteration.output_full || !iteration.processed {
			break
		}
	}
}
