// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compositor/VisualAnimation.{h,cpp}. The compositor receives
// already-resolved device-pixel transforms and samples them independently of
// style/layout on every frame.
module compositor

import css
import math
import painting

pub enum VisualAnimationEasingKind {
	linear
	cubic_bezier
	steps
}

pub struct VisualAnimationLinearPoint {
pub:
	input  f64
	output f64
}

pub struct VisualAnimationEasing {
pub:
	kind           VisualAnimationEasingKind
	linear_points  []VisualAnimationLinearPoint = [VisualAnimationLinearPoint{0, 0},
		VisualAnimationLinearPoint{1, 1}]
	x1             f64
	y1             f64
	x2             f64 = 1
	y2             f64 = 1
	interval_count i32 = 1
	step_position  u8
}

pub fn VisualAnimationEasing.from_css(easing css.EasingFunction) VisualAnimationEasing {
	return match easing.value {
		css.LinearEasingFunction {
			mut points := []VisualAnimationLinearPoint{cap: easing.value.control_points.len}
			for point in easing.value.control_points {
				points << VisualAnimationLinearPoint{point.input or { 0 }, point.output}
			}
			VisualAnimationEasing{
				kind: .linear
				linear_points: points
			}
		}
		css.CubicBezierEasingFunction {
			VisualAnimationEasing{
				kind: .cubic_bezier
				linear_points: []
				x1: easing.value.x1
				y1: easing.value.y1
				x2: easing.value.x2
				y2: easing.value.y2
			}
		}
		css.StepsEasingFunction {
			VisualAnimationEasing{
				kind: .steps
				linear_points: []
				interval_count: i32(easing.value.interval_count)
				step_position: u8(easing.value.position)
			}
		}
	}
}

pub fn (easing VisualAnimationEasing) evaluate_at(input_progress f64, before_flag bool) f64 {
	return match easing.kind {
		.linear {
			mut points := []css.LinearEasingControlPoint{cap: easing.linear_points.len}
			for point in easing.linear_points {
				points << css.LinearEasingControlPoint{
					input: point.input
					output: point.output
				}
			}
			css.LinearEasingFunction{ control_points: points }.evaluate_at(input_progress, before_flag)
		}
		.cubic_bezier {
			css.CubicBezierEasingFunction{
				x1: easing.x1
				y1: easing.y1
				x2: easing.x2
				y2: easing.y2
			}.evaluate_at(input_progress, before_flag)
		}
		.steps {
			position := match easing.step_position {
				0 { css.StepPosition.jump_start }
				1 { css.StepPosition.jump_end }
				2 { css.StepPosition.jump_none }
				3 { css.StepPosition.jump_both }
				4 { css.StepPosition.start }
				else { css.StepPosition.end }
			}
			css.StepsEasingFunction{
				interval_count: easing.interval_count
				position: position
			}.evaluate_at(input_progress, before_flag)
		}
	}
}

fn finite(value f64) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

pub fn (easing VisualAnimationEasing) is_valid() bool {
	if !finite(easing.x1) || !finite(easing.y1) || !finite(easing.x2) || !finite(easing.y2) {
		return false
	}
	return match easing.kind {
		.linear {
			if easing.linear_points.len < 2 {
				false
			} else {
				mut valid := true
				mut previous_input := -math.max_f64
				for point in easing.linear_points {
					if !finite(point.input) || !finite(point.output) || point.input < previous_input {
						valid = false
						break
					}
					previous_input = point.input
				}
				valid
			}
		}
		.cubic_bezier { easing.x1 >= 0 && easing.x1 <= 1 && easing.x2 >= 0 && easing.x2 <= 1 }
		.steps { easing.interval_count > 0 && easing.step_position <= 5 }
	}
}

pub enum VisualAnimationPlaybackDirection {
	normal
	reverse
	alternate
	alternate_reverse
}

pub enum VisualAnimationFillMode {
	none
	backwards
}

pub enum VisualAnimationTransformOperationKind {
	translate
	translate3d
	translate_x
	translate_y
	translate_z
	scale
	scale3d
	scale_x
	scale_y
	scale_z
	rotate
	rotate_x
	rotate_y
	rotate_z
	skew
	skew_x
	skew_y
}

