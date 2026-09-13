// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ChannelMergerRenderNode.
module webaudio

@[heap]
pub struct ChannelMergerRenderNode {
mut:
	render_node_ &RenderNode
}

pub fn ChannelMergerRenderNode.create(node_id u64, quantum_size int,
	number_of_inputs int) &ChannelMergerRenderNode {
	mut render_node := RenderNode.create(node_id, number_of_inputs, 1, quantum_size, number_of_inputs)
	render_node.set_channel_count(1)
	render_node.set_channel_count_mode(.explicit)
	mut merger := &ChannelMergerRenderNode{
		render_node_: render_node
	}
	merger_pointer := merger
	render_node.set_process_callback(fn [merger_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_merger := unsafe { &ChannelMergerRenderNode(merger_pointer) }
		mutable_merger.process(mut graph, context)
	})
	return merger
}

pub fn (merger &ChannelMergerRenderNode) render_node() &RenderNode {
	return merger.render_node_
}

pub fn (mut merger ChannelMergerRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(merger.render_node_) }
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(render_node.input_count())
	for input_index in 0 .. render_node.input_count() {
		input := render_node.pull_input(mut graph, context, input_index)
		output.set_channel(input_index, input.channel(0))
	}
}
