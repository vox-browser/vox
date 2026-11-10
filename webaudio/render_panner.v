// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PannerRenderNode and its spatialization helpers.
module webaudio

import math

struct AudioVector3 {
	x f64
	y f64
	z f64
}

fn (vector AudioVector3) subtract(other AudioVector3) AudioVector3 {
	return AudioVector3{vector.x - other.x, vector.y - other.y, vector.z - other.z}
}

fn (vector AudioVector3) multiply(scale f64) AudioVector3 {
	return AudioVector3{vector.x * scale, vector.y * scale, vector.z * scale}
}

fn (vector AudioVector3) dot(other AudioVector3) f64 {
	return vector.x * other.x + vector.y * other.y + vector.z * other.z
}

fn (vector AudioVector3) cross(other AudioVector3) AudioVector3 {
	return AudioVector3{vector.y * other.z - vector.z * other.y, vector.z * other.x - vector.x * other.z, vector.x * other.y - vector.y * other.x}
}

fn (vector AudioVector3) length() f64 {
	return math.sqrt(vector.dot(vector))
}

fn safe_normalized(vector AudioVector3) AudioVector3 {
	length := vector.length()
	if length == 0 {
		return AudioVector3{}
	}
	return vector.multiply(1.0 / length)
}

fn panner_clamp(value f64, minimum f64, maximum f64) f64 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

// https://webaudio.github.io/web-audio-api/#azimuth-elevation
fn compute_azimuth(source_position AudioVector3, listener_position AudioVector3,
	listener_forward AudioVector3, listener_up AudioVector3) f64 {
	mut source_listener := source_position.subtract(listener_position)
	if source_listener.length() == 0 {
		return 0
	}
	source_listener = safe_normalized(source_listener)
	listener_right := listener_forward.cross(listener_up)
	if listener_right.length() == 0 {
		return 0
	}
	listener_right_normalized := safe_normalized(listener_right)
	listener_forward_normalized := safe_normalized(listener_forward)
	up := listener_right_normalized.cross(listener_forward_normalized)
	up_projection := source_listener.dot(up)
	mut projected_source := source_listener.subtract(up.multiply(up_projection))
	projected_source = safe_normalized(projected_source)
	mut azimuth := 180.0 * math.acos(panner_clamp(projected_source.dot(listener_right_normalized), -1.0, 1.0)) / math.pi
	if projected_source.dot(listener_forward_normalized) < 0 {
		azimuth = 360.0 - azimuth
	}
	if azimuth <= 90 {
		azimuth = 90.0 - azimuth
	} else {
		azimuth = 450.0 - azimuth
	}
	if azimuth > 180 {
		azimuth -= 360
	}
	return azimuth
}

pub struct PannerRenderConfig {
pub:
	panning_model    PanningModelType = .equalpower
	distance_model   DistanceModelType = .inverse
	ref_distance     f64 = 1
	max_distance     f64 = 10_000
	rolloff_factor   f64 = 1
	cone_inner_angle f64 = 360
	cone_outer_angle f64 = 360
	cone_outer_gain  f64
}

// https://webaudio.github.io/web-audio-api/#Spatialization-distance-effects
fn compute_distance_gain(distance f64, config PannerRenderConfig) f64 {
	match config.distance_model {
		.linear {
			minimum_distance := math.min(config.ref_distance, config.max_distance)
			maximum_distance := math.max(config.ref_distance, config.max_distance)
			rolloff_factor := panner_clamp(config.rolloff_factor, 0, 1)
			if minimum_distance == maximum_distance {
				return 1.0 - rolloff_factor
			}
			distance_ := panner_clamp(distance, minimum_distance, maximum_distance)
			return 1.0 - rolloff_factor * (distance_ - minimum_distance) / (maximum_distance - minimum_distance)
		}
		.inverse {
			if config.ref_distance == 0 {
				return 0
			}
			distance_ := math.max(distance, config.ref_distance)
			return config.ref_distance / (config.ref_distance + config.rolloff_factor * (distance_ - config.ref_distance))
		}
		.exponential {
			if config.ref_distance == 0 {
				return 0
			}
			distance_ := math.max(distance, config.ref_distance)
			return math.pow(distance_ / config.ref_distance, -config.rolloff_factor)
		}
	}
}