pub struct VisualAnimationMatrix {
pub:
	m11 f64 = 1
	m12 f64
	m13 f64
	m14 f64
	m21 f64
	m22 f64 = 1
	m23 f64
	m24 f64
	m31 f64
	m32 f64
	m33 f64 = 1
	m34 f64
	m41 f64
	m42 f64
	m43 f64
	m44 f64 = 1
}

pub fn (left VisualAnimationMatrix) multiply(right VisualAnimationMatrix) VisualAnimationMatrix {
	mut values := [16]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			mut value := 0.0
			for inner in 0 .. 4 {
				value += left.at(row, inner) * right.at(inner, column)
			}
			values[row * 4 + column] = value
		}
	}
	return VisualAnimationMatrix.from_values(values)
}

pub fn (matrix VisualAnimationMatrix) at(row int, column int) f64 {
	return match row * 4 + column {
		0 { matrix.m11 }
		1 { matrix.m12 }
		2 { matrix.m13 }
		3 { matrix.m14 }
		4 { matrix.m21 }
		5 { matrix.m22 }
		6 { matrix.m23 }
		7 { matrix.m24 }
		8 { matrix.m31 }
		9 { matrix.m32 }
		10 { matrix.m33 }
		11 { matrix.m34 }
		12 { matrix.m41 }
		13 { matrix.m42 }
		14 { matrix.m43 }
		15 { matrix.m44 }
		else { panic('matrix index outside 4x4 bounds') }
	}
}

fn VisualAnimationMatrix.from_values(values [16]f64) VisualAnimationMatrix {
	return VisualAnimationMatrix{
		m11: values[0]
		m12: values[1]
		m13: values[2]
		m14: values[3]
		m21: values[4]
		m22: values[5]
		m23: values[6]
		m24: values[7]
		m31: values[8]
		m32: values[9]
		m33: values[10]
		m34: values[11]
		m41: values[12]
		m42: values[13]
		m43: values[14]
		m44: values[15]
	}
}

pub struct VisualAnimationTransformOperation {
pub:
	kind   VisualAnimationTransformOperationKind
	values []f32
}

fn translation_matrix(x f64, y f64, z f64) VisualAnimationMatrix {
	return VisualAnimationMatrix{ m14: x, m24: y, m34: z }
}

fn scale_matrix(x f64, y f64, z f64) VisualAnimationMatrix {
	return VisualAnimationMatrix{ m11: x, m22: y, m33: z }
}

fn rotation_matrix(x f64, y f64, z f64, angle f64) VisualAnimationMatrix {
	length := math.sqrt(x * x + y * y + z * z)
	if length == 0 {
		return VisualAnimationMatrix{}
	}
	nx := x / length
	ny := y / length
	nz := z / length
	c := math.cos(angle)
	s := math.sin(angle)
	t := 1.0 - c
	return VisualAnimationMatrix.from_values([t * nx * nx + c, t * nx * ny - s * nz,
		t * nx * nz + s * ny, 0, t * nx * ny + s * nz, t * ny * ny + c, t * ny * nz - s * nx, 0,
		t * nx * nz - s * ny, t * ny * nz + s * nx, t * nz * nz + c, 0, 0, 0, 0, 1]!)
}

