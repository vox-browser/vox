// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of StereoPannerRenderNode.
module webaudio

import math

struct PanGains {
	left  f32
	right f32
}

// The equal-power curve maps [0, 1] onto gains whose squared sum is one.
fn equal_power_pan_gains(position f64) PanGains {
	return PanGains{
		left: f32(math.cos(position * math.pi / 2.0))
		right: f32(math.sin(position * math.pi / 2.0))
	}
}

@[heap]
pub struct StereoPannerRenderNode {
mut:
	render_node_ &RenderNode
	pan_         &RenderAudioParam
	pan_values_  []f32
}

pub fn StereoPannerRenderNode.create(node_id u64, quantum_size int,
	pan &RenderAudioParam) &StereoPannerRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 2)
	render_node.set_channel_count_mode(.clamped_max)
	render_node.add_param(pan)
	mut panner := &StereoPannerRenderNode{
		render_node_: render_node
		pan_: pan
		pan_values_: []f32{len: quantum_size}
	}
	panner_pointer := panner
	render_node.set_process_callback(fn [panner_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_panner := unsafe { &StereoPannerRenderNode(panner_pointer) }
		mutable_panner.process(mut graph, context)
	})
	return panner
}

pub fn (panner &StereoPannerRenderNode) render_node() &RenderNode {
	return panner.render_node_
}

pub fn (mut panner StereoPannerRenderNode) for_each_param(callback RenderAudioParamCallback) {
	mut pan := unsafe { &RenderAudioParam(panner.pan_) }
	callback(mut pan)
}

// https://webaudio.github.io/web-audio-api/#stereopanner-algorithm
pub fn (mut panner StereoPannerRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(panner.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut pan_parameter := unsafe { &RenderAudioParam(panner.pan_) }
	pan_parameter.compute(mut graph, context, mut panner.pan_values_)

	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(2)
	mut output_left := []f32{len: context.quantum_size}
	mut output_right := []f32{len: context.quantum_size}
	input_left := input.channel(0)
	input_right := if input.channel_count() > 1 { input.channel(1) } else { input_left }
	for frame in 0 .. context.quantum_size {
		pan := panner.pan_values_[frame]
		clamped_pan := if pan < -1 {
			f32(-1)
		} else if pan > 1 { f32(1) } else { pan }
		x := if input.channel_count() == 1 {
			f64(clamped_pan + 1) / 2.0
		} else if clamped_pan <= 0 {
			f64(clamped_pan + 1)
		} else {
			f64(clamped_pan)
		}
		gains := equal_power_pan_gains(x)
		if input.channel_count() == 1 {
			output_left[frame] = input_left[frame] * gains.left
			output_right[frame] = input_left[frame] * gains.right
		} else if clamped_pan <= 0 {
			output_left[frame] = input_left[frame] + input_right[frame] * gains.left
			output_right[frame] = input_right[frame] * gains.right
		} else {
			output_left[frame] = input_left[frame] * gains.left
			output_right[frame] = input_right[frame] + input_left[frame] * gains.right
		}
	}
	output.set_channel(0, output_left)
	output.set_channel(1, output_right)
}
