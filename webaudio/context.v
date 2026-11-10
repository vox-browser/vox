// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BaseAudioContext, AudioContext, AudioDestinationNode, and
// MediaElementAudioSourceNode.
module webaudio

import time

pub enum AudioContextLatencyCategory {
	balanced
	interactive
	playback
}

pub struct AudioContextOptions {
pub:
	latency_category AudioContextLatencyCategory = .interactive
	latency_seconds  ?f64
	sample_rate      ?f32
}

pub struct AudioListener {
pub mut:
	forward_x  AudioParam
	forward_y  AudioParam
	forward_z  AudioParam
	position_x AudioParam
	position_y AudioParam
	position_z AudioParam
	up_x       AudioParam
	up_y       AudioParam
	up_z       AudioParam
}

pub struct AudioDestinationNode {
	AudioNode
pub:
	offline           bool
	max_channel_count u32
}

pub fn AudioDestinationNode.create(context_id u64, graph &AudioGraphState,
	channel_count u32, offline bool) !AudioDestinationNode {
	mut mutable_graph := unsafe { &AudioGraphState(graph) }
	mut node := AudioNode{
		id: 1
		context_id: context_id
		kind: .destination
		number_of_inputs: 1
		number_of_outputs: 1
		graph: mutable_graph
	}
	node.set_channel_count(channel_count)!
	node.channel_count_mode = .explicit
	node.queue_render_node_creation(DestinationRenderNode.create(node.id, int(channel_count), int(render_quantum_size)).render_node())
	return AudioDestinationNode{
		AudioNode: node
		offline: offline
		max_channel_count: if offline { channel_count } else { 2 }
	}
}

fn new_audio_listener(context_id u64, first_id u64, graph &AudioGraphState) AudioListener {
	mut next_id := first_id
	mut values := []AudioParam{}
	for value in [f32(0), 0, -1, 0, 0, 0, 0, 1, 0] {
		next_id++
		values << new_audio_param(next_id, context_id, graph, value, -3.402823e38, 3.402823e38, .a_rate, false)
	}
	return AudioListener{
		forward_x: values[0]
		forward_y: values[1]
		forward_z: values[2]
		position_x: values[3]
		position_y: values[4]
		position_z: values[5]
		up_x: values[6]
		up_y: values[7]
		up_z: values[8]
	}
}

pub fn (mut listener AudioListener) set_position(x f32, y f32, z f32) ! {
	listener.position_x.set_value(x)!
	listener.position_y.set_value(y)!
	listener.position_z.set_value(z)!
}

pub fn (mut listener AudioListener) set_orientation(x f32, y f32, z f32, up_x f32,
	up_y f32, up_z f32) ! {
	listener.forward_x.set_value(x)!
	listener.forward_y.set_value(y)!
	listener.forward_z.set_value(z)!
	listener.up_x.set_value(up_x)!
	listener.up_y.set_value(up_y)!
	listener.up_z.set_value(up_z)!
}

pub struct BaseAudioContext {
pub:
	id u64
pub mut:
	graph               &AudioGraphState
	sample_rate         f32
	state               AudioContextState = .suspended
	rendering_state     AudioContextState = .suspended
	destination         AudioDestinationNode
	listener            AudioListener
	next_id             u64 = 10
	control_messages    &ControlMessageQueue
	onstatechange_count u32
	onstatechange       bool
	media_element_tasks u32
	audio_worklet_      ?&AudioWorklet
}

pub fn verify_sample_rate(sample_rate f32) ! {
	if sample_rate < min_sample_rate || sample_rate > max_sample_rate {
		return error('NotSupportedError: Sample rate is outside of allowed range')
	}
}

pub fn verify_audio_options(number_of_channels u32, length u32, sample_rate f32) ! {
	if number_of_channels == 0 {
		return error("NotSupportedError: Number of channels must not be '0'")
	}
	if number_of_channels > max_number_of_channels {
		return error('NotSupportedError: Number of channels is greater than allowed range')
	}
	if length == 0 {
		return error('NotSupportedError: Length of buffer must be at least 1')
	}
	verify_sample_rate(sample_rate)!
}

fn make_base_context(id u64, sample_rate f32, destination_channels u32,
	offline bool) !BaseAudioContext {
	verify_sample_rate(sample_rate)!
	mut control_messages := &ControlMessageQueue{}
	mut graph := &AudioGraphState{
		sample_rate: sample_rate
	}
	graph.control_messages_ = control_messages
	destination_node := AudioDestinationNode.create(id, graph, destination_channels, offline)!
	listener := new_audio_listener(id, 1, graph)
	return BaseAudioContext{
		id: id
		graph: graph
		sample_rate: sample_rate
		destination: destination_node
		listener: listener
		next_id: 10
		control_messages: control_messages
	}
}

