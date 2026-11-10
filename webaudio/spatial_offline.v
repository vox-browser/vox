// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PannerNode, OfflineAudioContext, and
// OfflineAudioCompletionEvent.
module webaudio

import math

pub struct PannerOptions {
pub:
	panning_model    PanningModelType  = .equalpower
	distance_model   DistanceModelType = .inverse
	position_x       f32
	position_y       f32
	position_z       f32
	orientation_x    f32 = 1
	orientation_y    f32
	orientation_z    f32
	ref_distance     f64 = 1
	max_distance     f64 = 10_000
	rolloff_factor   f64 = 1
	cone_inner_angle f64 = 360
	cone_outer_angle f64 = 360
	cone_outer_gain  f64
	node             AudioNodeOptions
}

pub struct PannerNode {
pub mut:
	node             AudioNode
	position_x       AudioParam
	position_y       AudioParam
	position_z       AudioParam
	orientation_x    AudioParam
	orientation_y    AudioParam
	orientation_z    AudioParam
	panning_model    PanningModelType
	distance_model   DistanceModelType
	ref_distance     f64
	max_distance     f64
	rolloff_factor   f64
	cone_inner_angle f64
	cone_outer_angle f64
	cone_outer_gain  f64
}

pub fn (mut context BaseAudioContext) create_panner(options PannerOptions) !PannerNode {
	PannerNode.validate_options(options)!
	node := context.allocate_node(.panner, 1, 1, options.node, 2, .clamped_max, .speakers)!
	mut panner := PannerNode{
		node:             node
		position_x:       context.allocate_param(options.position_x, float_lowest, float_highest,
			.a_rate, false)
		position_y:       context.allocate_param(options.position_y, float_lowest, float_highest,
			.a_rate, false)
		position_z:       context.allocate_param(options.position_z, float_lowest, float_highest,
			.a_rate, false)
		orientation_x:    context.allocate_param(options.orientation_x, float_lowest,
			float_highest, .a_rate, false)
		orientation_y:    context.allocate_param(options.orientation_y, float_lowest,
			float_highest, .a_rate, false)
		orientation_z:    context.allocate_param(options.orientation_z, float_lowest,
			float_highest, .a_rate, false)
		panning_model:    options.panning_model
		distance_model:   options.distance_model
		ref_distance:     options.ref_distance
		max_distance:     options.max_distance
		rolloff_factor:   options.rolloff_factor
		cone_inner_angle: options.cone_inner_angle
		cone_outer_angle: options.cone_outer_angle
		cone_outer_gain:  options.cone_outer_gain
	}
	if count := options.node.channel_count { panner.set_channel_count(count)! }
	if mode := options.node.channel_count_mode { panner.set_channel_count_mode(mode)! }
	panner.node.queue_render_node_creation(PannerRenderNode.create(node.id, int(render_quantum_size),
		PannerRenderParams{
			position_x: panner.position_x.render_param()
			position_y: panner.position_y.render_param()
			position_z: panner.position_z.render_param()
			orientation_x: panner.orientation_x.render_param()
			orientation_y: panner.orientation_y.render_param()
			orientation_z: panner.orientation_z.render_param()
		}, PannerListenerRenderParams{
			position_x: context.listener.position_x.render_param()
			position_y: context.listener.position_y.render_param()
			position_z: context.listener.position_z.render_param()
			forward_x: context.listener.forward_x.render_param()
			forward_y: context.listener.forward_y.render_param()
			forward_z: context.listener.forward_z.render_param()
			up_x: context.listener.up_x.render_param()
			up_y: context.listener.up_y.render_param()
			up_z: context.listener.up_z.render_param()
		}).render_node())
	panner.queue_panner_parameters_update()
	return panner
}

pub fn PannerNode.validate_options(options PannerOptions) ! {
	if options.ref_distance < 0 {
		return error('RangeError: refDistance cannot be negative')
	}
	if options.rolloff_factor < 0 {
		return error('RangeError: rolloffFactor cannot be negative')
	}
	if options.max_distance <= 0 {
		return error('RangeError: maxDistance must be positive')
	}
	if options.cone_outer_gain < 0 || options.cone_outer_gain > 1 {
		return error('InvalidStateError: coneOuterGain must be in [0, 1]')
	}
}

