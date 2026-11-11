// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioWorklet, AudioWorkletGlobalScope, and
// AudioWorkletProcessor control-side behavior.
module webaudio

import fetch
import html
import math

pub struct AudioParamDescriptor {
pub:
	name            string @[required]
	default_value   f32
	min_value       f32 = -3.402823e38
	max_value       f32 = 3.402823e38
	automation_rate AutomationRate = .a_rate
}

pub struct AudioWorkletProcessorOptions {
pub:
	number_of_inputs     u32 = 1
	number_of_outputs    u32 = 1
	output_channel_count []u32
	parameter_data       map[string]f64
	processor_options    map[string]string
}

pub type AudioWorkletParameters = map[string][]f32

pub type AudioWorkletProcessCallback = fn (inputs [][][]f32, mut outputs [][][]f32, parameters AudioWorkletParameters) !bool

pub type AudioWorkletProcessorFactory = fn (AudioWorkletProcessorOptions, &AudioWorkletGlobalScope) !&AudioWorkletProcessor

pub struct AudioWorkletSyncedDefinition {
pub:
	name                  string
	parameter_descriptors []AudioParamDescriptor
}

pub struct AudioWorkletProcessorDefinition {
pub:
	factory               AudioWorkletProcessorFactory @[required]
	parameter_descriptors []AudioParamDescriptor
}

pub struct PendingProcessorConstructionData {
pub:
	port &html.MessagePort
}

@[heap]
pub struct AudioWorklet {
pub:
	context_id  u64
	sample_rate f32
mut:
	port_               &html.MessagePort
	global_scope_       ?&AudioWorkletGlobalScope
	synced_definitions_ []AudioWorkletSyncedDefinition
}

pub fn AudioWorklet.create(mut context BaseAudioContext) &AudioWorklet {
	mut outer_port := html.MessagePort.create()
	mut worklet := &AudioWorklet{
		context_id: context.id
		sample_rate: context.sample_rate
		port_: outer_port
	}
	worklet.create_global_scope()
	return worklet
}

pub fn (mut worklet AudioWorklet) create_global_scope() &AudioWorkletGlobalScope {
	mut scope := AudioWorkletGlobalScope.create(&worklet, worklet.sample_rate)
	mut scope_port := html.MessagePort.create()
	worklet.port_.entangle_with(scope_port)
	worklet.port_.enable()
	scope.set_port(scope_port)
	worklet.global_scope_ = scope
	return scope
}

pub fn (worklet &AudioWorklet) audio_worklet_global_scope() ?&AudioWorkletGlobalScope {
	return worklet.global_scope_
}

pub fn (worklet &AudioWorklet) port() &html.MessagePort {
	return worklet.port_
}

pub fn (_ AudioWorklet) worklet_destination() fetch.Destination {
	return .audio_worklet
}

pub fn (worklet &AudioWorklet) find_definition(name string) ?AudioWorkletSyncedDefinition {
	for definition in worklet.synced_definitions_ {
		if definition.name == name {
			return definition
		}
	}
	return none
}

pub fn (mut worklet AudioWorklet) add_synced_definition(
	definition AudioWorkletSyncedDefinition) {
	worklet.synced_definitions_ << definition
}

@[heap]
pub struct AudioWorkletGlobalScope {
pub:
	sample_rate_ f32
mut:
	worklet_                             &AudioWorklet
	port_                                ?&html.MessagePort
	processor_definition_names_          []string
	processor_definitions_               map[string]AudioWorkletProcessorDefinition
	pending_processor_construction_data_ ?PendingProcessorConstructionData
	processor_slots_                     map[u64]&AudioWorkletProcessorSlot
	current_frame_                       u64
	current_time_                        f64
	shut_down_                           bool
}

pub fn AudioWorkletGlobalScope.create(worklet &AudioWorklet,
	sample_rate f32) &AudioWorkletGlobalScope {
	return &AudioWorkletGlobalScope{
		worklet_: worklet
		sample_rate_: sample_rate
	}
}

fn convert_parameter_descriptor(descriptor AudioParamDescriptor) !AudioParamDescriptor {
	for value in [descriptor.default_value, descriptor.min_value, descriptor.max_value] {
		if math.is_nan(value) || math.is_inf(value, 0) {
			return error('TypeError: AudioParamDescriptor values must be finite')
		}
	}
	return descriptor
}

