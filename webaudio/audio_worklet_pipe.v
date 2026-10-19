// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/AudioWorkletPipe. Native Ladybird uses atomics and
// a preallocated byte arena across two threads. The V renderer is currently
// single-threaded, so it keeps the same fixed slots and ring semantics without
// synchronization primitives.
module webaudio

import html
import math

pub struct AudioWorkletRingSizing {
pub:
	ring_capacity int
	prime_level   int
}

pub struct AudioWorkletPipeConfig {
pub mut:
	quantum_size                       int
	sample_rate                        f32
	input_count                        u32
	output_count                       u32
	input_channel_capacity             []u32
	output_channel_capacity            []u32
	output_channel_count_matches_input bool
	param_count                        u32
	param_is_a_rate                    []bool
	ring_capacity                      int
	prime_level                        int
}

pub fn AudioWorkletPipeConfig.ring_sizing_for_device_latency(device_latency_ms u32,
	sample_rate f32, quantum_size int) AudioWorkletRingSizing {
	assert sample_rate > 0
	assert quantum_size > 0
	burst_quanta := int(math.ceil(f64(device_latency_ms) / 1000.0 * f64(sample_rate) / f64(quantum_size)))
	prime_level := (burst_quanta * 5 + 3) / 4
	mut ring_capacity := 1
	for ring_capacity < prime_level + max_int(burst_quanta / 4, 1) {
		ring_capacity *= 2
	}
	return AudioWorkletRingSizing{
		ring_capacity: ring_capacity
		prime_level: prime_level
	}
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}

pub enum AudioWorkletPipeState {
	running
	failed
	shut_down
}

pub struct AudioWorkletInputSlot {
mut:
	start_frame_           u64
	had_gap_               bool
	actual_channel_counts_ []u32
	input_channels_        [][][]f32
	param_blocks_          [][]f32
}

fn new_audio_worklet_input_slot(config AudioWorkletPipeConfig) AudioWorkletInputSlot {
	mut inputs := [][][]f32{cap: int(config.input_count)}
	for input in 0 .. int(config.input_count) {
		mut channels := [][]f32{cap: int(config.input_channel_capacity[input])}
		for _ in 0 .. int(config.input_channel_capacity[input]) {
			channels << []f32{len: config.quantum_size}
		}
		inputs << channels
	}
	mut params := [][]f32{cap: int(config.param_count)}
	for parameter in 0 .. int(config.param_count) {
		block_length := if config.param_is_a_rate[parameter] { config.quantum_size } else { 1 }
		params << []f32{len: block_length}
	}
	return AudioWorkletInputSlot{
		actual_channel_counts_: []u32{len: int(config.input_count)}
		input_channels_: inputs
		param_blocks_: params
	}
}

pub fn (slot &AudioWorkletInputSlot) start_frame() u64 {
	return slot.start_frame_
}

pub fn (mut slot AudioWorkletInputSlot) set_start_frame(value u64) {
	slot.start_frame_ = value
}

pub fn (slot &AudioWorkletInputSlot) had_gap() bool {
	return slot.had_gap_
}

pub fn (mut slot AudioWorkletInputSlot) set_had_gap(had_gap bool) {
	slot.had_gap_ = had_gap
}

pub fn (slot &AudioWorkletInputSlot) actual_channel_count(input int) u32 {
	return slot.actual_channel_counts_[input]
}

pub fn (mut slot AudioWorkletInputSlot) set_actual_channel_count(input int, count u32) {
	assert input >= 0 && input < slot.actual_channel_counts_.len
	assert int(count) <= slot.input_channels_[input].len
	slot.actual_channel_counts_[input] = count
}

pub fn (slot &AudioWorkletInputSlot) input_channel(input int, channel int) []f32 {
	return slot.input_channels_[input][channel]
}

pub fn (mut slot AudioWorkletInputSlot) set_input_channel(input int, channel int, samples []f32) {
	assert samples.len == slot.input_channels_[input][channel].len
	for index, sample in samples {
		slot.input_channels_[input][channel][index] = sample
	}
}

pub fn (slot &AudioWorkletInputSlot) param_block(parameter int) []f32 {
	return slot.param_blocks_[parameter]
}

pub fn (mut slot AudioWorkletInputSlot) set_param_block(parameter int, samples []f32) {
	assert samples.len == slot.param_blocks_[parameter].len
	for index, sample in samples {
		slot.param_blocks_[parameter][index] = sample
	}
}

pub struct AudioWorkletOutputSlot {
mut:
	start_frame_           u64
	processor_active_      bool
	actual_channel_counts_ []u32
	output_channels_       [][][]f32
}