pub fn (panner PannerNode) queue_panner_parameters_update() {
	panner.node.enqueue_control_message(ControlMessage{
		kind: .node_message
		node_message: NodeMessage{
			node_id: panner.node.id
			kind: .set_panner_parameters
			panning_model: panner.panning_model
			distance_model: panner.distance_model
			ref_distance: panner.ref_distance
			max_distance: panner.max_distance
			rolloff_factor: panner.rolloff_factor
			cone_inner_angle: panner.cone_inner_angle
			cone_outer_angle: panner.cone_outer_angle
			cone_outer_gain: panner.cone_outer_gain
		}
	})
}

pub fn (mut panner PannerNode) set_ref_distance(value f64) ! {
	if value < 0 {
		return error('RangeError: refDistance cannot be negative')
	}
	panner.ref_distance = value
	panner.queue_panner_parameters_update()
}

pub fn (mut panner PannerNode) set_max_distance(value f64) ! {
	if value <= 0 {
		return error('RangeError: maxDistance must be positive')
	}
	panner.max_distance = value
	panner.queue_panner_parameters_update()
}

pub fn (mut panner PannerNode) set_rolloff_factor(value f64) ! {
	if value < 0 {
		return error('RangeError: rolloffFactor cannot be negative')
	}
	panner.rolloff_factor = value
	panner.queue_panner_parameters_update()
}

pub fn (mut panner PannerNode) set_cone_outer_gain(value f64) ! {
	if value < 0 || value > 1 {
		return error('InvalidStateError: coneOuterGain must be in [0, 1]')
	}
	panner.cone_outer_gain = value
	panner.queue_panner_parameters_update()
}

pub fn (mut panner PannerNode) set_position(x f32, y f32, z f32) ! {
	panner.position_x.set_value(x)!
	panner.position_y.set_value(y)!
	panner.position_z.set_value(z)!
}

pub fn (mut panner PannerNode) set_orientation(x f32, y f32, z f32) ! {
	panner.orientation_x.set_value(x)!
	panner.orientation_y.set_value(y)!
	panner.orientation_z.set_value(z)!
}

pub fn (mut panner PannerNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode == .max {
		return error("NotSupportedError: PannerNode does not support 'max'")
	}
	panner.node.set_channel_count_mode(mode)!
}

pub fn (mut panner PannerNode) set_channel_count(count u32) ! {
	if count > 2 {
		return error('NotSupportedError: PannerNode does not support channel count greater than 2')
	}
	panner.node.set_channel_count(count)!
}

pub struct OfflineAudioContext {
pub mut:
	base               BaseAudioContext
	length             u32
	number_of_channels u32
	rendering_started  bool
	rendered_buffer    ?AudioBuffer
	oncomplete_count   u32
	oncomplete         bool
	fully_active       bool = true
	detached           bool
	renderer           ?&OfflineAudioRenderer
	suspend_frames     map[u64]bool
}

pub struct OfflineAudioContextOptions {
pub:
	number_of_channels u32 = 1
	length             u32
	sample_rate        f32
}

pub fn new_offline_audio_context_with_options(id u64, options OfflineAudioContextOptions) !OfflineAudioContext {
	return new_offline_audio_context(id, options.number_of_channels, options.length,
		options.sample_rate)
}

pub fn new_offline_audio_context(id u64, number_of_channels u32, length u32, sample_rate f32) !OfflineAudioContext {
	verify_audio_options(number_of_channels, length, sample_rate)!
	base := make_base_context(id, sample_rate, number_of_channels, true)!
	return OfflineAudioContext{
		base:               base
		length:             length
		number_of_channels: number_of_channels
	}
}

pub struct OfflineRenderResult {
pub:
	promise AudioPromise
	buffer  ?AudioBuffer
	event   ?OfflineAudioCompletionEvent
}

