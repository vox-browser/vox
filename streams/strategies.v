// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of QueuingStrategy, QueuingStrategyInit,
// ByteLengthQueuingStrategy, and CountQueuingStrategy.
module streams

import math
import webidl

pub struct QueuingStrategy {
pub:
	high_water_mark ?f64
	size            ?SizeAlgorithm
	size_value      ?ValueSizeAlgorithm
}

pub struct QueuingStrategyInit {
pub:
	high_water_mark f64
}

// HTML relevant_window_or_worker_global_scope supplies retained builtin
// CallbackType records without introducing a Streams -> HTML import cycle.
pub interface QueuingStrategyGlobalScope {
mut:
	count_queuing_strategy_size_callback() !&webidl.CallbackType
	byte_length_queuing_strategy_size_callback() !&webidl.CallbackType
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

// BindingsGlue.h keeps callback invocation out of the Streams implementation.
// The typed V boundary preserves the same abrupt-completion result.
pub fn invoke_queuing_strategy_size_callback(callback SizeAlgorithm, chunk Value) !f64 {
	return callback(chunk)
}

fn invoke_size_value_algorithm(scalar SizeAlgorithm, actual ?ValueSizeAlgorithm, chunk Value) !webidl.Value {
	if callback := actual { return callback(chunk) }
	return webidl.number_value(scalar(chunk)!)
}

pub struct ByteLengthQueuingStrategy {
	high_water_mark_ f64
}

pub fn ByteLengthQueuingStrategy.create(high_water_mark f64) &ByteLengthQueuingStrategy {
	return &ByteLengthQueuingStrategy{
		high_water_mark_: high_water_mark
	}
}

pub fn ByteLengthQueuingStrategy.create_for_constructor(init QueuingStrategyInit) &ByteLengthQueuingStrategy {
	return ByteLengthQueuingStrategy.create(init.high_water_mark)
}

pub fn ByteLengthQueuingStrategy.construct_impl(init QueuingStrategyInit) &ByteLengthQueuingStrategy {
	return ByteLengthQueuingStrategy.create_for_constructor(init)
}

pub fn (strategy &ByteLengthQueuingStrategy) high_water_mark() f64 {
	return strategy.high_water_mark_
}

// ByteLengthQueuingStrategy.cpp::size returns the relevant global's cached
// function. It does not read/coerce a chunk at this getter.
pub fn (_ &ByteLengthQueuingStrategy) size_callback(mut global QueuingStrategyGlobalScope) !&webidl.CallbackType {
	return global.byte_length_queuing_strategy_size_callback()
}

// Compatibility adapter for existing standalone typed-byte callers.
pub fn (_ &ByteLengthQueuingStrategy) size(value Value) f64 {
	return f64(value.byte_length())
}

pub struct CountQueuingStrategy {
	high_water_mark_ f64
}

pub fn CountQueuingStrategy.create(high_water_mark f64) &CountQueuingStrategy {
	return &CountQueuingStrategy{
		high_water_mark_: high_water_mark
	}
}

pub fn CountQueuingStrategy.create_for_constructor(init QueuingStrategyInit) &CountQueuingStrategy {
	return CountQueuingStrategy.create(init.high_water_mark)
}

pub fn CountQueuingStrategy.construct_impl(init QueuingStrategyInit) &CountQueuingStrategy {
	return CountQueuingStrategy.create_for_constructor(init)
}

pub fn (strategy &CountQueuingStrategy) high_water_mark() f64 {
	return strategy.high_water_mark_
}

pub fn (_ &CountQueuingStrategy) size_callback(mut global QueuingStrategyGlobalScope) !&webidl.CallbackType {
	return global.count_queuing_strategy_size_callback()
}

// Compatibility adapter for existing standalone scalar callers.
pub fn (_ &CountQueuingStrategy) size(_ Value) f64 {
	return 1.0
}