pub fn (context BaseAudioContext) nyquist_frequency() f32 {
	return context.sample_rate / 2
}

pub fn (_ BaseAudioContext) render_quantum_size() u32 {
	return render_quantum_size
}

fn (mut context BaseAudioContext) allocate_node(kind NodeKind, inputs u32, outputs u32, options AudioNodeOptions, default_count u32, default_mode ChannelCountMode, interpretation ChannelInterpretation) !AudioNode {
	context.next_id++
	mut node := AudioNode{
		id: context.next_id
		context_id: context.id
		kind: kind
		number_of_inputs: inputs
		number_of_outputs: outputs
		graph: context.graph
	}
	node.initialize_options(options, default_count, default_mode, interpretation)!
	return node
}

fn (mut context BaseAudioContext) allocate_param(default_value f32, min_value f32, max_value f32, rate AutomationRate, fixed bool) AudioParam {
	context.next_id++
	return new_audio_param(context.next_id, context.id, context.graph, default_value, min_value, max_value, rate, fixed)
}

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

pub struct AudioPromise {
pub:
	state   PromiseState
	message string
}

pub struct AudioContext {
pub mut:
	base              BaseAudioContext
	base_latency      f64
	output_latency    f64
	allowed_to_start  bool = true
	suspended_by_user bool
	fully_active      bool = true
	renderer          ?&RealtimeAudioRenderer
}

pub fn new_audio_context(id u64, sample_rate ?f32, fully_active bool) !AudioContext {
	if !fully_active {
		return error('InvalidStateError: Document is not fully active')
	}
	rate := sample_rate or { f32(44_100) }
	mut base := make_base_context(id, rate, 2, false)!
	base.rendering_state = .running
	base.state = .running
	// The constructor queues one statechange event after changing the initial
	// suspended state to running. This deterministic model observes that task as
	// completed before returning the context.
	base.onstatechange_count = 1
	mut renderer := RealtimeAudioRenderer.create(base.control_messages, base.destination.id, rate,
		int(render_quantum_size))
	renderer.start_rendering_with_null_output()
	mut context := AudioContext{
		base: base
		fully_active: fully_active
		renderer: renderer
	}
	context.set_renderer_callbacks()
	return context
}

pub fn new_audio_context_with_options(id u64, options AudioContextOptions, fully_active bool) !AudioContext {
	// Latency hints are intentionally accepted but are still FIXME upstream.
	return new_audio_context(id, options.sample_rate, fully_active)
}

pub fn (_ BaseAudioContext) destination_max_channel_count() u32 {
	return 2
}

pub fn (context AudioContext) output_timestamp() AudioTimestamp {
	renderer := context.renderer or { return AudioTimestamp{} }
	if renderer.frames_rendered() == 0 {
		return AudioTimestamp{}
	}
	return AudioTimestamp{
		context_time: renderer.output_time_played()
		performance_time: f64(time.now().unix_nano()) / 1.0e6
	}
}

pub struct AudioTimestamp {
pub:
	context_time     f64
	performance_time f64
}

pub fn (mut context AudioContext) resume() AudioPromise {
	if !context.fully_active {
		return AudioPromise{
			state: .rejected
			message: 'InvalidStateError: Document is not fully active'
		}
	}
	if context.base.state == .closed {
		return AudioPromise{
			state: .rejected
			message: 'InvalidStateError: Audio context is already closed'
		}
	}
	context.suspended_by_user = false
	context.base.state = .running
	context.base.rendering_state = .running
	context.set_renderer_callbacks()
	if mut renderer := context.renderer {
		renderer.resume()
	}
	return AudioPromise{
		state: .fulfilled
	}
}

pub fn (mut context AudioContext) suspend() AudioPromise {
	if !context.fully_active {
		return AudioPromise{
			state: .rejected
			message: 'InvalidStateError: Document is not fully active'
		}
	}
	if context.base.state == .closed {
		return AudioPromise{
			state: .rejected
			message: 'InvalidStateError: Audio context is already closed'
		}
	}
	context.suspended_by_user = true
	context.base.state = .suspended
	context.base.rendering_state = .suspended
	if mut renderer := context.renderer {
		renderer.suspend()
		renderer.clear_callbacks()
	}
	return AudioPromise{
		state: .fulfilled
	}
}