fn new_audio_worklet_output_slot(config AudioWorkletPipeConfig) AudioWorkletOutputSlot {
	mut outputs := [][][]f32{cap: int(config.output_count)}
	for output in 0 .. int(config.output_count) {
		mut channels := [][]f32{cap: int(config.output_channel_capacity[output])}
		for _ in 0 .. int(config.output_channel_capacity[output]) {
			channels << []f32{len: config.quantum_size}
		}
		outputs << channels
	}
	return AudioWorkletOutputSlot{
		actual_channel_counts_: []u32{len: int(config.output_count)}
		output_channels_: outputs
	}
}

pub fn (slot &AudioWorkletOutputSlot) start_frame() u64 {
	return slot.start_frame_
}

pub fn (mut slot AudioWorkletOutputSlot) set_start_frame(value u64) {
	slot.start_frame_ = value
}

pub fn (slot &AudioWorkletOutputSlot) processor_active() bool {
	return slot.processor_active_
}

pub fn (mut slot AudioWorkletOutputSlot) set_processor_active(processor_active bool) {
	slot.processor_active_ = processor_active
}

pub fn (slot &AudioWorkletOutputSlot) actual_channel_count(output int) u32 {
	return slot.actual_channel_counts_[output]
}

pub fn (mut slot AudioWorkletOutputSlot) set_actual_channel_count(output int, count u32) {
	assert output >= 0 && output < slot.actual_channel_counts_.len
	assert int(count) <= slot.output_channels_[output].len
	slot.actual_channel_counts_[output] = count
}

pub fn (slot &AudioWorkletOutputSlot) output_channel(output int, channel int) []f32 {
	return slot.output_channels_[output][channel]
}

pub fn (mut slot AudioWorkletOutputSlot) set_output_channel(output int, channel int,
	samples []f32) {
	assert samples.len == slot.output_channels_[output][channel].len
	for index, sample in samples {
		slot.output_channels_[output][channel][index] = sample
	}
}

pub type AudioWorkletInputFillCallback = fn (mut AudioWorkletInputSlot)

pub type AudioWorkletInputReadCallback = fn (AudioWorkletInputSlot)

pub type AudioWorkletOutputFillCallback = fn (mut AudioWorkletOutputSlot)

pub type AudioWorkletOutputReadCallback = fn (AudioWorkletOutputSlot)

pub type AudioWorkletPumpCallback = fn ()

@[heap]
pub struct AudioWorkletPipe {
mut:
	config_              AudioWorkletPipeConfig
	ring_index_mask_     u64
	input_slots_         []AudioWorkletInputSlot
	output_slots_        []AudioWorkletOutputSlot
	input_head_          u64
	input_tail_          u64
	output_head_         u64
	output_tail_         u64
	pump_callback_       ?AudioWorkletPumpCallback
	pump_scheduled_      bool
	state_               AudioWorkletPipeState
	underrun_count_      u64
	dropped_input_count_ u64
}

pub fn AudioWorkletPipe.create(config AudioWorkletPipeConfig) !&AudioWorkletPipe {
	if config.quantum_size <= 0 {
		return error('AudioWorkletPipe quantum size must be positive')
	}
	if config.input_channel_capacity.len != int(config.input_count) {
		return error('AudioWorkletPipe input channel capacities must match input count')
	}
	if config.output_channel_capacity.len != int(config.output_count) {
		return error('AudioWorkletPipe output channel capacities must match output count')
	}
	if config.param_is_a_rate.len != int(config.param_count) {
		return error('AudioWorkletPipe parameter rates must match parameter count')
	}
	if config.ring_capacity <= 0
		|| (config.ring_capacity & (config.ring_capacity - 1)) != 0 {
		return error('AudioWorkletPipe ring capacity must be a power of two')
	}
	if config.prime_level < 0 || config.prime_level > config.ring_capacity {
		return error('AudioWorkletPipe prime level exceeds ring capacity')
	}
	mut input_slots := []AudioWorkletInputSlot{cap: config.ring_capacity}
	mut output_slots := []AudioWorkletOutputSlot{cap: config.ring_capacity}
	for _ in 0 .. config.ring_capacity {
		input_slots << new_audio_worklet_input_slot(config)
		output_slots << new_audio_worklet_output_slot(config)
	}
	return &AudioWorkletPipe{
		config_: config
		ring_index_mask_: u64(config.ring_capacity - 1)
		input_slots_: input_slots
		output_slots_: output_slots
	}
}

pub fn (pipe &AudioWorkletPipe) config() AudioWorkletPipeConfig {
	return pipe.config_
}

