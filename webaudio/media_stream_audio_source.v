// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaStreamAudioSourceNode and
// Rendering/MediaStreamSourceRenderNode.
module webaudio

import math
import mediacapture

const media_stream_source_ring_capacity = 4096

pub struct MediaStreamAudioSourceOptions {
pub:
	media_stream &mediacapture.MediaStream @[required]
}

// The native implementation uses an SPSC ring because capture and rendering
// run on different threads. The V engine currently drives both deterministically
// on one thread, while retaining the same bounded, whole-block drop behavior.
@[heap]
struct MediaStreamAudioRing {
	channel_count   int
	capacity_frames int
mut:
	interleaved_samples []f32
}

fn new_media_stream_audio_ring(capacity_frames int, channel_count int) &MediaStreamAudioRing {
	return &MediaStreamAudioRing{
		channel_count: channel_count
		capacity_frames: capacity_frames
	}
}

fn (ring &MediaStreamAudioRing) frames_available() int {
	return ring.interleaved_samples.len / ring.channel_count
}

fn (ring &MediaStreamAudioRing) frames_free() int {
	return ring.capacity_frames - ring.frames_available()
}

// Drop a complete incoming block when it cannot fit, so an overrun never
// replaces samples the render side has not consumed yet.
fn push_frames_if_enough_room(mut ring MediaStreamAudioRing, interleaved_samples []f32) int {
	if interleaved_samples.len == 0 || interleaved_samples.len % ring.channel_count != 0 {
		return 0
	}
	frame_count := interleaved_samples.len / ring.channel_count
	if ring.frames_free() < frame_count {
		return 0
	}
	ring.interleaved_samples << interleaved_samples
	return frame_count
}

fn (mut ring MediaStreamAudioRing) pop_frames(maximum_frames int) []f32 {
	frame_count := if ring.frames_available() < maximum_frames {
		ring.frames_available()
	} else {
		maximum_frames
	}
	sample_count := frame_count * ring.channel_count
	if sample_count == 0 {
		return []f32{}
	}
	result := ring.interleaved_samples[..sample_count].clone()
	ring.interleaved_samples.delete_many(0, sample_count)
	return result
}

fn convert_media_stream_frames(samples []f32, frame_count int, input_channels int,
	input_sample_rate u32, output_channels int, output_sample_rate u32) []f32 {
	if frame_count <= 0 || input_channels <= 0 || input_sample_rate == 0
		|| output_sample_rate == 0 || samples.len < frame_count * input_channels {
		return []f32{}
	}
	output_frame_count := int(math.round(f64(frame_count) * f64(output_sample_rate) / f64(input_sample_rate)))
	mut output := []f32{len: output_frame_count * output_channels}
	for output_frame in 0 .. output_frame_count {
		source_position := f64(output_frame) * f64(input_sample_rate) / f64(output_sample_rate)
		first_frame := int(math.floor(source_position))
		second_frame := if first_frame + 1 < frame_count { first_frame + 1 } else { first_frame }
		factor := f32(source_position - f64(first_frame))
		for output_channel in 0 .. output_channels {
			input_channel := if output_channel < input_channels { output_channel } else { 0 }
			first := samples[first_frame * input_channels + input_channel]
			second := samples[second_frame * input_channels + input_channel]
			output[output_frame * output_channels + output_channel] = first + (second - first) * factor
		}
	}
	return output
}

@[heap]
pub struct MediaStreamSourceRenderNode {
pub:
	node_id u64
mut:
	ring          &MediaStreamAudioRing
	channel_count int = 1
}

fn new_media_stream_source_render_node(node_id u64) &MediaStreamSourceRenderNode {
	return &MediaStreamSourceRenderNode{
		node_id: node_id
		ring: new_media_stream_audio_ring(media_stream_source_ring_capacity, 1)
	}
}

fn (mut render_node MediaStreamSourceRenderNode) handle_message(ring &MediaStreamAudioRing,
	channel_count u32) {
	render_node.ring = ring
	render_node.channel_count = if ring.channel_count > 0 {
		ring.channel_count
	} else if channel_count > 0 {
		int(channel_count)
	} else {
		1
	}
}

