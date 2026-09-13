// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ScheduledSourceRenderNode and ConstantSourceRenderNode.
module webaudio

import math

pub type ScheduledSourceProcessCallback = fn (mut RenderGraph, RenderContext)

@[heap]
pub struct ScheduledSourceRenderNode {
mut:
	render_node_               &RenderNode
	process_source_callback_   ?ScheduledSourceProcessCallback
	start_time_                ?f64
	stop_time_                 f64 = math.inf(1)
	start_time_needs_clamping_ bool
	content_ended_             bool
	ended_                     bool
	ended_pending_             bool
}

pub fn ScheduledSourceRenderNode.create(node_id u64, output_count int,
	quantum_size int) &ScheduledSourceRenderNode {
	mut render_node := RenderNode.create(node_id, 0, output_count, quantum_size, 1)
	mut scheduled := &ScheduledSourceRenderNode{
		render_node_: render_node
	}
	scheduled_pointer := scheduled
	render_node.set_process_callback(fn [scheduled_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_scheduled := unsafe { &ScheduledSourceRenderNode(scheduled_pointer) }
		mutable_scheduled.process(mut graph, context)
	})
	render_node.set_message_callback(fn [scheduled_pointer] (_ mut RenderNode, message NodeMessage) {
		mut mutable_scheduled := unsafe { &ScheduledSourceRenderNode(scheduled_pointer) }
		mutable_scheduled.handle_message(message)
	})
	return scheduled
}

pub fn (scheduled &ScheduledSourceRenderNode) render_node() &RenderNode {
	return scheduled.render_node_
}

pub fn (mut scheduled ScheduledSourceRenderNode) set_process_source_callback(
	callback ScheduledSourceProcessCallback) {
	scheduled.process_source_callback_ = callback
}

pub fn (mut scheduled ScheduledSourceRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	if scheduled.start_time_needs_clamping_ {
		start_time := scheduled.start_time_ or { context.quantum_start_time() }
		scheduled.start_time_ = if start_time > context.quantum_start_time() {
			start_time
		} else {
			context.quantum_start_time()
		}
		scheduled.start_time_needs_clamping_ = false
	}
	if callback := scheduled.process_source_callback_ {
		callback(mut graph, context)
	}
}

pub fn (mut scheduled ScheduledSourceRenderNode) handle_message(message NodeMessage) {
	match message.kind {
		.start_source {
			scheduled.start_time_ = message.when
			scheduled.start_time_needs_clamping_ = true
		}
		.stop_source {
			scheduled.stop_time_ = message.when
		}
		else {}
	}
}

pub fn (mut scheduled ScheduledSourceRenderNode) take_ended_notification() bool {
	if !scheduled.ended_pending_ {
		return false
	}
	scheduled.ended_pending_ = false
	return true
}

pub fn (scheduled &ScheduledSourceRenderNode) has_started() bool {
	return scheduled.start_time_ != none
}

pub fn (scheduled &ScheduledSourceRenderNode) start_time() f64 {
	return scheduled.start_time_ or { 0 }
}

pub fn (scheduled &ScheduledSourceRenderNode) stop_time() f64 {
	return scheduled.stop_time_
}

pub fn (scheduled &ScheduledSourceRenderNode) is_active_at(time f64) bool {
	start_time := scheduled.start_time_ or { return false }
	return time >= start_time && time < scheduled.stop_time_ && !scheduled.content_ended_
}

pub fn (mut scheduled ScheduledSourceRenderNode) set_content_ended() {
	scheduled.content_ended_ = true
}

pub fn (scheduled &ScheduledSourceRenderNode) content_ended() bool {
	return scheduled.content_ended_
}

pub fn (mut scheduled ScheduledSourceRenderNode) update_ended_state(context RenderContext) {
	if !scheduled.has_started() || scheduled.ended_ {
		return
	}
	quantum_end_time := context.frame_time(context.quantum_size)
	if quantum_end_time >= scheduled.stop_time_ || scheduled.content_ended_ {
		scheduled.ended_ = true
		scheduled.ended_pending_ = true
		mut render_node := unsafe { &RenderNode(scheduled.render_node_) }
		render_node.mark_ended()
	}
}

@[heap]
pub struct ConstantSourceRenderNode {
mut:
	scheduled_     &ScheduledSourceRenderNode
	offset_        &RenderAudioParam
	offset_values_ []f32
}

pub fn ConstantSourceRenderNode.create(node_id u64, quantum_size int,
	offset &RenderAudioParam) &ConstantSourceRenderNode {
	mut scheduled := ScheduledSourceRenderNode.create(node_id, 1, quantum_size)
	mut render_node := unsafe { &RenderNode(scheduled.render_node()) }
	render_node.add_param(offset)
	mut constant := &ConstantSourceRenderNode{
		scheduled_: scheduled
		offset_: offset
		offset_values_: []f32{len: quantum_size}
	}
	constant_pointer := constant
	scheduled.set_process_source_callback(fn [constant_pointer] (mut graph RenderGraph, context RenderContext) {
		mut mutable_constant := unsafe { &ConstantSourceRenderNode(constant_pointer) }
		mutable_constant.process_source(mut graph, context)
	})
	return constant
}

pub fn (constant &ConstantSourceRenderNode) render_node() &RenderNode {
	return constant.scheduled_.render_node()
}

pub fn (constant &ConstantSourceRenderNode) scheduled_source() &ScheduledSourceRenderNode {
	return constant.scheduled_
}

pub fn (mut constant ConstantSourceRenderNode) for_each_param(
	callback RenderAudioParamCallback) {
	mut offset := unsafe { &RenderAudioParam(constant.offset_) }
	callback(mut offset)
}

pub fn (mut constant ConstantSourceRenderNode) process_source(mut graph RenderGraph,
	context RenderContext) {
	mut offset := unsafe { &RenderAudioParam(constant.offset_) }
	offset.compute(mut graph, context, mut constant.offset_values_)
	mut output := unsafe { &AudioBus(constant.render_node().output(0)) }
	mut samples := []f32{len: context.quantum_size}
	for frame in 0 .. context.quantum_size {
		if constant.scheduled_.is_active_at(context.frame_time(frame)) {
			samples[frame] = constant.offset_values_[frame]
		}
	}
	output.set_channel(0, samples)
	constant.scheduled_.update_ended_state(context)
}
