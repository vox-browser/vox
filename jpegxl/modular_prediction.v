// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn modular_wrapping_abs(value i32) i32 {
	return if value < 0 { i32(-i64(value)) } else { value }
}

// The caller keeps static properties 0/1 and resets property 9 at each row.
// References are the current pixel's already prepared prior-channel properties.
pub fn compute_modular_properties(data PredictionData, x int, y int, references []i32, weighted WeightedPrediction, mut properties []i32) ! {
	if properties.len < 16 || properties.len > 256 || references.len > properties.len - 16
		|| x < 0 || y < 0 {
		return error('Invalid JPEG XL modular prediction properties')
	}
	properties[2] = i32(y)
	properties[3] = i32(x)
	properties[4] = modular_wrapping_abs(data.top)
	properties[5] = modular_wrapping_abs(data.left)
	properties[6] = data.top
	properties[7] = data.left
	properties[8] = i32(i64(data.left) - i64(properties[9]))
	properties[9] = i32(i64(data.left) + i64(data.top) - i64(data.topleft))
	properties[10] = i32(i64(data.left) - i64(data.topleft))
	properties[11] = i32(i64(data.topleft) - i64(data.top))
	properties[12] = i32(i64(data.top) - i64(data.topright))
	properties[13] = i32(i64(data.top) - i64(data.toptop))
	properties[14] = i32(i64(data.left) - i64(data.leftleft))
	properties[15] = weighted.property
	copy(mut properties[16..16 + references.len], references)
}

// Only the low 32 bits survive the source's release arithmetic and final cast.
pub fn make_modular_pixel(residual i32, multiplier u32, guess i64) i32 {
	return i32(u32(u64(u32(guess)) + u64(multiplier) * u64(u32(residual))))
}

pub struct ModularPrediction {
pub:
	guess      i64
	multiplier u32
	context    u32
}

pub fn (tree ModularTree) predict_modular(data PredictionData, weighted_prediction i64, properties []i32) !ModularPrediction {
	leaf := tree.walk(properties)!
	guess := leaf.predictor.predict_one(data, weighted_prediction)
	return ModularPrediction{
		guess:      i64(u64(guess) + u64(i64(leaf.offset)))
		multiplier: leaf.multiplier
		context:    leaf.context
	}
}