// https://webaudio.github.io/web-audio-api/#Spatialization-sound-cones
fn compute_cone_gain(source_position AudioVector3, source_orientation AudioVector3,
	listener_position AudioVector3, config PannerRenderConfig) f64 {
	if source_orientation.length() == 0
		|| (config.cone_inner_angle == 360 && config.cone_outer_angle == 360) {
		return 1
	}
	source_to_listener := safe_normalized(listener_position.subtract(source_position))
	normalized_source_orientation := safe_normalized(source_orientation)
	angle := 180.0 * math.acos(panner_clamp(source_to_listener.dot(normalized_source_orientation), -1.0, 1.0)) / math.pi
	absolute_angle := math.abs(angle)
	absolute_inner_angle := math.abs(config.cone_inner_angle) / 2.0
	absolute_outer_angle := math.abs(config.cone_outer_angle) / 2.0
	if absolute_angle <= absolute_inner_angle {
		return 1
	}
	if absolute_angle >= absolute_outer_angle {
		return config.cone_outer_gain
	}
	x := (absolute_angle - absolute_inner_angle) / (absolute_outer_angle - absolute_inner_angle)
	return 1.0 + (config.cone_outer_gain - 1.0) * x
}

pub struct PannerRenderParams {
pub:
	position_x    &RenderAudioParam
	position_y    &RenderAudioParam
	position_z    &RenderAudioParam
	orientation_x &RenderAudioParam
	orientation_y &RenderAudioParam
	orientation_z &RenderAudioParam
}

pub struct PannerListenerRenderParams {
pub:
	position_x &RenderAudioParam
	position_y &RenderAudioParam
	position_z &RenderAudioParam
	forward_x  &RenderAudioParam
	forward_y  &RenderAudioParam
	forward_z  &RenderAudioParam
	up_x       &RenderAudioParam
	up_y       &RenderAudioParam
	up_z       &RenderAudioParam
}

@[heap]
pub struct PannerRenderNode {
mut:
	render_node_     &RenderNode
	params_          PannerRenderParams
	listener_params_ PannerListenerRenderParams
	config_          PannerRenderConfig
	param_values_    [][]f32
}

pub fn PannerRenderNode.create(node_id u64, quantum_size int, params PannerRenderParams,
	listener_params PannerListenerRenderParams) &PannerRenderNode {
	mut render_node := RenderNode.create(node_id, 1, 1, quantum_size, 2)
	render_node.set_channel_count_mode(.clamped_max)
	for parameter in params.as_array() {
		render_node.add_param(parameter)
	}
	mut panner := &PannerRenderNode{
		render_node_: render_node
		params_: params
		listener_params_: listener_params
		config_: PannerRenderConfig{}
		param_values_: [][]f32{len: 15, init: []f32{len: quantum_size}}
	}
	panner_pointer := panner
	render_node.set_process_callback(fn [panner_pointer] (_ mut RenderNode, mut graph RenderGraph, context RenderContext) {
		mut mutable_panner := unsafe { &PannerRenderNode(panner_pointer) }
		mutable_panner.process(mut graph, context)
	})
	render_node.set_message_callback(fn [panner_pointer] (_ mut RenderNode, message NodeMessage) {
		mut mutable_panner := unsafe { &PannerRenderNode(panner_pointer) }
		mutable_panner.handle_message(message)
	})
	return panner
}

fn (params PannerRenderParams) as_array() []&RenderAudioParam {
	return [params.position_x, params.position_y, params.position_z, params.orientation_x,
		params.orientation_y, params.orientation_z]
}

fn (params PannerListenerRenderParams) as_array() []&RenderAudioParam {
	return [params.position_x, params.position_y, params.position_z, params.forward_x,
		params.forward_y, params.forward_z, params.up_x, params.up_y, params.up_z]
}

pub fn (panner &PannerRenderNode) render_node() &RenderNode {
	return panner.render_node_
}

