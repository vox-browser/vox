// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub enum Predictor {
	zero
	west
	north
	average_west_north
	select
	gradient
	weighted
	north_east
	north_west
	west_west
	average_west_north_west
	average_north_north_west
	average_north_north_east
	average_all
}

pub fn predictor_from_id(id u32) !Predictor {
	if id >= 14 { return error('Invalid JPEG XL predictor') }
	return unsafe { Predictor(id) }
}

pub fn (p Predictor) requires_full_row() bool {
	return p in [.weighted, .north_east, .average_north_north_east, .average_all]
}

pub struct PredictionData {
pub:
	left          i32
	top           i32
	toptop        i32
	topleft       i32
	topright      i32
	leftleft      i32
	toprightright i32
}

// Border substitutions are part of the modular prediction format.
pub fn PredictionData.from_rows(row []i32, row_top []i32, row_toptop []i32, x int, y int) !PredictionData {
	if x < 0 || x >= row.len || y < 0 || (y > 0 && row_top.len < row.len)
		|| (y > 1 && row_toptop.len < row.len) {
		return error('Invalid JPEG XL prediction rows')
	}
	left := if x > 0 {
		row[x - 1]
	} else if y > 0 {
		row_top[0]
	} else {
		i32(0)
	}
	top := if y > 0 { row_top[x] } else { left }
	topleft := if x > 0 && y > 0 { row_top[x - 1] } else { left }
	topright := if x + 1 < row.len && y > 0 { row_top[x + 1] } else { top }
	return PredictionData{
		left:          left
		top:           top
		toptop:        if y > 1 { row_toptop[x] } else { top }
		topleft:       topleft
		topright:      topright
		leftleft:      if x > 1 { row[x - 2] } else { left }
		toprightright: if x + 2 < row.len && y > 0 { row_top[x + 2] } else { topright }
	}
}

pub fn (d PredictionData) update_for_interior_row(row_top []i32, row_toptop []i32, x int, current i32, needs_toptop bool) !PredictionData {
	if x <= 1 || x + 2 >= row_top.len || (needs_toptop && x >= row_toptop.len) {
		return error('Invalid JPEG XL interior prediction row')
	}
	return PredictionData{
		left:          current
		top:           d.topright
		toptop:        if needs_toptop { row_toptop[x] } else { i32(0) }
		topleft:       d.top
		topright:      d.toprightright
		leftleft:      d.left
		toprightright: row_top[x + 2]
	}
}

pub fn clamped_gradient(left i64, top i64, topleft i64) i64 {
	low := math.min(left, top)
	high := math.max(left, top)
	if topleft < low { return high }
	if topleft > high { return low }
	return left + top - topleft
}

pub fn (p Predictor) predict_one(d PredictionData, weighted_prediction i64) i64 {
	left := i64(d.left)
	top := i64(d.top)
	topleft := i64(d.topleft)
	return match p {
		.zero { i64(0) }
		.west { left }
		.north { top }
		.average_west_north { (left + top) / 2 }
		.select {
			gradient := left + top - topleft
			if math.abs(gradient - left) < math.abs(gradient - top) { left } else { top }
		}
		.gradient { clamped_gradient(left, top, topleft) }
		.weighted { weighted_prediction }
		.north_east { i64(d.topright) }
		.north_west { topleft }
		.west_west { i64(d.leftleft) }
		.average_west_north_west { (left + topleft) / 2 }
		.average_north_north_west { (top + topleft) / 2 }
		.average_north_north_east { (top + i64(d.topright)) / 2 }
		.average_all {
			(6 * top - 2 * i64(d.toptop) + 7 * left + i64(d.leftleft) + i64(d.toprightright) +
				3 * i64(d.topright) + 8) / 16
		}
	}
}