pub fn (mut scope AudioWorkletGlobalScope) register_processor(name string,
	factory AudioWorkletProcessorFactory, descriptors []AudioParamDescriptor) ! {
	if name.len == 0 {
		return error('NotSupportedError: registerProcessor name must not be empty')
	}
	if name in scope.processor_definitions_ {
		return error("NotSupportedError: A processor named '${name}' is already registered")
	}
	mut parameter_names := map[string]bool{}
	mut converted_descriptors := []AudioParamDescriptor{cap: descriptors.len}
	for descriptor in descriptors {
		converted_descriptor := convert_parameter_descriptor(descriptor)!
		if converted_descriptor.name in parameter_names {
			return error("NotSupportedError: Duplicate parameter descriptor name '${converted_descriptor.name}'")
		}
		parameter_names[converted_descriptor.name] = true
		if converted_descriptor.default_value < converted_descriptor.min_value
			|| converted_descriptor.default_value > converted_descriptor.max_value {
			return error("InvalidStateError: Parameter '${converted_descriptor.name}' defaultValue is outside [minValue, maxValue]")
		}
		converted_descriptors << converted_descriptor
	}
	definition := AudioWorkletProcessorDefinition{
		factory: factory
		parameter_descriptors: converted_descriptors.clone()
	}
	scope.processor_definition_names_ << name
	scope.processor_definitions_[name] = definition
	mut worklet := unsafe { &AudioWorklet(scope.worklet_) }
	worklet.add_synced_definition(AudioWorkletSyncedDefinition{
		name: name
		parameter_descriptors: converted_descriptors
	})
}

pub fn (scope &AudioWorkletGlobalScope) find_definition(
	name string) ?AudioWorkletProcessorDefinition {
	return scope.processor_definitions_[name] or { return none }
}

pub fn (mut scope AudioWorkletGlobalScope) take_pending_processor_construction_data() ?PendingProcessorConstructionData {
	data := scope.pending_processor_construction_data_ or { return none }
	scope.pending_processor_construction_data_ = none
	return data
}

pub fn (mut scope AudioWorkletGlobalScope) set_pending_processor_construction_data(
	data PendingProcessorConstructionData) {
	scope.pending_processor_construction_data_ = data
}

pub fn (scope &AudioWorkletGlobalScope) current_frame() u64 {
	return scope.current_frame_
}

pub fn (scope &AudioWorkletGlobalScope) current_time() f64 {
	return scope.current_time_
}

pub fn (scope &AudioWorkletGlobalScope) sample_rate() f32 {
	return scope.sample_rate_
}

pub fn (_ AudioWorkletGlobalScope) render_quantum_size() u32 {
	return render_quantum_size
}

pub fn (scope &AudioWorkletGlobalScope) port() ?&html.MessagePort {
	return scope.port_
}

pub fn (mut scope AudioWorkletGlobalScope) set_port(port &html.MessagePort) {
	scope.port_ = port
}

pub fn (mut scope AudioWorkletGlobalScope) set_current_frame_and_time(current_frame u64,
	current_time f64) {
	scope.current_frame_ = current_frame
	scope.current_time_ = current_time
}

pub fn (mut scope AudioWorkletGlobalScope) shutdown_all_slots() {
	for _, slot in scope.processor_slots_ {
		mut pipe := unsafe { &AudioWorkletPipe(slot.pipe) }
		pipe.clear_pump_callback()
		pipe.request_shutdown()
	}
	scope.processor_slots_.clear()
	scope.pending_processor_construction_data_ = none
	scope.shut_down_ = true
}

@[heap]
pub struct AudioWorkletProcessor {
mut:
	port_             &html.MessagePort
	global_scope_     &AudioWorkletGlobalScope
	process_callback_ ?AudioWorkletProcessCallback
}

pub fn AudioWorkletProcessor.construct_impl(
	global_scope &AudioWorkletGlobalScope) !&AudioWorkletProcessor {
	mut mutable_scope := unsafe { &AudioWorkletGlobalScope(global_scope) }
	construction_data := mutable_scope.take_pending_processor_construction_data() or {
		return error('TypeError: AudioWorkletProcessor constructor called outside AudioWorkletNode construction')
	}
	return &AudioWorkletProcessor{
		port_: construction_data.port
		global_scope_: global_scope
	}
}

pub fn (processor &AudioWorkletProcessor) port() &html.MessagePort {
	return processor.port_
}

pub fn (processor &AudioWorkletProcessor) relevant_global_impl() &AudioWorkletGlobalScope {
	return processor.global_scope_
}

pub fn (mut processor AudioWorkletProcessor) set_process_callback(
	callback AudioWorkletProcessCallback) {
	processor.process_callback_ = callback
}

pub fn (mut processor AudioWorkletProcessor) process(inputs [][][]f32, mut outputs [][][]f32,
	parameters map[string][]f32) !bool {
	callback := processor.process_callback_ or {
		return error('TypeError: AudioWorkletProcessor.process must be a function')
	}
	return callback(inputs, mut outputs, parameters)
}

pub fn (mut context BaseAudioContext) audio_worklet() &AudioWorklet {
	if worklet := context.audio_worklet_ {
		return worklet
	}
	worklet := AudioWorklet.create(mut context)
	context.audio_worklet_ = worklet
	return worklet
}

pub fn (mut context BaseAudioContext) shutdown_audio_worklet() {
	worklet := context.audio_worklet_ or { return }
	mut mutable_worklet := unsafe { &AudioWorklet(worklet) }
	mut scope := mutable_worklet.audio_worklet_global_scope() or { return }
	scope.shutdown_all_slots()
}