pub fn (panner &PannerRenderNode) config() PannerRenderConfig {
	return panner.config_
}

pub fn (mut panner PannerRenderNode) handle_message(message NodeMessage) {
	if message.kind != .set_panner_parameters {
		return
	}
	panner.config_ = PannerRenderConfig{
		panning_model: message.panning_model
		distance_model: message.distance_model
		ref_distance: message.ref_distance
		max_distance: message.max_distance
		rolloff_factor: message.rolloff_factor
		cone_inner_angle: message.cone_inner_angle
		cone_outer_angle: message.cone_outer_angle
		cone_outer_gain: message.cone_outer_gain
	}
}

pub fn (mut panner PannerRenderNode) for_each_param(callback RenderAudioParamCallback) {
	for parameter in panner.params_.as_array() {
		mut mutable_parameter := unsafe { &RenderAudioParam(parameter) }
		callback(mut mutable_parameter)
	}
}

// https://webaudio.github.io/web-audio-api/#Spatialization
pub fn (mut panner PannerRenderNode) process(mut graph RenderGraph,
	context RenderContext) {
	mut render_node := unsafe { &RenderNode(panner.render_node_) }
	input := render_node.pull_input(mut graph, context, 0)
	mut output := unsafe { &AudioBus(render_node.output(0)) }
	output.set_channel_count(2)
	if input.is_silent() {
		output.zero()
		return
	}
	mut parameters := panner.params_.as_array()
	parameters << panner.listener_params_.as_array()
	for index, parameter in parameters {
		mut mutable_parameter := unsafe { &RenderAudioParam(parameter) }
		mutable_parameter.compute(mut graph, context, mut panner.param_values_[index])
	}
	mut output_left := []f32{len: context.quantum_size}
	mut output_right := []f32{len: context.quantum_size}
	input_left := input.channel(0)
	input_right := if input.channel_count() > 1 { input.channel(1) } else { input_left }
	for frame in 0 .. context.quantum_size {
		source_position := AudioVector3{panner.param_values_[0][frame], panner.param_values_[1][frame], panner.param_values_[2][frame]}
		source_orientation := AudioVector3{panner.param_values_[3][frame], panner.param_values_[4][frame], panner.param_values_[5][frame]}
		listener_position := AudioVector3{panner.param_values_[6][frame], panner.param_values_[7][frame], panner.param_values_[8][frame]}
		listener_forward := AudioVector3{panner.param_values_[9][frame], panner.param_values_[10][frame], panner.param_values_[11][frame]}
		listener_up := AudioVector3{panner.param_values_[12][frame], panner.param_values_[13][frame], panner.param_values_[14][frame]}
		mut azimuth := compute_azimuth(source_position, listener_position, listener_forward, listener_up)
		distance := source_position.subtract(listener_position).length()
		gain := f32(compute_distance_gain(distance, panner.config_) * compute_cone_gain(source_position, source_orientation, listener_position, panner.config_))
		if azimuth < -90 {
			azimuth = -180 - azimuth
		} else if azimuth > 90 {
			azimuth = 180 - azimuth
		}
		x := if input.channel_count() == 1 {
			(azimuth + 90.0) / 180.0
		} else if azimuth <= 0 {
			(azimuth + 90.0) / 90.0
		} else {
			azimuth / 90.0
		}
		pan_gains := equal_power_pan_gains(x)
		if input.channel_count() == 1 {
			output_left[frame] = input_left[frame] * pan_gains.left * gain
			output_right[frame] = input_left[frame] * pan_gains.right * gain
		} else if azimuth <= 0 {
			output_left[frame] = (input_left[frame] + input_right[frame] * pan_gains.left) * gain
			output_right[frame] = input_right[frame] * pan_gains.right * gain
		} else {
			output_left[frame] = input_left[frame] * pan_gains.left * gain
			output_right[frame] = (input_right[frame] + input_left[frame] * pan_gains.right) * gain
		}
	}
	output.set_channel(0, output_left)
	output.set_channel(1, output_right)
}
