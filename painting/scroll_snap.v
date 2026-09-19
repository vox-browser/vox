// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause
module painting

import math

const maximum_momentum_decay_share = 0.96
const maximum_slow_momentum_decay_share = 0.99
const decaying_deltas_before_slow_decay_is_predicted_from = u32(3)

// Estimates the displacement a momentum flick still has to travel from the
// deltas it has produced so far. CSS pixel values use Ladybird's 1/64-pixel
// quantum when the estimate is returned.
pub struct MomentumFlingEstimator {
mut:
	previous_momentum_delta                ?Point
	consecutively_decaying_momentum_deltas u32
}

pub fn (mut estimator MomentumFlingEstimator) reset() {
	estimator.previous_momentum_delta = none
	estimator.consecutively_decaying_momentum_deltas = 0
}

fn nearest_css_pixel_value(value f64) f64 {
	return math.round(value * 64.0) / 64.0
}

pub fn (mut estimator MomentumFlingEstimator) estimate_remaining_displacement(momentum_delta Point) ?Point {
	previous := estimator.previous_momentum_delta
	estimator.previous_momentum_delta = momentum_delta
	previous_delta := previous or { return none }
	distance := math.hypot(momentum_delta.x, momentum_delta.y)
	previous_distance := math.hypot(previous_delta.x, previous_delta.y)
	if previous_distance <= 0 {
		return none
	}
	decay_share := distance / previous_distance
	if decay_share < 1 {
		estimator.consecutively_decaying_momentum_deltas++
	} else {
		estimator.consecutively_decaying_momentum_deltas = 0
	}
	momentum_is_decaying := decay_share < maximum_momentum_decay_share
		|| (estimator.consecutively_decaying_momentum_deltas >= decaying_deltas_before_slow_decay_is_predicted_from
			&& decay_share < 1)
	if !momentum_is_decaying {
		return none
	}
	remaining_distance_factor := 1.0 / (1.0 - math.min(decay_share, maximum_slow_momentum_decay_share))
	return Point{
		x: nearest_css_pixel_value(momentum_delta.x * remaining_distance_factor)
		y: nearest_css_pixel_value(momentum_delta.y * remaining_distance_factor)
	}
}
