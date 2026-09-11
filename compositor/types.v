// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compositor/{Types,SmoothScrollAnimation}.{h,cpp}. Geometry
// remains in device pixels at this boundary, just as it does upstream.
module compositor

import css
import math
import painting

pub type CompositorContextId = u64

pub type ScreenshotRequestId = u64

pub type AsyncScrollOperationId = u64

pub fn compositor_context_id_for_page(page_id u64) !CompositorContextId {
	if page_id == 0 {
		return error('a compositor context cannot be created for page 0')
	}
	return CompositorContextId(page_id)
}

pub enum WindowResizingInProgress {
	no
	yes
}

pub enum ContextVisibility {
	visible
	hidden
}

pub enum PagePresentationRegistration {
	no
	yes
}

pub enum AsyncScrollUpdateFreshness {
	pushed
	from_compositor
}

pub enum AsyncScrollOperationTracking {
	no
	yes
}

pub enum ScrollAnimationKind {
	smooth_scroll
	momentum
}

pub struct PendingAsyncScrollUpdates {
pub:
	sequence                               u64
	scroll_offsets                         []AsyncScrollOffset
	completed_operation_ids                []AsyncScrollOperationId
	operation_ids_taken_over_by_user_input []AsyncScrollOperationId
	user_scroll_gesture_in_progress        bool
	user_scroll_gesture_ended              bool
}

pub struct AsyncScrollEnqueueResult {
pub:
	accepted     bool
	operation_id ?AsyncScrollOperationId
}

pub struct SmoothScrollSample {
pub:
	offset   painting.Point
	complete bool
}

pub struct SmoothScrollAnimation {
	start_offset_       painting.Point
	destination_offset_ painting.Point
	duration_seconds_   f64
	kind_               ScrollAnimationKind = .smooth_scroll
}

const scroll_speed_in_pixels_per_second = 1000.0
const maximum_scroll_duration_in_seconds = 0.2
const momentum_distance_share_per_frame = 0.92
const momentum_frame_duration_in_seconds = 0.016
const maximum_momentum_duration_in_seconds = 5.0

fn momentum_frames_for_distance(distance f64) f64 {
	frames := math.ceil(-math.log(1.0 - distance * (1.0 - 1.0 / momentum_distance_share_per_frame)) / math.log(momentum_distance_share_per_frame))
	return math.min(frames, maximum_momentum_duration_in_seconds / momentum_frame_duration_in_seconds)
}

pub fn new_smooth_scroll_animation(start_offset painting.Point, destination_offset painting.Point, pixels_per_css_pixel f64, kind ScrollAnimationKind) !SmoothScrollAnimation {
	if pixels_per_css_pixel <= 0 || math.is_nan(pixels_per_css_pixel)
		|| math.is_inf(pixels_per_css_pixel, 0) {
		return error('pixels per CSS pixel must be finite and positive')
	}
	horizontal_distance := (destination_offset.x - start_offset.x) / pixels_per_css_pixel
	vertical_distance := (destination_offset.y - start_offset.y) / pixels_per_css_pixel
	distance := math.sqrt(horizontal_distance * horizontal_distance + vertical_distance * vertical_distance)
	duration := if kind == .momentum {
		momentum_frames_for_distance(distance) * momentum_frame_duration_in_seconds
	} else {
		math.min(distance / scroll_speed_in_pixels_per_second, maximum_scroll_duration_in_seconds)
	}
	return SmoothScrollAnimation{
		start_offset_: start_offset
		destination_offset_: destination_offset
		duration_seconds_: duration
		kind_: kind
	}
}

pub fn (animation SmoothScrollAnimation) duration() f64 {
	return animation.duration_seconds_
}

pub fn (animation SmoothScrollAnimation) sample(elapsed_seconds f64) SmoothScrollSample {
	if animation.duration_seconds_ == 0 || elapsed_seconds >= animation.duration_seconds_ {
		return SmoothScrollSample{
			offset: animation.destination_offset_
			complete: true
		}
	}
	progress := math.max(0.0, math.min(elapsed_seconds / animation.duration_seconds_, 1.0))
	eased_progress := if animation.kind_ == .momentum {
		frames := animation.duration_seconds_ / momentum_frame_duration_in_seconds
		frames_elapsed := progress * frames
		(1.0 - math.pow(momentum_distance_share_per_frame, frames_elapsed)) / (1.0 - math.pow(momentum_distance_share_per_frame, frames))
	} else {
		css.CubicBezierEasingFunction{
			x1: 0.42
			y1: 0
			x2: 0.58
			y2: 1
		}.evaluate_at(progress, false)
	}
	return SmoothScrollSample{
		offset: painting.Point{
			x: animation.start_offset_.x + (animation.destination_offset_.x - animation.start_offset_.x) * eased_progress
			y: animation.start_offset_.y + (animation.destination_offset_.y - animation.start_offset_.y) * eased_progress
		}
	}
}
