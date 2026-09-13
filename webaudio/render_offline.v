// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/OfflineAudioRenderer.
module webaudio

pub type OfflineRendererCompleteCallback = fn ()

pub type OfflineRendererSuspendedCallback = fn (f64)

pub type AudioSourcesEndedCallback = fn ([]u64)

@[heap]
pub struct OfflineAudioRenderer {
mut:
	control_message_queue_ &ControlMessageQueue
	destination_node_id_   u64
	number_of_channels_    int
	length_                int
	sample_rate_           f32
	quantum_size_          int
	graph_                 &RenderGraph
	rendered_channels_     [][]f32
	frames_rendered_       u64
	on_complete_           ?OfflineRendererCompleteCallback
	on_suspended_          ?OfflineRendererSuspendedCallback
	on_sources_ended_      ?AudioSourcesEndedCallback
	suspend_frames_        map[u64]bool
	next_suspend_frame_    u64
	rendering_started_     bool
	suspended_             bool
	shutting_down_         bool
	completed_             bool
}

pub fn OfflineAudioRenderer.create(control_message_queue &ControlMessageQueue,
	destination_node_id u64, number_of_channels int, length int, sample_rate f32,
	quantum_size int) &OfflineAudioRenderer {
	return &OfflineAudioRenderer{
		control_message_queue_: control_message_queue
		destination_node_id_: destination_node_id
		number_of_channels_: number_of_channels
		length_: length
		sample_rate_: sample_rate
		quantum_size_: quantum_size
		graph_: RenderGraph.create()
		rendered_channels_: [][]f32{len: number_of_channels, init: []f32{len: length}}
	}
}

pub fn (mut renderer OfflineAudioRenderer) set_on_complete(callback OfflineRendererCompleteCallback) {
	renderer.on_complete_ = callback
}

pub fn (mut renderer OfflineAudioRenderer) set_on_suspended(callback OfflineRendererSuspendedCallback) {
	renderer.on_suspended_ = callback
}

pub fn (mut renderer OfflineAudioRenderer) set_on_sources_ended(callback AudioSourcesEndedCallback) {
	renderer.on_sources_ended_ = callback
}

pub fn (mut renderer OfflineAudioRenderer) clear_callbacks() {
	renderer.on_complete_ = none
	renderer.on_suspended_ = none
	renderer.on_sources_ended_ = none
}

pub fn (mut renderer OfflineAudioRenderer) start_rendering() {
	assert !renderer.rendering_started_
	renderer.rendering_started_ = true
	renderer.graph_.set_destination(renderer.destination_node_id_)
	renderer.render_thread_main()
}

pub fn (mut renderer OfflineAudioRenderer) stop() {
	renderer.shutting_down_ = true
	renderer.suspended_ = false
}

pub fn (mut renderer OfflineAudioRenderer) request_suspend(frame u64) bool {
	if frame < renderer.next_suspend_frame_ {
		return false
	}
	renderer.suspend_frames_[frame] = true
	return true
}

pub fn (mut renderer OfflineAudioRenderer) resume() {
	if !renderer.suspended_ || renderer.shutting_down_ || renderer.completed_ {
		return
	}
	renderer.suspended_ = false
	renderer.render_thread_main()
}

pub fn (renderer &OfflineAudioRenderer) is_rendering_started() bool {
	return renderer.rendering_started_
}

pub fn (renderer &OfflineAudioRenderer) frames_rendered() u64 {
	return renderer.frames_rendered_
}

pub fn (renderer &OfflineAudioRenderer) rendered_channels() [][]f32 {
	return renderer.rendered_channels_.clone()
}

pub fn (renderer &OfflineAudioRenderer) is_suspended() bool {
	return renderer.suspended_
}

pub fn (renderer &OfflineAudioRenderer) is_complete() bool {
	return renderer.completed_
}

// The standalone V runtime drives this synchronously. Suspension returns to the
// caller at the same quantum boundary where upstream's dedicated thread waits;
// resume() continues the same render graph from that boundary.
fn (mut renderer OfflineAudioRenderer) render_thread_main() {
	mut current_frame := renderer.frames_rendered_
	for current_frame < u64(renderer.length_) {
		if renderer.shutting_down_ {
			return
		}
		renderer.next_suspend_frame_ = current_frame + u64(renderer.quantum_size_)
		if current_frame in renderer.suspend_frames_ {
			renderer.suspend_frames_.delete(current_frame)
			renderer.suspended_ = true
			if callback := renderer.on_suspended_ {
				callback(f64(current_frame) / f64(renderer.sample_rate_))
			}
			return
		}

		renderer.graph_.apply_control_messages(renderer.control_message_queue_.drain())
		renderer.graph_.render_quantum(RenderContext{
			sample_rate: renderer.sample_rate_
			quantum_size: renderer.quantum_size_
			quantum_start_frame: current_frame
		})

		if destination := renderer.graph_.destination() {
			output := destination.output(0)
			remaining_frames := renderer.length_ - int(current_frame)
			frames_to_copy := if renderer.quantum_size_ < remaining_frames {
				renderer.quantum_size_
			} else {
				remaining_frames
			}
			channels_to_copy := if renderer.number_of_channels_ < output.channel_count() {
				renderer.number_of_channels_
			} else {
				output.channel_count()
			}
			for channel in 0 .. channels_to_copy {
				samples := output.channel(channel)
				for frame in 0 .. frames_to_copy {
					renderer.rendered_channels_[channel][int(current_frame) + frame] = samples[frame]
				}
			}
		}

		current_frame += u64(renderer.quantum_size_)
		renderer.frames_rendered_ = current_frame
		ended_nodes := renderer.graph_.take_ended_nodes()
		if ended_nodes.len > 0 {
			if callback := renderer.on_sources_ended_ {
				callback(ended_nodes)
			}
		}
	}

	renderer.completed_ = true
	if callback := renderer.on_complete_ {
		callback()
	}
}
