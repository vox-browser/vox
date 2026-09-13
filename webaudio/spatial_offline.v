// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PannerNode, OfflineAudioContext, and
// OfflineAudioCompletionEvent.
module webaudio

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
	if options.ref_distance < 0 { return error('RangeError: refDistance cannot be negative') }
	if options.rolloff_factor < 0 { return error('RangeError: rolloffFactor cannot be negative') }
	// Mirrors the current upstream comparison (< 0), despite its spec comment saying non-positive.
	if options.max_distance < 0 { return error('RangeError: maxDistance cannot be negative') }
	if options.cone_outer_gain < 0 || options.cone_outer_gain > 1 {
		return error('InvalidStateError: coneOuterGain must be in [0, 1]')
	}
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
	return panner
}

pub fn (mut panner PannerNode) set_ref_distance(value f64) ! {
	if value < 0 { return error('RangeError: refDistance cannot be negative') }
	panner.ref_distance = value
}

pub fn (mut panner PannerNode) set_max_distance(value f64) ! {
	if value < 0 { return error('RangeError: maxDistance cannot be negative') }
	panner.max_distance = value
}

pub fn (mut panner PannerNode) set_rolloff_factor(value f64) ! {
	if value < 0 { return error('RangeError: rolloffFactor cannot be negative') }
	panner.rolloff_factor = value
}

pub fn (mut panner PannerNode) set_cone_outer_gain(value f64) ! {
	if value < 0 || value > 1 { return error('InvalidStateError: coneOuterGain must be in [0, 1]') }
	panner.cone_outer_gain = value
}

pub fn (mut panner PannerNode) set_position(x f32, y f32, z f32) {
	panner.position_x.set_value(x) or {}
	panner.position_y.set_value(y) or {}
	panner.position_z.set_value(z) or {}
}

pub fn (mut panner PannerNode) set_orientation(x f32, y f32, z f32) {
	panner.orientation_x.set_value(x) or {}
	panner.orientation_y.set_value(y) or {}
	panner.orientation_z.set_value(z) or {}
}

pub fn (mut panner PannerNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode == .max { return error("NotSupportedError: PannerNode does not support 'max'") }
	panner.node.channel_count_mode = mode
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
	if !context.fully_active || context.detached { return OfflineRenderResult{
			promise: AudioPromise{
				state:   .rejected
				message: 'InvalidStateError: Document is not fully active'
			}
		} }
	if context.rendering_started { return OfflineRenderResult{
			promise: AudioPromise{
				state:   .rejected
				message: 'InvalidStateError: Rendering is already started'
			}
		} }
	context.rendering_started = true
	buffer := new_audio_buffer(context.number_of_channels, context.length, context.base.sample_rate) or {
		return OfflineRenderResult{
			promise: AudioPromise{
				state:   .rejected
				message: err.msg()
			}
		}
	}
	context.rendered_buffer = buffer
	context.oncomplete_count++
	event := OfflineAudioCompletionEvent{
		event_type:      'complete'
		rendered_buffer: buffer
	}
	return OfflineRenderResult{
		promise: AudioPromise{
			state: .fulfilled
		}
		buffer:  buffer
		event:   event
	}
}

pub fn (_ OfflineAudioContext) resume() ! {
	return error('NotSupportedError: FIXME: Implement OfflineAudioContext::resume')
}

pub fn (_ OfflineAudioContext) suspend(_ f64) ! {
	return error('NotSupportedError: FIXME: Implement OfflineAudioContext::suspend')
}

pub struct OfflineAudioCompletionEvent {
pub:
	event_type      string
	rendered_buffer ?AudioBuffer
}
