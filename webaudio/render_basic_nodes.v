// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DestinationRenderNode, GainRenderNode, and
// PassthroughRenderNode from Rendering/RenderNodes.
module webaudio

@[heap]
pub struct DestinationRenderNode {
mut:
	render_node_ &RenderNode
}

pub fn DestinationRenderNode.create(node_id u64, channel_count int,
	quantum_size int) &DestinationRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, channel_count)
	render_node.set_channel_count(channel_count)
	render_node.set_channel_count_mode(.explicit)
	mut destination := &DestinationRenderNode{
		render_node_: render_node
	}
	destination_pointer := destination
	render_node.set_process_callback(fn [destination_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_destination := unsafe { &DestinationRenderNode(destination_pointer) }
		mutable_destination.process(mut graph, context)
	})
	return destination
}

pub fn (destination &DestinationRenderNode) render_node() &RenderNode {
	return destination.render_node_
}

pub fn (mut destination DestinationRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(destination.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(render_node.channel_count())
	output.zero()
	output.sum_from(input, render_node.channel_interpretation())
}

@[heap]
pub struct GainRenderNode {
mut:
	render_node_ &RenderNode
	gain_        &RenderAudioParam
	gain_values_ []f32
}

pub fn GainRenderNode.create(node_id u64, quantum_size int,
	gain &RenderAudioParam) &GainRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 1)
	render_node.add_param(gain)
	mut gain_node := &GainRenderNode{
		render_node_: render_node
		gain_: gain
		gain_values_: []f32{len: quantum_size}
	}
	gain_node_pointer := gain_node
	render_node.set_process_callback(fn [gain_node_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_gain_node := unsafe { &GainRenderNode(gain_node_pointer) }
		mutable_gain_node.process(mut graph, context)
	})
	return gain_node
}

pub fn (gain_node &GainRenderNode) render_node() &RenderNode {
	return gain_node.render_node_
}

pub fn (mut gain_node GainRenderNode) for_each_param(callback RenderAudioParamCallback) {
	mut gain := unsafe { &RenderAudioParam(gain_node.gain_) }
	callback(mut gain)
}

pub fn (mut gain_node GainRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(gain_node.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(input.channel_count())
	// Automation still advances while the audio input is silent, including
	// the intrinsic value exposed to the control side and retained on cancellation.
	mut gain := unsafe { &RenderAudioParam(gain_node.gain_) }
	gain.compute(mut graph, context, mut gain_node.gain_values_)
	if input.is_silent() {
		output.zero()
		return
	}
	for channel in 0 .. input.channel_count() {
		input_samples := input.channel(channel)
		mut output_samples := []f32{len: context.quantum_size}
		for frame in 0 .. context.quantum_size {
			output_samples[frame] = input_samples[frame] * gain_node.gain_values_[frame]
		}
		output.set_channel(channel, output_samples)
	}
}

@[heap]
pub struct PassthroughRenderNode {
mut:
	render_node_ &RenderNode
}

pub fn PassthroughRenderNode.create(node_id u64, quantum_size int) &PassthroughRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 1)
	mut passthrough := &PassthroughRenderNode{
		render_node_: render_node
	}
	passthrough_pointer := passthrough
	render_node.set_process_callback(fn [passthrough_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_passthrough := unsafe { &PassthroughRenderNode(passthrough_pointer) }
		mutable_passthrough.process(mut graph, context)
	})
	return passthrough
}

pub fn (passthrough &PassthroughRenderNode) render_node() &RenderNode {
	return passthrough.render_node_
}

pub fn (mut passthrough PassthroughRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(passthrough.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.copy_from(input)
}
