// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DelayRenderNode.
module webaudio

import math

@[heap]
pub struct DelayRenderNode {
mut:
	render_node_    &RenderNode
	delay_time_     &RenderAudioParam
	delay_values_   []f32
	max_delay_time_ f64
	history_        [][]f32
	write_index_    int
}

pub fn DelayRenderNode.create(node_id u64, quantum_size int, delay_time &RenderAudioParam,
	max_delay_time f64) &DelayRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 1)
	render_node.add_param(delay_time)
	mut delay := &DelayRenderNode{
		render_node_: render_node
		delay_time_: delay_time
		delay_values_: []f32{len: quantum_size}
		max_delay_time_: max_delay_time
	}
	delay_pointer := delay
	render_node.set_process_callback(fn [delay_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_delay := unsafe { &DelayRenderNode(delay_pointer) }
		mutable_delay.process(mut graph, context)
	})
	return delay
}

pub fn (delay &DelayRenderNode) render_node() &RenderNode {
	return delay.render_node_
}

pub fn (mut delay DelayRenderNode) for_each_param(callback RenderAudioParamCallback) {
	mut delay_time := unsafe { &RenderAudioParam(delay.delay_time_) }
	callback(mut delay_time)
}

pub fn (mut delay DelayRenderNode) process(mut graph RenderGraph, context RenderContext) {
	mut render_node := unsafe { &RenderNode(delay.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut delay_time := unsafe { &RenderAudioParam(delay.delay_time_) }
	delay_time.compute(mut graph, context, mut delay.delay_values_)
	history_length := int(math.ceil(delay.max_delay_time_ * context.sample_rate)) + 2
	if delay.history_.len != input.channel_count()
		|| (delay.history_.len > 0 && delay.history_[0].len != history_length) {
		delay.history_ = [][]f32{len: input.channel_count(), init: []f32{len: history_length}}
		delay.write_index_ = 0
	}
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(input.channel_count())
	mut channels := [][]f32{len: input.channel_count(), init: []f32{len: context.quantum_size}}
	for frame in 0 .. context.quantum_size {
		mut delay_seconds := f64(delay.delay_values_[frame])
		if delay_seconds < 0 {
			delay_seconds = 0
		}
		if delay_seconds > delay.max_delay_time_ {
			delay_seconds = delay.max_delay_time_
		}
		delay_frames := delay_seconds * context.sample_rate
		for channel in 0 .. input.channel_count() {
			delay.history_[channel][delay.write_index_] = input.channel(channel)[frame]
			mut read_position := f64(delay.write_index_) - delay_frames
			for read_position < 0 {
				read_position += f64(history_length)
			}
			read_index := int(read_position)
			fraction := f32(read_position - f64(read_index))
			sample_a := delay.history_[channel][read_index % history_length]
			sample_b := delay.history_[channel][(read_index + 1) % history_length]
			channels[channel][frame] = sample_a + fraction * (sample_b - sample_a)
		}
		delay.write_index_ = (delay.write_index_ + 1) % history_length
	}
	for channel in 0 .. channels.len {
		output.set_channel(channel, channels[channel])
	}
}
