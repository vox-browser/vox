// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaStreamAudioDestinationNode and
// Rendering/MediaStreamDestinationRenderNode.
module webaudio

import mediacapture

const media_stream_destination_ring_capacity = 8192

type MediaStreamDrainCallback = fn ()

@[heap]
struct MediaStreamDestinationSharedState {
	ring &MediaStreamAudioRing
mut:
	drain_pending bool
	drain         ?MediaStreamDrainCallback
}

fn new_media_stream_destination_shared_state(ring &MediaStreamAudioRing) &MediaStreamDestinationSharedState {
	return &MediaStreamDestinationSharedState{
		ring: ring
	}
}

@[heap]
pub struct MediaStreamDestinationRenderNode {
pub:
	node_id       u64
	quantum_size  int
	channel_count int
mut:
	shared_state &MediaStreamDestinationSharedState
}

fn new_media_stream_destination_render_node(node_id u64, quantum_size int, channel_count int,
	shared_state &MediaStreamDestinationSharedState) &MediaStreamDestinationRenderNode {
	return &MediaStreamDestinationRenderNode{
		node_id: node_id
		quantum_size: quantum_size
		channel_count: channel_count
		shared_state: shared_state
	}
}

fn mix_media_stream_input(input [][]f32, output_channels int, frame_count int) [][]f32 {
	mut output := [][]f32{len: output_channels, init: []f32{len: frame_count}}
	if input.len == 0 {
		return output
	}
	if output_channels == 1 && input.len > 1 {
		for frame in 0 .. frame_count {
			mut sum := f32(0)
			mut contributors := 0
			for channel in input {
				if frame < channel.len {
					sum += channel[frame]
					contributors++
				}
			}
			if contributors > 0 {
				output[0][frame] = sum / f32(contributors)
			}
		}
		return output
	}
	for output_channel in 0 .. output_channels {
		input_channel := if output_channel < input.len { output_channel } else { 0 }
		for frame in 0 .. frame_count {
			if frame < input[input_channel].len {
				output[output_channel][frame] = input[input_channel][frame]
			}
		}
	}
	return output
}

// Mix, interleave, and enqueue one render quantum. The native event-loop wakeup
// is represented by an immediate coalesced drain because this renderer is
// currently single-threaded.
pub fn (mut render_node MediaStreamDestinationRenderNode) process(input [][]f32) [][]f32 {
	mixed := mix_media_stream_input(input, render_node.channel_count, render_node.quantum_size)
	mut interleaved := []f32{len: render_node.quantum_size * render_node.channel_count}
	for frame in 0 .. render_node.quantum_size {
		for channel in 0 .. render_node.channel_count {
			interleaved[frame * render_node.channel_count + channel] = mixed[channel][frame]
		}
	}
	mut ring := unsafe { &MediaStreamAudioRing(render_node.shared_state.ring) }
	push_frames_if_enough_room(mut ring, interleaved)
	if !render_node.shared_state.drain_pending {
		render_node.shared_state.drain_pending = true
		if drain := render_node.shared_state.drain {
			drain()
		}
		render_node.shared_state.drain_pending = false
	}
	// Upstream exposes this passthrough only inside RenderGraph so a zero-output
	// DOM node continues to be pulled every quantum.
	return input.clone()
}

pub struct MediaStreamAudioDestinationNode {
pub:
	node AudioNode
mut:
	stream_       &mediacapture.MediaStream
	track_        &mediacapture.MediaStreamTrack
	shared_state_ &MediaStreamDestinationSharedState
	render_node_  &MediaStreamDestinationRenderNode
}

pub fn MediaStreamAudioDestinationNode.create(mut context AudioContext,
	options AudioNodeOptions) !MediaStreamAudioDestinationNode {
	mut track := mediacapture.MediaStreamTrack.create(.audio, 'MediaStreamAudioDestinationNode', false)
	stream := mediacapture.MediaStream.create([track])
	node := context.base.allocate_node(.media_stream_destination, 1, 0, options, 2, .explicit, .speakers)!
	track.set_settings(mediacapture.MediaTrackSettings{
		sample_rate: u32(context.base.sample_rate)
		channel_count: node.channel_count
	})
	ring := new_media_stream_audio_ring(media_stream_destination_ring_capacity, int(node.channel_count))
	mut shared_state := new_media_stream_destination_shared_state(ring)
	track_pointer := &mediacapture.MediaStreamTrack(track)
	sample_rate := u32(context.base.sample_rate)
	shared_state.drain = fn [track_pointer, ring, sample_rate] () {
		mut mutable_ring := unsafe { &MediaStreamAudioRing(ring) }
		mut mutable_track := unsafe { &mediacapture.MediaStreamTrack(track_pointer) }
		for mutable_ring.frames_available() > 0 {
			chunk := mutable_ring.pop_frames(int(render_quantum_size))
			frame_count := chunk.len / mutable_ring.channel_count
			mutable_track.deliver_audio_frames(chunk, frame_count, u8(mutable_ring.channel_count), sample_rate)
		}
	}
	render_node := new_media_stream_destination_render_node(node.id, int(render_quantum_size), int(node.channel_count), shared_state)
	return MediaStreamAudioDestinationNode{
		node: node
		stream_: stream
		track_: track
		shared_state_: shared_state
		render_node_: render_node
	}
}

pub fn MediaStreamAudioDestinationNode.create_for_constructor(mut context AudioContext,
	options AudioNodeOptions) !MediaStreamAudioDestinationNode {
	return MediaStreamAudioDestinationNode.create(mut context, options)
}

pub fn (_ MediaStreamAudioDestinationNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ MediaStreamAudioDestinationNode) number_of_outputs() u32 {
	return 0
}

pub fn (destination MediaStreamAudioDestinationNode) stream() &mediacapture.MediaStream {
	return destination.stream_
}

pub fn (mut destination MediaStreamAudioDestinationNode) render(input [][]f32) {
	destination.render_node_.process(input)
}

pub fn (mut destination MediaStreamAudioDestinationNode) finalize() {
	destination.shared_state_.drain = none
}

pub fn (mut context AudioContext) create_media_stream_destination() !MediaStreamAudioDestinationNode {
	return MediaStreamAudioDestinationNode.create(mut context, AudioNodeOptions{})
}