pub fn (operation VisualAnimationTransformOperation) to_matrix() VisualAnimationMatrix {
	values := operation.values
	return match operation.kind {
		.translate { translation_matrix(values[0], if values.len == 2 { values[1] } else { 0 }, 0) }
		.translate3d { translation_matrix(values[0], values[1], values[2]) }
		.translate_x { translation_matrix(values[0], 0, 0) }
		.translate_y { translation_matrix(0, values[0], 0) }
		.translate_z { translation_matrix(0, 0, values[0]) }
		.scale { scale_matrix(values[0], if values.len == 2 { values[1] } else { values[0] }, 1) }
		.scale3d { scale_matrix(values[0], values[1], values[2]) }
		.scale_x { scale_matrix(values[0], 1, 1) }
		.scale_y { scale_matrix(1, values[0], 1) }
		.scale_z { scale_matrix(1, 1, values[0]) }
		.rotate, .rotate_z { rotation_matrix(0, 0, 1, values[0]) }
		.rotate_x { rotation_matrix(1, 0, 0, values[0]) }
		.rotate_y { rotation_matrix(0, 1, 0, values[0]) }
		.skew {
			VisualAnimationMatrix.from_values([f64(1), math.tan(values[0]), 0, 0,
				if values.len == 2 { math.tan(values[1]) } else { 0 }, 1, 0, 0, 0, 0, 1, 0, 0, 0,
				0, 1]!)
		}
		.skew_x {
			VisualAnimationMatrix.from_values([f64(1), math.tan(values[0]), 0, 0, 0, 1, 0, 0, 0,
				0, 1, 0, 0, 0, 0, 1]!)
		}
		.skew_y {
			VisualAnimationMatrix.from_values([f64(1), 0, 0, 0, math.tan(values[0]), 1, 0, 0, 0,
				0, 1, 0, 0, 0, 0, 1]!)
		}
	}
}

pub fn (operation VisualAnimationTransformOperation) is_valid() bool {
	expected := match operation.kind {
		.translate, .scale, .skew {
			if operation.values.len != 1 && operation.values.len != 2 {
				return false
			}
			operation.values.len
		}
		.translate3d, .scale3d { 3 }
		else { 1 }
	}
	if operation.values.len != expected {
		return false
	}
	return operation.values.all(finite(it))
}

pub enum VisualAnimationFilterOperationKind {
	blur
	drop_shadow
	color
	hue_rotate
}

pub struct VisualAnimationFilterOperation {
pub:
	kind            VisualAnimationFilterOperationKind
	amount          f32
	offset_x        f32
	offset_y        f32
	color           painting.Color = painting.transparent
	color_operation painting.ColorFilterType = .brightness
}

pub fn (operation VisualAnimationFilterOperation) matches(other VisualAnimationFilterOperation) bool {
	return operation.kind == other.kind
		&& (operation.kind != .color || operation.color_operation == other.color_operation)
}

pub fn (operation VisualAnimationFilterOperation) initial_value() VisualAnimationFilterOperation {
	amount := if operation.kind == .color && operation.color_operation !in [.grayscale, .invert,
		.sepia] {
		f32(1)
	} else {
		f32(0)
	}
	return VisualAnimationFilterOperation{
		kind: operation.kind
		amount: amount
		color_operation: operation.color_operation
	}
}

fn interpolate_legacy_srgb_color(from painting.Color, to painting.Color, progress f64) painting.Color {
	from_alpha := f64(from.a) / 255.0
	to_alpha := f64(to.a) / 255.0
	alpha := math.max(0.0, math.min(from_alpha + (to_alpha - from_alpha) * progress, 1.0))
	if alpha == 0 {
		return painting.transparent
	}
	interpolate_channel := fn [from_alpha, to_alpha, alpha, progress] (from_channel u8, to_channel u8) u8 {
		from_premultiplied := f64(from_channel) * from_alpha
		to_premultiplied := f64(to_channel) * to_alpha
		channel := (from_premultiplied + (to_premultiplied - from_premultiplied) * progress) / alpha
		return u8(math.round(math.max(0.0, math.min(channel, 255.0))))
	}
	return painting.Color{
		r: interpolate_channel(from.r, to.r)
		g: interpolate_channel(from.g, to.g)
		b: interpolate_channel(from.b, to.b)
		a: u8(math.round(alpha * 255.0))
	}
}

