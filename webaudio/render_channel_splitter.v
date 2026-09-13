// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ChannelSplitterRenderNode.
module webaudio

@[heap]
pub struct ChannelSplitterRenderNode {
mut:
	render_node_ &RenderNode
}

pub fn ChannelSplitterRenderNode.create(node_id u64, quantum_size int,
	number_of_outputs int) &ChannelSplitterRenderNode {
	mut render_node := RenderNode.create(node_id, 1, number_of_outputs, quantum_size, 1)
	render_node.set_channel_count(number_of_outputs)
	render_node.set_channel_count_mode(.explicit)
	render_node.set_channel_interpretation(.discrete)
	mut splitter := &ChannelSplitterRenderNode{
		render_node_: render_node
	}
	splitter_pointer := splitter
	render_node.set_process_callback(fn [splitter_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_splitter := unsafe { &ChannelSplitterRenderNode(splitter_pointer) }
		mutable_splitter.process(mut graph, context)
	})
	return splitter
}

pub fn (splitter &ChannelSplitterRenderNode) render_node() &RenderNode {
	return splitter.render_node_
}

pub fn (mut splitter ChannelSplitterRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(splitter.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	for output_index in 0 .. render_node.output_count() {
		mut output := unsafe { &AudioBus(render_node.output(output_index)) }
		if output_index < input.channel_count() {
			output.set_channel(0, input.channel(output_index))
		} else {
			output.zero()
		}
	}
}
