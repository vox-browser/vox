// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct WeightedPrediction {
pub:
	value    i64
	property i32
}

pub struct WeightedPredictorState {
	width int
	w     [4]u32
	p1c   u32
	p2c   u32
	p3c   [5]u32
mut:
	prediction       [4]i64
	pred             i64
	predictor_errors [][4]u32
	errors           []i32
}

// The source persists the first error-buffer row between palette chunks.
pub struct WeightedPredictorRows {
	width            int
	predictor_errors [][4]u32
	errors           []i32
}

pub fn WeightedPredictorState.new(header WeightedPredictorHeader, width int) !WeightedPredictorState {
	if width <= 0 || width > 1048576 {
		return error('Invalid JPEG XL weighted predictor width')
	}
	if header.p1c > 31 || header.p2c > 31 || header.p3ca > 31 || header.p3cb > 31
		|| header.p3cc > 31 || header.p3cd > 31 || header.p3ce > 31
		|| header.w0 > 15 || header.w1 > 15 || header.w2 > 15 || header.w3 > 15 {
		return error('Invalid JPEG XL weighted predictor coefficients')
	}
	return WeightedPredictorState{
		width:            width
		w:                [header.w0, header.w1, header.w2, header.w3]!
		p1c:              header.p1c
		p2c:              header.p2c
		p3c:              [header.p3ca, header.p3cb, header.p3cc, header.p3cd, header.p3ce]!
		predictor_errors: [][4]u32{len: (width + 1) * 2}
		errors:           []i32{len: (width + 1) * 2}
	}
}

pub fn (state &WeightedPredictorState) save_rows() WeightedPredictorRows {
	return WeightedPredictorRows{
		width:            state.width
		predictor_errors: state.predictor_errors[..state.width + 1].clone()
		errors:           state.errors[..state.width + 1].clone()
	}
}

pub fn (mut state WeightedPredictorState) restore_rows(rows WeightedPredictorRows) ! {
	if rows.width != state.width || rows.errors.len != state.width + 1
		|| rows.predictor_errors.len != state.width + 1 {
		return error('Incompatible JPEG XL weighted predictor rows')
	}
	copy(mut state.errors[..state.width + 1], rows.errors)
	copy(mut state.predictor_errors[..state.width + 1], rows.predictor_errors)
}

fn predictor_floor_log2(value u64) int {
	mut bits := 0
	mut v := value
	for v > 1 {
		v >>= 1
		bits++
	}
	return bits
}

// Exact integer lookup from the source: floor(2^24 / (index + 1)).
fn predictor_divisor(index u32) u32 {
	return u32(16777216 / (index + 1))
}

pub fn (mut state WeightedPredictorState) predict_and_property(x int, y int, data PredictionData) !WeightedPrediction {
	if x < 0 || x >= state.width || y < 0 {
		return error('Invalid JPEG XL weighted predictor position')
	}
	stride := state.width + 1
	current := if y & 1 != 0 { 0 } else { stride }
	previous := if y & 1 != 0 { stride } else { 0 }
	north_east := math.min(x + 1, state.width - 1)
	north_west := math.max(x - 1, 0)
	mut weights := [4]i64{}
	for i in 0 .. 4 {
		error_sum := u32(u64(state.predictor_errors[previous + x][i]) +
			u64(state.predictor_errors[previous + north_east][i]) +
			u64(state.predictor_errors[previous + north_west][i]))
		shift := math.max(0, predictor_floor_log2(u64(error_sum) + 1) - 5)
		weights[i] = i64(4 + ((state.w[i] * predictor_divisor(error_sum >> shift)) >> shift))
	}
	west_error := i64(state.errors[current + x])
	north_error := i64(state.errors[previous + 1 + x])
	north_west_error := i64(state.errors[previous + 1 + north_west])
	north_east_error := i64(state.errors[previous + 1 + north_east])
	mut property := west_error
	for candidate in [north_error, north_west_error, north_east_error] {
		if math.abs(candidate) > math.abs(property) { property = candidate }
	}
	north := i64(data.top) * 8
	west := i64(data.left) * 8
	north_east_value := i64(data.topright) * 8
	north_west_value := i64(data.topleft) * 8
	north_north := i64(data.toptop) * 8
	sum_wn := north_error + west_error
	p0 := west + north_east_value - north
	p1 := north - (((sum_wn + north_east_error) * i64(state.p1c)) >> 5)
	p2 := west - (((sum_wn + north_west_error) * i64(state.p2c)) >> 5)
	p3 := north - ((north_west_error * i64(state.p3c[0]) + north_error * i64(state.p3c[1]) +
		north_east_error * i64(state.p3c[2]) + (north_north - north) * i64(state.p3c[3]) +
		(north_west_value - west) * i64(state.p3c[4])) >> 5)
	shift := predictor_floor_log2(u64(weights[0] + weights[1] + weights[2] + weights[3])) - 4
	for i in 0 .. 4 { weights[i] >>= shift }
	weight_sum := weights[0] + weights[1] + weights[2] + weights[3]
	sum := (weight_sum >> 1) - 1 + weights[0] * p0 + weights[1] * p1 + weights[2] * p2 + weights[3] * p3
	// The release source wraps this product for extreme signed 32-bit samples.
	mut prediction := i64(u64(sum) * u64(predictor_divisor(u32(weight_sum - 1)))) >> 24
	if ((north_error ^ west_error) | (north_error ^ north_west_error)) <= 0 {
		prediction = math.max(math.min(west, math.min(north_east_value, north)),
			math.min(math.max(west, math.max(north_east_value, north)), prediction))
	}
	state.prediction = [p0, p1, p2, p3]!
	state.pred = prediction
	return WeightedPrediction{ value: (prediction + 3) >> 3, property: i32(property) }
}

pub fn (mut state WeightedPredictorState) update_errors(correct i32, x int, y int) ! {
	if x < 0 || x >= state.width || y < 0 {
		return error('Invalid JPEG XL weighted predictor position')
	}
	stride := state.width + 1
	current := if y & 1 != 0 { 0 } else { stride }
	previous := if y & 1 != 0 { stride } else { 0 }
	value := i64(correct) * 8
	state.errors[current + x + 1] = i32(state.pred - value)
	for i in 0 .. 4 {
		err := u32((math.abs(state.prediction[i] - value) + 3) >> 3)
		state.predictor_errors[current + x][i] = err
		state.predictor_errors[previous + x + 1][i] = u32(u64(state.predictor_errors[previous + x + 1][i]) + u64(err))
	}
}