pub fn (operation VisualAnimationFilterOperation) interpolated_with(other VisualAnimationFilterOperation, progress f64) VisualAnimationFilterOperation {
	assert operation.matches(other)
	interpolate := fn [progress] (from f32, to f32) f32 {
		return f32(f64(from) + f64(to - from) * progress)
	}
	mut amount := interpolate(operation.amount, other.amount)
	if operation.kind in [.blur, .drop_shadow, .color] && amount < 0 {
		amount = 0
	}
	if operation.kind == .color && operation.color_operation in [.grayscale, .invert, .opacity,
		.sepia] && amount > 1 {
		amount = 1
	}
	return VisualAnimationFilterOperation{
		kind: operation.kind
		amount: amount
		offset_x: interpolate(operation.offset_x, other.offset_x)
		offset_y: interpolate(operation.offset_y, other.offset_y)
		color: if operation.kind == .drop_shadow {
			interpolate_legacy_srgb_color(operation.color, other.color, progress)
		} else {
			operation.color
		}
		color_operation: operation.color_operation
	}
}

pub fn (operation VisualAnimationFilterOperation) is_valid() bool {
	if !finite(operation.amount) || !finite(operation.offset_x) || !finite(operation.offset_y) {
		return false
	}
	if operation.kind in [.blur, .drop_shadow] && operation.amount < 0 {
		return false
	}
	if operation.kind != .color {
		return true
	}
	if operation.amount < 0 {
		return false
	}
	return operation.color_operation !in [.grayscale, .invert, .opacity, .sepia] || operation.amount <= 1
}

pub struct OpacityAnimationValue {
pub:
	value f32
}

pub struct BackgroundColorAnimationValue {
pub:
	value painting.Color
}

pub struct FilterListAnimationValue {
pub:
	operations []VisualAnimationFilterOperation
}

pub struct TransformListAnimationValue {
pub:
	operations []VisualAnimationTransformOperation
}

pub type VisualAnimationValue = BackgroundColorAnimationValue
	| FilterListAnimationValue
	| OpacityAnimationValue
	| TransformListAnimationValue

pub struct VisualAnimationKeyframe {
pub:
	offset f64
	easing VisualAnimationEasing
	value  VisualAnimationValue
}

pub enum VisualAnimationTargetKind {
	opacity
	background_color
	filter
	transform
}

pub struct VisualAnimationSample {
pub:
	opacity           f32 = 1
	background_color  ?painting.Color
	samples_filter    bool
	filter_operations []VisualAnimationFilterOperation
	transform         VisualAnimationMatrix
}

pub struct VisualAnimation {
pub:
	target_kind                 VisualAnimationTargetKind
	visual_context_node_indices []u32
	monotonic_time_at_anchor_ns i64
	local_time_at_anchor_ms     f64
	playback_rate               f64 = 1
	start_delay_ms              f64
	iteration_duration_ms       f64
	iteration_count             f64 = 1.7976931348623157e308
	iteration_start             f64
	playback_direction          VisualAnimationPlaybackDirection
	fill_mode                   VisualAnimationFillMode
	easing                      VisualAnimationEasing
	keyframes                   []VisualAnimationKeyframe
}

pub fn (animation VisualAnimation) has_same_parameters_except_anchor(other VisualAnimation) bool {
	return animation.target_kind == other.target_kind
		&& animation.visual_context_node_indices == other.visual_context_node_indices
		&& animation.has_same_animation_parameters(other)
}

pub fn (animation VisualAnimation) has_same_animation_parameters(other VisualAnimation) bool {
	return animation.target_kind == other.target_kind
		&& animation.playback_rate == other.playback_rate
		&& animation.start_delay_ms == other.start_delay_ms
		&& animation.iteration_duration_ms == other.iteration_duration_ms
		&& animation.iteration_count == other.iteration_count
		&& animation.iteration_start == other.iteration_start
		&& animation.playback_direction == other.playback_direction
		&& animation.fill_mode == other.fill_mode && animation.easing == other.easing
		&& animation.keyframes == other.keyframes
}