pub fn (mut context AudioContext) close() AudioPromise {
	if !context.fully_active {
		return AudioPromise{
			state: .rejected
			message: 'InvalidStateError: Document is not fully active'
		}
	}
	if context.base.state == .closed {
		return AudioPromise{
			state: .rejected
			message: 'InvalidStateError: Audio context is already closed'
		}
	}
	context.base.shutdown_audio_worklet()
	if mut renderer := context.renderer {
		renderer.stop()
		renderer.clear_callbacks()
	}
	context.base.rendering_state = .suspended
	context.base.state = .closed
	context.base.onstatechange_count++
	return AudioPromise{
		state: .fulfilled
	}
}

pub fn (context AudioContext) current_time() f64 {
	renderer := context.renderer or { return context.base.current_time() }
	return f64(renderer.frames_rendered()) / f64(context.base.sample_rate)
}

pub fn (mut context AudioContext) set_renderer_callbacks() {
	if mut renderer := context.renderer {
		graph := context.base.graph
		renderer.set_on_sources_ended(fn [graph] (ended_nodes []u64) {
			mut mutable_graph := unsafe { &AudioGraphState(graph) }
			mutable_graph.handle_ended_sources(ended_nodes)
		})
	}
}

// This is the V host boundary corresponding to the playback stream's data
// request callback. The native frontend supplies an interleaved device buffer.
pub fn (mut context AudioContext) fill_output_buffer(mut buffer []f32) []f32 {
	if context.base.state != .running {
		return []f32{}
	}
	mut renderer := context.renderer or { return []f32{} }
	result := renderer.fill_output_buffer(mut buffer)
	context.base.set_current_time(context.current_time())
	return result
}

pub fn (mut context AudioContext) document_became_inactive() {
	context.fully_active = false
	context.base.shutdown_audio_worklet()
	if mut renderer := context.renderer {
		renderer.stop()
		renderer.clear_callbacks()
	}
}

pub fn (mut context BaseAudioContext) create_buffer(number_of_channels u32, length u32, sample_rate f32) !AudioBuffer {
	return new_audio_buffer(number_of_channels, length, sample_rate)
}

// The native browser decodes through FFmpeg and resamples to the context rate;
// portable builds retain an in-process WAVE decoder for the same typed result.
// Promise and callback settlement is synchronous in this deterministic host.
pub fn (mut context BaseAudioContext) decode_audio_data(audio_data []u8,
	fully_active bool) DecodeResult {
	if !fully_active {
		return DecodeResult{
			promise: AudioPromise{
				state: .rejected
				message: 'InvalidStateError: The document is not fully active'
			}
		}
	}
	decoded := decode_audio_bytes(audio_data, context.sample_rate) or {
		context.media_element_tasks++
		return DecodeResult{
			promise: AudioPromise{
				state: .rejected
				message: 'EncodingError: Unable to decode audio data'
			}
		}
	}
	mut buffer := new_audio_buffer(u32(decoded.channels.len), u32(decoded.channels[0].len), decoded.sample_rate) or {
		context.media_element_tasks++
		return DecodeResult{
			promise: AudioPromise{
				state: .rejected
				message: 'EncodingError: Unable to decode audio data'
			}
		}
	}
	buffer.channels = decoded.channels
	context.media_element_tasks++
	return DecodeResult{
		promise: AudioPromise{
			state: .fulfilled
		}
		buffer: buffer
	}
}

pub struct DecodeResult {
pub:
	promise AudioPromise
	buffer  ?AudioBuffer
}

pub fn (mut context AudioContext) create_media_element_source(media_element_id string) !MediaElementAudioSourceNode {
	if media_element_id.len == 0 {
		return error('TypeError: mediaElement is required')
	}
	node := context.base.allocate_node(.media_element_source, 0, 1, AudioNodeOptions{}, 2, .max, .speakers)!
	return MediaElementAudioSourceNode{
		node: node
		media_element_id: media_element_id
	}
}

pub struct MediaElementAudioSourceNode {
pub:
	node             AudioNode
	media_element_id string
}

pub fn (mut context BaseAudioContext) set_destination_channel_count(count u32, offline bool) ! {
	if offline != context.destination.offline {
		return error('InvalidStateError: Destination context kind does not match')
	}
	context.destination.set_channel_count(count)!
}
