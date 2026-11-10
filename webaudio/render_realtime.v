// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/RealtimeAudioRenderer.
module webaudio

@[heap]
pub struct RealtimeAudioRenderer {
mut:
	control_message_queue_ &ControlMessageQueue
	destination_node_id_   u64
	sample_rate_           f32
	quantum_size_          int
	graph_                 &RenderGraph
	device_bus_            ?&AudioBus
	device_channel_count_  int
	device_sample_rate_    f32
	playhead_step_         f64 = 1
	playhead_              f64
	pending_samples_       []f32
	frames_rendered_       u64
	device_frames_played_  u64
	on_sources_ended_      ?AudioSourcesEndedCallback
	started_               bool
	suspended_             bool
	shutting_down_         bool
}

pub fn RealtimeAudioRenderer.create(control_message_queue &ControlMessageQueue,
	destination_node_id u64, sample_rate f32, quantum_size int) &RealtimeAudioRenderer {
	return &RealtimeAudioRenderer{
		control_message_queue_: control_message_queue
		destination_node_id_: destination_node_id
		sample_rate_: sample_rate
		quantum_size_: quantum_size
		graph_: RenderGraph.create()
	}
}

pub fn (mut renderer RealtimeAudioRenderer) set_on_sources_ended(callback AudioSourcesEndedCallback) {
	renderer.on_sources_ended_ = callback
}

pub fn (mut renderer RealtimeAudioRenderer) clear_callbacks() {
	renderer.on_sources_ended_ = none
}

pub fn (mut renderer RealtimeAudioRenderer) start_rendering() {
	renderer.prepare_to_start_rendering()
	renderer.set_playback_stream(2, renderer.sample_rate_)
}

pub fn (mut renderer RealtimeAudioRenderer) start_rendering_with_null_output() {
	renderer.prepare_to_start_rendering()
	renderer.set_playback_stream(2, renderer.sample_rate_)
}

fn (mut renderer RealtimeAudioRenderer) prepare_to_start_rendering() {
	assert !renderer.started_
	renderer.started_ = true
	renderer.graph_.set_destination(renderer.destination_node_id_)
}

// V exposes the device specification directly at the host boundary. Upstream
// obtains these two values from Audio::PlaybackStream before it starts pulling.
pub fn (mut renderer RealtimeAudioRenderer) set_playback_stream(channel_count int,
	sample_rate f32) {
	assert channel_count > 0
	assert sample_rate > 0
	if renderer.shutting_down_ {
		return
	}
	if renderer.device_channel_count_ != channel_count {
		renderer.pending_samples_.clear()
		renderer.playhead_ = 0
	}
	renderer.device_channel_count_ = channel_count
	renderer.device_sample_rate_ = sample_rate
	renderer.device_bus_ = AudioBus.create(channel_count, renderer.quantum_size_)
	renderer.playhead_step_ = f64(renderer.sample_rate_) / f64(sample_rate)
}

pub fn (mut renderer RealtimeAudioRenderer) resume() {
	renderer.suspended_ = false
}

pub fn (mut renderer RealtimeAudioRenderer) suspend() {
	renderer.suspended_ = true
}

pub fn (mut renderer RealtimeAudioRenderer) stop() {
	renderer.shutting_down_ = true
	renderer.suspended_ = true
	renderer.device_bus_ = none
	renderer.device_channel_count_ = 0
}

pub fn (renderer &RealtimeAudioRenderer) frames_rendered() u64 {
	return renderer.frames_rendered_
}

pub fn (renderer &RealtimeAudioRenderer) output_time_played() f64 {
	if renderer.device_sample_rate_ == 0 {
		return 0
	}
	return f64(renderer.device_frames_played_) / f64(renderer.device_sample_rate_)
}

pub fn (renderer &RealtimeAudioRenderer) is_suspended() bool {
	return renderer.suspended_
}

pub fn (renderer &RealtimeAudioRenderer) is_shutting_down() bool {
	return renderer.shutting_down_
}

// Fill an interleaved host-device buffer, linearly resampling when its sample
// rate differs from the AudioContext's rate.
pub fn (mut renderer RealtimeAudioRenderer) fill_output_buffer(mut buffer []f32) []f32 {
	if renderer.shutting_down_ || renderer.device_channel_count_ == 0 {
		return []f32{}
	}
	channel_count := renderer.device_channel_count_
	frames_requested := buffer.len / channel_count
	for frame in 0 .. frames_requested {
		first_frame := int(renderer.playhead_)
		fraction := f32(renderer.playhead_ - f64(first_frame))
		for renderer.pending_samples_.len / channel_count < first_frame + 2 {
			renderer.render_quantum_into_pending_samples()
		}
		for channel in 0 .. channel_count {
			mut sample := renderer.pending_samples_[first_frame * channel_count + channel]
			if fraction != 0 {
				next_sample := renderer.pending_samples_[(first_frame + 1) * channel_count + channel]
				sample += fraction * (next_sample - sample)
			}
			buffer[frame * channel_count + channel] = sample
		}
		renderer.playhead_ += renderer.playhead_step_
	}

	rendered_frames := renderer.pending_samples_.len / channel_count
	consumed_frames := if int(renderer.playhead_) < rendered_frames {
		int(renderer.playhead_)
	} else {
		rendered_frames
	}
	if consumed_frames > 0 {
		renderer.pending_samples_.delete_many(0, consumed_frames * channel_count)
		renderer.playhead_ -= f64(consumed_frames)
	}
	renderer.device_frames_played_ += u64(frames_requested)
	return buffer
}

fn (mut renderer RealtimeAudioRenderer) render_quantum_into_pending_samples() {
	renderer.graph_.apply_control_messages(renderer.control_message_queue_.drain())
	renderer.graph_.render_quantum(RenderContext{
		sample_rate: renderer.sample_rate_
		quantum_size: renderer.quantum_size_
		quantum_start_frame: renderer.frames_rendered_
	})

	if mut device_bus := renderer.device_bus_ {
		device_bus.zero()
		if destination := renderer.graph_.destination() {
			device_bus.sum_from(destination.output(0), .speakers)
		}
		for frame in 0 .. renderer.quantum_size_ {
			for channel in 0 .. renderer.device_channel_count_ {
				renderer.pending_samples_ << device_bus.channel(channel)[frame]
			}
		}
	}

	renderer.frames_rendered_ += u64(renderer.quantum_size_)
	ended_nodes := renderer.graph_.take_ended_nodes()
	if ended_nodes.len > 0 {
		if callback := renderer.on_sources_ended_ {
			callback(ended_nodes)
		}
	}
}