fn interpolate_value(from VisualAnimationValue, to VisualAnimationValue, progress f64) VisualAnimationValue {
	return match from {
		OpacityAnimationValue {
			target := to as OpacityAnimationValue
			OpacityAnimationValue{f32(f64(from.value) + f64(target.value - from.value) * progress)}
		}
		BackgroundColorAnimationValue {
			target := to as BackgroundColorAnimationValue
			BackgroundColorAnimationValue{interpolate_legacy_srgb_color(from.value, target.value, progress)}
		}
		FilterListAnimationValue {
			target := to as FilterListAnimationValue
			mut from_filters := from.operations.clone()
			mut to_filters := target.operations.clone()
			for from_filters.len < to_filters.len {
				from_filters << to_filters[from_filters.len].initial_value()
			}
			for to_filters.len < from_filters.len {
				to_filters << from_filters[to_filters.len].initial_value()
			}
			mut mismatch := false
			for index in 0 .. from_filters.len {
				if !from_filters[index].matches(to_filters[index]) {
					mismatch = true
					break
				}
			}
			if mismatch {
				if progress < 0.5 { from } else { target }
			} else {
				mut operations := []VisualAnimationFilterOperation{cap: from_filters.len}
				for index in 0 .. from_filters.len {
					operations << from_filters[index].interpolated_with(to_filters[index], progress)
				}
				FilterListAnimationValue{operations}
			}
		}
		TransformListAnimationValue {
			target := to as TransformListAnimationValue
			mut operations := []VisualAnimationTransformOperation{cap: from.operations.len}
			for index, from_operation in from.operations {
				to_operation := target.operations[index]
				mut values := []f32{cap: from_operation.values.len}
				for value_index, from_value in from_operation.values {
					to_value := to_operation.values[value_index]
					values << f32(f64(from_value) + f64(to_value - from_value) * progress)
				}
				operations << VisualAnimationTransformOperation{from_operation.kind, values}
			}
			TransformListAnimationValue{operations}
		}
	}
}

pub fn (animation VisualAnimation) sample(elapsed_since_anchor_seconds f64) ?VisualAnimationSample {
	if animation.iteration_duration_ms <= 0 || animation.playback_rate <= 0
		|| animation.keyframes.len < 2 {
		return none
	}
	mut local_time := animation.local_time_at_anchor_ms + elapsed_since_anchor_seconds * 1000.0 * animation.playback_rate
	if !finite(local_time) {
		return none
	}
	is_in_before_phase := local_time < animation.start_delay_ms
	if is_in_before_phase {
		if animation.fill_mode != .backwards {
			return none
		}
		local_time = animation.start_delay_ms
	}
	overall_progress := (local_time - animation.start_delay_ms) / animation.iteration_duration_ms + animation.iteration_start
	if !finite(overall_progress) || overall_progress < 0 {
		return none
	}
	active_progress := overall_progress - animation.iteration_start
	is_at_or_after_end := finite(animation.iteration_count)
		&& active_progress >= animation.iteration_count
	mut current_iteration := math.floor(overall_progress)
	mut simple_iteration_progress := math.fmod(overall_progress, 1.0)
	if is_at_or_after_end {
		terminal := animation.iteration_start + animation.iteration_count
		simple_iteration_progress = math.fmod(terminal, 1.0)
		if simple_iteration_progress == 0 {
			simple_iteration_progress = 1
		}
		current_iteration = math.floor(terminal) - if simple_iteration_progress == 1 {
			1
		} else {
			0
		}
	}
	going_forwards := match animation.playback_direction {
		.normal { true }
		.reverse { false }
		.alternate { math.fmod(current_iteration, 2.0) == 0 }
		.alternate_reverse { math.fmod(current_iteration + 1.0, 2.0) == 0 }
	}
	directed_progress := if going_forwards {
		simple_iteration_progress
	} else {
		1.0 - simple_iteration_progress
	}
	before_flag := (is_in_before_phase && going_forwards)
		|| (is_at_or_after_end && !going_forwards)
	transformed_progress := animation.easing.evaluate_at(directed_progress, before_flag)
	if !finite(transformed_progress) {
		return none
	}
	mut from_index := 0
	mut to_index := 1
	for index := 1; index < animation.keyframes.len; index++ {
		from_index = index - 1
		to_index = index
		if transformed_progress < animation.keyframes[index].offset {
			break
		}
	}
	from := animation.keyframes[from_index]
	to := animation.keyframes[to_index]
	interval_width := to.offset - from.offset
	assert interval_width > 0
	interval_progress := (transformed_progress - from.offset) / interval_width
	eased_progress := from.easing.evaluate_at(interval_progress, false)
	if !finite(eased_progress) {
		return none
	}
	value := interpolate_value(from.value, to.value, eased_progress)
	mut sample := VisualAnimationSample{}
	match value {
		OpacityAnimationValue {
			sample = VisualAnimationSample{ opacity: value.value }
		}
		BackgroundColorAnimationValue {
			sample = VisualAnimationSample{ background_color: value.value }
		}
		FilterListAnimationValue {
			if value.operations.any(!it.is_valid()) {
				return none
			}
			sample = VisualAnimationSample{
				samples_filter: true
				filter_operations: value.operations.clone()
			}
		}
		TransformListAnimationValue {
			mut transform := VisualAnimationMatrix{}
			for operation in value.operations {
				transform = transform.multiply(operation.to_matrix())
			}
			sample = VisualAnimationSample{ transform: transform }
		}
	}
	return match animation.target_kind {
		.opacity {
			if !finite(sample.opacity) {
				none
			} else {
				VisualAnimationSample{
					...sample
					opacity: if sample.opacity < 0 {
						0
					} else if sample.opacity > 1 {
						1
					} else {
						sample.opacity
					}
				}
			}
		}
		.background_color {
			if sample.background_color == none { none } else { sample }
		}
		.filter {
			if !sample.samples_filter { none } else { sample }
		}
		.transform {
			mut valid := true
			for row in 0 .. 4 {
				for column in 0 .. 4 {
					if !finite(sample.transform.at(row, column)) {
						valid = false
					}
				}
			}
			if valid { sample } else { none }
		}
	}
}

