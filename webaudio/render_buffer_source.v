// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioBufferSourceRenderNode.
module webaudio

import math

@[heap]
pub struct AudioBufferSourceRenderNode {
mut:
	scheduled_            &ScheduledSourceRenderNode
	playback_rate_        &RenderAudioParam
	detune_               &RenderAudioParam
	playback_rate_values_ []f32
	detune_values_        []f32
	buffer_               ?&AudioBufferContents
	loop_                 bool
	loop_start_           f64
	loop_end_             f64
	offset_               f64
	duration_             ?f64
	playhead_             f64
	playhead_valid_       bool
	played_time_          f64
}

pub fn AudioBufferSourceRenderNode.create(node_id u64, quantum_size int,
	playback_rate &RenderAudioParam, detune &RenderAudioParam) &AudioBufferSourceRenderNode {
	mut scheduled := ScheduledSourceRenderNode.create(node_id, 1, quantum_size)
	mut render_node := unsafe { &RenderNode(scheduled.render_node()) }
	render_node.add_param(playback_rate)
	render_node.add_param(detune)
	mut source := &AudioBufferSourceRenderNode{
		scheduled_: scheduled
		playback_rate_: playback_rate
		detune_: detune
		playback_rate_values_: []f32{len: quantum_size}
		detune_values_: []f32{len: quantum_size}
	}
	source_pointer := source
	scheduled.set_process_source_callback(fn [source_pointer] (mut graph RenderGraph, context RenderContext) {
		mut mutable_source := unsafe { &AudioBufferSourceRenderNode(source_pointer) }
		mutable_source.process_source(mut graph, context)
	})
	render_node.set_message_callback(fn [source_pointer] (_ mut RenderNode, message NodeMessage) {
		mut mutable_source := unsafe { &AudioBufferSourceRenderNode(source_pointer) }
		mutable_source.handle_message(message)
	})
	return source
}

pub fn (source &AudioBufferSourceRenderNode) render_node() &RenderNode {
	return source.scheduled_.render_node()
}

pub fn (source &AudioBufferSourceRenderNode) scheduled_source() &ScheduledSourceRenderNode {
	return source.scheduled_
}

pub fn (mut source AudioBufferSourceRenderNode) for_each_param(
	callback RenderAudioParamCallback) {
	mut playback_rate := unsafe { &RenderAudioParam(source.playback_rate_) }
	callback(mut playback_rate)
	mut detune := unsafe { &RenderAudioParam(source.detune_) }
	callback(mut detune)
}

pub fn (mut source AudioBufferSourceRenderNode) handle_message(message NodeMessage) {
	match message.kind {
		.start_buffer_source {
			source.scheduled_.handle_message(NodeMessage{
				node_id: message.node_id
				kind: .start_source
				when: message.when
			})
			source.offset_ = message.offset
			source.duration_ = message.duration
			if buffer := message.buffer {
				source.buffer_ = buffer
			}
		}
		.set_buffer_source_parameters {
			source.loop_ = message.loop_
			source.loop_start_ = message.loop_start
			source.loop_end_ = message.loop_end
			if message.update_buffer {
				source.buffer_ = message.buffer
			}
		}
		else {
			source.scheduled_.handle_message(message)
		}
	}
}

pub fn (source &AudioBufferSourceRenderNode) sample_buffer(channel int, playhead_frames f64,
	loop_start_frame f64, loop_end_frame f64) f32 {
	buffer := source.buffer_ or { return 0 }
	samples := buffer.channels[channel]
	index := i64(math.floor(playhead_frames))
	fraction := f32(playhead_frames - f64(index))
	first := source.sample_at(samples, index, loop_start_frame, loop_end_frame)
	if fraction == 0 {
		return first
	}
	second := source.sample_at(samples, index + 1, loop_start_frame, loop_end_frame)
	return first + fraction * (second - first)
}