// The C++ pipe returns an arena address for these counters. V owns typed slot
// arrays instead, so the equivalent helpers return the masked array index.
fn (pipe &AudioWorkletPipe) input_slot(counter u64) int {
	return int(counter & pipe.ring_index_mask_)
}

fn (pipe &AudioWorkletPipe) output_slot(counter u64) int {
	return int(counter & pipe.ring_index_mask_)
}

pub fn (mut pipe AudioWorkletPipe) try_push_input(fill AudioWorkletInputFillCallback) bool {
	if pipe.input_tail_ - pipe.input_head_ == u64(pipe.config_.ring_capacity) {
		pipe.dropped_input_count_++
		return false
	}
	index := pipe.input_slot(pipe.input_tail_)
	pipe.input_slots_[index].had_gap_ = false
	fill(mut pipe.input_slots_[index])
	pipe.input_tail_++
	return true
}

pub fn (mut pipe AudioWorkletPipe) try_pop_input(read AudioWorkletInputReadCallback) bool {
	if pipe.input_head_ == pipe.input_tail_ {
		return false
	}
	slot := pipe.input_slots_[pipe.input_slot(pipe.input_head_)]
	read(slot)
	pipe.input_head_++
	return true
}

pub fn (mut pipe AudioWorkletPipe) try_push_output(fill AudioWorkletOutputFillCallback) bool {
	if pipe.output_tail_ - pipe.output_head_ == u64(pipe.config_.ring_capacity) {
		return false
	}
	index := pipe.output_slot(pipe.output_tail_)
	pipe.output_slots_[index].processor_active_ = false
	fill(mut pipe.output_slots_[index])
	pipe.output_tail_++
	return true
}

pub fn (mut pipe AudioWorkletPipe) try_pop_output(read AudioWorkletOutputReadCallback) bool {
	if pipe.output_head_ == pipe.output_tail_ {
		pipe.underrun_count_++
		return false
	}
	slot := pipe.output_slots_[pipe.output_slot(pipe.output_head_)]
	read(slot)
	pipe.output_head_++
	return true
}

pub fn (pipe &AudioWorkletPipe) output_occupancy() int {
	return int(pipe.output_tail_ - pipe.output_head_)
}

pub fn (mut pipe AudioWorkletPipe) discard_outputs_down_to(target_occupancy int) {
	if pipe.output_occupancy() <= target_occupancy {
		return
	}
	pipe.output_head_ = pipe.output_tail_ - u64(target_occupancy)
}

pub fn (mut pipe AudioWorkletPipe) prime_outputs_with_silence(count int) {
	config := pipe.config_
	for _ in 0 .. count {
		pushed := pipe.try_push_output(fn [config] (mut slot AudioWorkletOutputSlot) {
			slot.set_start_frame(0)
			slot.set_processor_active(true)
			for output in 0 .. int(config.output_count) {
				channel_count := if config.output_channel_count_matches_input {
					u32(1)
				} else {
					config.output_channel_capacity[output]
				}
				slot.set_actual_channel_count(output, channel_count)
				for channel in 0 .. int(channel_count) {
					slot.set_output_channel(output, channel, []f32{len: config.quantum_size})
				}
			}
		})
		assert pushed
	}
}

pub fn (mut pipe AudioWorkletPipe) request_wakeup() {
	if pipe.pump_scheduled_ {
		return
	}
	pipe.pump_scheduled_ = true
	pipe_pointer := unsafe { &pipe }
	html.queue_a_task(.media_element, html.main_thread_event_loop(), none, fn [pipe_pointer] () {
		mut current_pipe := pipe_pointer
		if current_pipe.state() == .shut_down {
			return
		}
		if callback := current_pipe.pump_callback_ {
			callback()
		}
	})
}

pub fn (mut pipe AudioWorkletPipe) clear_wakeup_flag() {
	pipe.pump_scheduled_ = false
}

pub fn (mut pipe AudioWorkletPipe) set_pump_callback(callback AudioWorkletPumpCallback) {
	pipe.pump_callback_ = callback
}

pub fn (mut pipe AudioWorkletPipe) clear_pump_callback() {
	pipe.pump_callback_ = none
}

pub fn (pipe &AudioWorkletPipe) state() AudioWorkletPipeState {
	return pipe.state_
}

pub fn (mut pipe AudioWorkletPipe) set_state(state AudioWorkletPipeState) {
	pipe.state_ = state
}

pub fn (mut pipe AudioWorkletPipe) request_shutdown() {
	pipe.set_state(.shut_down)
}

pub fn (pipe &AudioWorkletPipe) underrun_count() u64 {
	return pipe.underrun_count_
}

pub fn (pipe &AudioWorkletPipe) dropped_input_count() u64 {
	return pipe.dropped_input_count_
}