// Pull at most one render quantum sequentially. Startup or scheduling gaps
// remain silent at the tail rather than skipping, repeating, or reordering data.
pub fn (mut render_node MediaStreamSourceRenderNode) process(quantum_size int) [][]f32 {
	mut output := [][]f32{len: render_node.channel_count, init: []f32{len: quantum_size}}
	interleaved := render_node.ring.pop_frames(quantum_size)
	frames_popped := interleaved.len / render_node.channel_count
	for channel in 0 .. render_node.channel_count {
		for frame in 0 .. frames_popped {
			output[channel][frame] = interleaved[frame * render_node.channel_count + channel]
		}
	}
	return output
}

pub struct MediaStreamAudioSourceNode {
pub:
	node AudioNode
mut:
	media_stream_ &mediacapture.MediaStream
	input_track_  &mediacapture.MediaStreamTrack
	sink_         &mediacapture.AudioFrameSink
	render_node_  &MediaStreamSourceRenderNode
}

pub fn MediaStreamAudioSourceNode.create(mut context AudioContext,
	options MediaStreamAudioSourceOptions) !MediaStreamAudioSourceNode {
	mut audio_tracks := options.media_stream.get_audio_tracks()
	if audio_tracks.len == 0 {
		return error('InvalidStateError: MediaStream has no audio tracks')
	}
	audio_tracks.sort(a.id() < b.id())
	node := context.base.allocate_node(.media_stream_source, 0, 1, AudioNodeOptions{}, 2, .max, .speakers)!
	mut source := MediaStreamAudioSourceNode{
		node: node
		media_stream_: options.media_stream
		input_track_: audio_tracks[0]
		sink_: mediacapture.AudioFrameSink.create(none)
		render_node_: new_media_stream_source_render_node(node.id)
	}
	source.attach_input_track()
	return source
}

pub fn MediaStreamAudioSourceNode.create_for_constructor(mut context AudioContext,
	options MediaStreamAudioSourceOptions) !MediaStreamAudioSourceNode {
	return MediaStreamAudioSourceNode.create(mut context, options)
}

fn (mut source MediaStreamAudioSourceNode) attach_input_track() {
	output_channels := if source.input_track_.channel_count() == 1 { 1 } else { 2 }
	ring := new_media_stream_audio_ring(media_stream_source_ring_capacity, output_channels)
	source.render_node_.handle_message(ring, u32(output_channels))
	output_sample_rate := u32(source.node.graph.sample_rate)
	source.sink_ = mediacapture.AudioFrameSink.create(fn [ring, output_channels, output_sample_rate] (samples []f32, frame_count int, channel_count u8, sample_rate u32) {
		converted := convert_media_stream_frames(samples, frame_count, int(channel_count), sample_rate, output_channels, output_sample_rate)
		mut mutable_ring := unsafe { &MediaStreamAudioRing(ring) }
		push_frames_if_enough_room(mut mutable_ring, converted)
	})
	mut input_track := unsafe { &mediacapture.MediaStreamTrack(source.input_track_) }
	input_track.add_audio_sink(source.sink_)
}

pub fn (_ MediaStreamAudioSourceNode) number_of_inputs() u32 {
	return 0
}

pub fn (_ MediaStreamAudioSourceNode) number_of_outputs() u32 {
	return 1
}

pub fn (source MediaStreamAudioSourceNode) media_stream() &mediacapture.MediaStream {
	return source.media_stream_
}

pub fn (mut source MediaStreamAudioSourceNode) render(quantum_size int) [][]f32 {
	return source.render_node_.process(quantum_size)
}

pub fn (mut source MediaStreamAudioSourceNode) finalize() {
	mut input_track := unsafe { &mediacapture.MediaStreamTrack(source.input_track_) }
	input_track.remove_audio_sink(source.sink_)
}

pub fn (mut context AudioContext) create_media_stream_source(
	media_stream &mediacapture.MediaStream) !MediaStreamAudioSourceNode {
	return MediaStreamAudioSourceNode.create(mut context, MediaStreamAudioSourceOptions{
		media_stream: media_stream
	})
}