fn (source &AudioBufferSourceRenderNode) sample_at(samples []f32, input_index i64,
	loop_start_frame f64, loop_end_frame f64) f32 {
	mut sample_index := input_index
	if source.loop_ && f64(sample_index) >= loop_end_frame
		&& loop_end_frame > loop_start_frame {
		sample_index -= i64(loop_end_frame - loop_start_frame)
	}
	if sample_index < 0 || sample_index >= i64(samples.len) {
		return 0
	}
	return samples[sample_index]
}

// https://webaudio.github.io/web-audio-api/#playback-AudioBufferSourceNode
pub fn (mut source AudioBufferSourceRenderNode) process_source(mut graph RenderGraph,
	context RenderContext) {
	mut playback_rate := unsafe { &RenderAudioParam(source.playback_rate_) }
	playback_rate.compute(mut graph, context, mut source.playback_rate_values_)
	mut detune := unsafe { &RenderAudioParam(source.detune_) }
	detune.compute(mut graph, context, mut source.detune_values_)
	mut output := unsafe { &AudioBus(source.render_node().output(0)) }
	buffer := source.buffer_ or {
		output.set_channel_count(1)
		output.zero()
		source.scheduled_.update_ended_state(context)
		return
	}
	output.set_channel_count(buffer.channels.len)
	output.zero()
	if !source.scheduled_.has_started() {
		source.scheduled_.update_ended_state(context)
		return
	}

	computed_playback_rate := f64(source.playback_rate_values_[0]) * math.exp2(f64(source.detune_values_[0]) / 1200.0)
	buffer_sample_rate := f64(buffer.sample_rate)
	playhead_increment := computed_playback_rate * buffer_sample_rate / context.sample_rate
	buffer_length := f64(buffer.length())
	mut actual_loop_start := f64(0)
	mut actual_loop_end := buffer_length
	if source.loop_ && source.loop_start_ >= 0 && source.loop_end_ > 0
		&& source.loop_start_ < source.loop_end_ {
		actual_loop_start = math.min(source.loop_start_ * buffer_sample_rate, buffer_length)
		actual_loop_end = math.min(source.loop_end_ * buffer_sample_rate, buffer_length)
	}
	mut channels := [][]f32{len: buffer.channels.len, init: []f32{len: context.quantum_size}}
	for frame in 0 .. context.quantum_size {
		frame_time := context.frame_time(frame)
		if !source.scheduled_.is_active_at(frame_time) {
			continue
		}
		if !source.playhead_valid_ {
			source.playhead_ = source.offset_ * buffer_sample_rate
			if source.loop_ {
				source.playhead_ = math.min(source.playhead_, actual_loop_end)
			} else {
				source.playhead_ = math.min(source.playhead_, buffer_length)
			}
			source.playhead_ += (frame_time - source.scheduled_.start_time()) * computed_playback_rate * buffer_sample_rate
			source.playhead_valid_ = true
		}
		frame_consumption := math.abs(computed_playback_rate) / context.sample_rate
		if duration := source.duration_ {
			if source.played_time_ + frame_consumption / 2.0 >= duration {
				source.scheduled_.set_content_ended()
				continue
			}
		}
		if source.loop_ {
			loop_duration := actual_loop_end - actual_loop_start
			if loop_duration > 0 {
				for source.playhead_ >= actual_loop_end {
					source.playhead_ -= loop_duration
				}
				for source.playhead_ < actual_loop_start && playhead_increment < 0 {
					source.playhead_ += loop_duration
				}
			}
		} else if source.playhead_ >= buffer_length
			|| (playhead_increment < 0 && source.playhead_ < 0) {
			source.scheduled_.set_content_ended()
			continue
		}
		for channel in 0 .. buffer.channels.len {
			channels[channel][frame] = source.sample_buffer(channel, source.playhead_, actual_loop_start, actual_loop_end)
		}
		source.playhead_ += playhead_increment
		source.played_time_ += math.abs(computed_playback_rate) / context.sample_rate
	}
	for channel in 0 .. channels.len {
		output.set_channel(channel, channels[channel])
	}
	source.scheduled_.update_ended_state(context)
}
