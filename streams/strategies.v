// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of QueuingStrategy, QueuingStrategyInit,
// ByteLengthQueuingStrategy, and CountQueuingStrategy.
module streams

import math

pub struct QueuingStrategy {
pub:
	high_water_mark ?f64
	size            ?SizeAlgorithm
}

pub struct QueuingStrategyInit {
pub:
	high_water_mark f64
}

pub fn extract_high_water_mark(strategy QueuingStrategy, default_hwm f64) !f64 {
	value := strategy.high_water_mark or { return default_hwm }
	if math.is_nan(value) || value < 0 {
		return error('RangeError: highWaterMark must be a non-negative number')
	}
	return value
}

pub fn extract_size_algorithm(strategy QueuingStrategy) SizeAlgorithm {
	return strategy.size or { default_size_algorithm }
}

pub struct ByteLengthQueuingStrategy {
	high_water_mark_ f64
}

pub fn ByteLengthQueuingStrategy.construct_impl(init QueuingStrategyInit) &ByteLengthQueuingStrategy {
	return &ByteLengthQueuingStrategy{
		high_water_mark_: init.high_water_mark
	}
}

pub fn (strategy &ByteLengthQueuingStrategy) high_water_mark() f64 {
	return strategy.high_water_mark_
}

pub fn (_ &ByteLengthQueuingStrategy) size(value Value) f64 {
	return f64(value.byte_length())
}

pub struct CountQueuingStrategy {
	high_water_mark_ f64
}

pub fn CountQueuingStrategy.construct_impl(init QueuingStrategyInit) &CountQueuingStrategy {
	return &CountQueuingStrategy{
		high_water_mark_: init.high_water_mark
	}
}

pub fn (strategy &CountQueuingStrategy) high_water_mark() f64 {
	return strategy.high_water_mark_
}

pub fn (_ &CountQueuingStrategy) size(_ Value) f64 {
	return 1.0
}