pub fn (animation VisualAnimation) is_valid() bool {
	if animation.visual_context_node_indices.len == 0 || animation.monotonic_time_at_anchor_ns < 0
		|| !finite(animation.local_time_at_anchor_ms) || !finite(animation.playback_rate)
		|| animation.playback_rate <= 0 || !finite(animation.start_delay_ms)
		|| !finite(animation.iteration_duration_ms) || animation.iteration_duration_ms <= 0
		|| math.is_nan(animation.iteration_count) || animation.iteration_count <= 0
		|| !finite(animation.iteration_start) || animation.iteration_start < 0
		|| !animation.easing.is_valid() || animation.keyframes.len < 2 {
		return false
	}
	if animation.keyframes[0].offset != 0
		|| animation.keyframes[animation.keyframes.len - 1].offset != 1 {
		return false
	}
	mut transform_operation_count := ?int(none)
	for index, keyframe in animation.keyframes {
		if !finite(keyframe.offset) || keyframe.offset < 0 || keyframe.offset > 1
			|| !keyframe.easing.is_valid() || (index > 0
			&& keyframe.offset <= animation.keyframes[index - 1].offset) {
			return false
		}
		match animation.target_kind {
			.opacity {
				if keyframe.value !is OpacityAnimationValue {
					return false
				}
				opacity := (keyframe.value as OpacityAnimationValue).value
				if !finite(opacity) || opacity < 0 || opacity > 1 {
					return false
				}
			}
			.background_color {
				if keyframe.value !is BackgroundColorAnimationValue {
					return false
				}
			}
			.filter {
				if keyframe.value !is FilterListAnimationValue {
					return false
				}
				filters := (keyframe.value as FilterListAnimationValue).operations
				if filters.any(!it.is_valid()) {
					return false
				}
			}
			.transform {
				if keyframe.value !is TransformListAnimationValue {
					return false
				}
				operations := (keyframe.value as TransformListAnimationValue).operations
				if operations.len == 0 {
					return false
				}
				if count := transform_operation_count {
					if operations.len != count {
						return false
					}
				} else {
					transform_operation_count = operations.len
				}
				for operation_index, operation in operations {
					if !operation.is_valid() {
						return false
					}
					if index > 0 {
						previous := (animation.keyframes[index - 1].value as TransformListAnimationValue).operations[operation_index]
						if operation.kind != previous.kind
							|| operation.values.len != previous.values.len {
							return false
						}
					}
				}
			}
		}
	}
	return true
}