pub fn (mut context OfflineAudioContext) start_rendering() OfflineRenderResult {
	if !context.fully_active || context.detached {
		return OfflineRenderResult{
			promise: AudioPromise{
				state: .rejected
				message: 'InvalidStateError: Document is not fully active'
			}
		}
	}
	if context.rendering_started {
		return OfflineRenderResult{
			promise: AudioPromise{
				state: .rejected
				message: 'InvalidStateError: Rendering is already started'
			}
		}
	}
	buffer := new_audio_buffer(context.number_of_channels, context.length, context.base.sample_rate) or {
		return OfflineRenderResult{
			promise: AudioPromise{
				state: .rejected
				message: err.msg()
			}
		}
	}
	context.rendering_started = true
	context.rendered_buffer = buffer
	mut renderer := OfflineAudioRenderer.create(context.base.control_messages,
		context.base.destination.id, int(context.number_of_channels), int(context.length),
		context.base.sample_rate, int(render_quantum_size))
	graph := context.base.graph
	renderer.set_on_sources_ended(fn [graph] (ended_nodes []u64) {
		mut mutable_graph := unsafe { &AudioGraphState(graph) }
		mutable_graph.handle_ended_sources(ended_nodes)
	})
	for frame, _ in context.suspend_frames {
		renderer.request_suspend(frame)
	}
	context.renderer = renderer
	context.base.state = .running
	context.base.rendering_state = .running
	context.queue_a_statechange_event()
	renderer.start_rendering()
	event := context.synchronize_renderer_state()
	if renderer.is_suspended() {
		return OfflineRenderResult{
			promise: AudioPromise{ state: .pending }
		}
	}
	completed_buffer := context.rendered_buffer or { buffer }
	return OfflineRenderResult{
		promise: AudioPromise{
			state: .fulfilled
		}
		buffer: completed_buffer
		event: event
	}
}

fn (mut context OfflineAudioContext) synchronize_renderer_state() ?OfflineAudioCompletionEvent {
	mut renderer := context.renderer or { return none }
	context.base.set_current_time(f64(renderer.frames_rendered()) / f64(context.base.sample_rate))
	if renderer.is_suspended() {
		context.handle_suspended()
		return none
	}
	if !renderer.is_complete() {
		return none
	}
	return context.finish_rendering()
}

fn (mut context OfflineAudioContext) finish_rendering() OfflineAudioCompletionEvent {
	mut renderer := context.renderer or { panic('offline renderer is missing') }
	mut buffer := context.rendered_buffer or { panic('offline rendered buffer is missing') }
	buffer.channels = renderer.rendered_channels()
	context.rendered_buffer = buffer
	context.base.set_current_time(f64(renderer.frames_rendered()) / f64(context.base.sample_rate))
	context.base.state = .closed
	context.base.rendering_state = .closed
	context.queue_a_statechange_event()
	renderer.clear_callbacks()
	context.oncomplete_count++
	return OfflineAudioCompletionEvent{
		event_type: 'complete'
		rendered_buffer: buffer
	}
}

fn (mut context OfflineAudioContext) handle_suspended() {
	if renderer := context.renderer {
		context.suspend_frames.delete(renderer.frames_rendered())
	}
	context.base.state = .suspended
	context.base.rendering_state = .suspended
	context.queue_a_statechange_event()
}

fn (mut context OfflineAudioContext) queue_a_statechange_event() {
	context.base.onstatechange_count++
}

pub fn (mut context OfflineAudioContext) resume() ! {
	mut renderer := context.renderer or {
		return error('InvalidStateError: The OfflineAudioContext is not suspended')
	}
	if context.base.state != .suspended || !renderer.is_suspended() {
		return error('InvalidStateError: The OfflineAudioContext is not suspended')
	}
	context.base.state = .running
	context.base.rendering_state = .running
	context.queue_a_statechange_event()
	renderer.resume()
	context.synchronize_renderer_state()
}

pub fn (mut context OfflineAudioContext) suspend(suspend_time f64) ! {
	if math.is_nan(suspend_time) || math.is_inf(suspend_time, 0) || suspend_time < 0 {
		return error('RangeError: Suspend time must be a finite, non-negative number')
	}
	mut frame := u64(math.round(suspend_time * f64(context.base.sample_rate)))
	quantum_size := u64(render_quantum_size)
	frame = ((frame + quantum_size - 1) / quantum_size) * quantum_size
	if frame >= u64(context.length) {
		return error('RangeError: Suspend time must be less than the duration of the context')
	}
	if frame in context.suspend_frames {
		return error('InvalidStateError: A suspension is already scheduled at this time')
	}
	context.suspend_frames[frame] = true
	if mut renderer := context.renderer {
		if !renderer.request_suspend(frame) {
			context.suspend_frames.delete(frame)
			return error('InvalidStateError: The rendering thread has already passed the requested suspend time')
		}
	}
}

pub fn (mut context OfflineAudioContext) document_became_inactive() {
	context.fully_active = false
	if mut renderer := context.renderer {
		renderer.stop()
		renderer.clear_callbacks()
	}
}

pub struct OfflineAudioCompletionEvent {
pub:
	event_type      string
	rendered_buffer ?AudioBuffer
}
