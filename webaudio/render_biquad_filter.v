// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BiquadFilterRenderNode.
module webaudio

import math

struct BiquadFilterState {
mut:
	x1 f64
	x2 f64
	y1 f64
	y2 f64
}

@[heap]
pub struct BiquadFilterRenderNode {
mut:
	render_node_      &RenderNode
	frequency_        &RenderAudioParam
	detune_           &RenderAudioParam
	q_                &RenderAudioParam
	gain_             &RenderAudioParam
	frequency_values_ []f32
	detune_values_    []f32
	q_values_         []f32
	gain_values_      []f32
	type_             BiquadFilterType = .lowpass
	filter_states_    []BiquadFilterState
}

pub fn BiquadFilterRenderNode.create(node_id u64, quantum_size int,
	frequency &RenderAudioParam, detune &RenderAudioParam, q &RenderAudioParam,
	gain &RenderAudioParam) &BiquadFilterRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 1)
	for parameter in [frequency, detune, q, gain] {
		render_node.add_param(parameter)
	}
	mut filter := &BiquadFilterRenderNode{
		render_node_: render_node
		frequency_: frequency
		detune_: detune
		q_: q
		gain_: gain
		frequency_values_: []f32{len: quantum_size}
		detune_values_: []f32{len: quantum_size}
		q_values_: []f32{len: quantum_size}
		gain_values_: []f32{len: quantum_size}
	}
	filter_pointer := filter
	render_node.set_process_callback(fn [filter_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_filter := unsafe { &BiquadFilterRenderNode(filter_pointer) }
		mutable_filter.process(mut graph, context)
	})
	render_node.set_message_callback(fn [filter_pointer] (_ mut RenderNode, message NodeMessage) {
		mut mutable_filter := unsafe { &BiquadFilterRenderNode(filter_pointer) }
		mutable_filter.handle_message(message)
	})
	return filter
}

pub fn (filter &BiquadFilterRenderNode) render_node() &RenderNode {
	return filter.render_node_
}

pub fn (filter &BiquadFilterRenderNode) filter_type() BiquadFilterType {
	return filter.type_
}

pub fn (mut filter BiquadFilterRenderNode) handle_message(message NodeMessage) {
	if message.kind == .set_biquad_filter_type {
		filter.type_ = message.biquad_type
	}
}

pub fn (mut filter BiquadFilterRenderNode) for_each_param(callback RenderAudioParamCallback) {
	for parameter in [filter.frequency_, filter.detune_, filter.q_, filter.gain_] {
		mut mutable_parameter := unsafe { &RenderAudioParam(parameter) }
		callback(mut mutable_parameter)
	}
}

fn (mut filter BiquadFilterRenderNode) resize_filter_states(channel_count int) {
	if filter.filter_states_.len < channel_count {
		filter.filter_states_ << []BiquadFilterState{len: channel_count - filter.filter_states_.len}
	} else if filter.filter_states_.len > channel_count {
		filter.filter_states_ = filter.filter_states_[..channel_count].clone()
	}
}

fn (filter &BiquadFilterRenderNode) parameters_changed(frame int) bool {
	return filter.frequency_values_[frame] != filter.frequency_values_[frame - 1]
		|| filter.detune_values_[frame] != filter.detune_values_[frame - 1]
		|| filter.q_values_[frame] != filter.q_values_[frame - 1]
		|| filter.gain_values_[frame] != filter.gain_values_[frame - 1]
}

fn (filter &BiquadFilterRenderNode) coefficients_for_frame(frame int,
	nyquist_frequency f64) BiquadCoefficients {
	computed_frequency := f64(filter.frequency_values_[frame]) * math.exp2(f64(filter.detune_values_[frame]) / 1200.0)
	normalized_frequency := if computed_frequency < 0 {
		0.0
	} else if computed_frequency > nyquist_frequency {
		1.0
	} else {
		computed_frequency / nyquist_frequency
	}
	return compute_biquad_coefficients(filter.type_, normalized_frequency, f64(filter.q_values_[frame]), f64(filter.gain_values_[frame]))
}

pub fn (mut filter BiquadFilterRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(filter.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut frequency := unsafe { &RenderAudioParam(filter.frequency_) }
	mut detune := unsafe { &RenderAudioParam(filter.detune_) }
	mut q := unsafe { &RenderAudioParam(filter.q_) }
	mut gain := unsafe { &RenderAudioParam(filter.gain_) }
	frequency.compute(mut graph, context, mut filter.frequency_values_)
	detune.compute(mut graph, context, mut filter.detune_values_)
	q.compute(mut graph, context, mut filter.q_values_)
	gain.compute(mut graph, context, mut filter.gain_values_)
	filter.resize_filter_states(input.channel_count())

	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(input.channel_count())
	mut output_channels := [][]f32{len: input.channel_count(), init: []f32{len: context.quantum_size}}
	nyquist_frequency := context.sample_rate / 2.0
	mut coefficients := filter.coefficients_for_frame(0, nyquist_frequency)
	for frame in 0 .. context.quantum_size {
		if frame > 0 && filter.parameters_changed(frame) {
			coefficients = filter.coefficients_for_frame(frame, nyquist_frequency)
		}
		for channel in 0 .. input.channel_count() {
			mut state := &filter.filter_states_[channel]
			x := f64(input.channel(channel)[frame])
			y := coefficients.b0 * x + coefficients.b1 * state.x1 + coefficients.b2 * state.x2 - coefficients.a1 * state.y1 - coefficients.a2 * state.y2
			state.x2 = state.x1
			state.x1 = x
			state.y2 = state.y1
			state.y1 = y
			output_channels[channel][frame] = f32(y)
		}
	}
	for channel in 0 .. output_channels.len {
		output.set_channel(channel, output_channels[channel])
	}
}
