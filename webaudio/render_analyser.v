// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/AnalyserRenderNode.
module webaudio

@[heap]
pub struct AnalyserRenderNode {
mut:
	render_node_      &RenderNode
	time_domain_ring_ &MediaStreamAudioRing
	mono_scratch_     &AudioBus
	discard_scratch_  []f32
}

pub fn AnalyserRenderNode.create(node_id u64, quantum_size int,
	time_domain_ring &MediaStreamAudioRing) &AnalyserRenderNode {
	assert time_domain_ring.channel_count == 1
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 1)
	render_node.set_channel_count(2)
	render_node.set_channel_count_mode(.max)
	render_node.set_channel_interpretation(.speakers)
	mut analyser := &AnalyserRenderNode{
		render_node_: render_node
		time_domain_ring_: time_domain_ring
		mono_scratch_: AudioBus.create(1, quantum_size)
		discard_scratch_: []f32{len: quantum_size}
	}
	analyser_pointer := analyser
	render_node.set_process_callback(fn [analyser_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_analyser := unsafe { &AnalyserRenderNode(analyser_pointer) }
		mutable_analyser.process(mut graph, context)
	})
	return analyser
}

pub fn (analyser &AnalyserRenderNode) render_node() &RenderNode {
	return analyser.render_node_
}

pub fn (analyser &AnalyserRenderNode) time_domain_ring() &MediaStreamAudioRing {
	return analyser.time_domain_ring_
}

pub fn (mut analyser AnalyserRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(analyser.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.copy_from(input)
	analyser.mono_scratch_.zero()
	analyser.mono_scratch_.sum_from(input, .speakers)
	mut ring := unsafe { &MediaStreamAudioRing(analyser.time_domain_ring_) }
	if ring.frames_free() < context.quantum_size {
		analyser.discard_scratch_ = ring.pop_frames(context.quantum_size)
	}
	push_frames_if_enough_room(mut ring, analyser.mono_scratch_.channel(0))
}
