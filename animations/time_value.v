// Copyright (c) 2025-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/TimeValue.{h,cpp}.
module animations

pub enum TimeValueType {
	milliseconds
	percentage
}

pub struct PercentageValue {
pub:
	value f64
}

pub type CSSNumberish = PercentageValue | f64

// Web IDL represents the nullable CSSNumberish used by animation binding
// attributes as either null or a number/CSS numeric value. Keeping the
// nullable value in a small wrapper avoids losing the distinction when the
// value crosses the translated binding boundary.
pub struct NullableCSSNumberish {
pub:
	value ?CSSNumberish
}

fn optional_css_numberish(time ?TimeValue) ?CSSNumberish {
	if resolved := time {
		return resolved.as_css_numberish()
	}
	return none
}

pub fn NullableCSSNumberish.from_optional_css_numberish_time(time ?TimeValue) NullableCSSNumberish {
	return NullableCSSNumberish{
		value: optional_css_numberish(time)
	}
}

struct NullableTimeValue {
	value ?TimeValue
}

pub struct TimeValue {
pub:
	type_ TimeValueType
	value f64
}

pub fn TimeValue.milliseconds(value f64) TimeValue {
	return TimeValue{.milliseconds, value}
}

pub fn TimeValue.percentage(value f64) TimeValue {
	return TimeValue{.percentage, value}
}

pub fn TimeValue.from_css_numberish(value CSSNumberish) TimeValue {
	return match value {
		f64 { TimeValue.milliseconds(value) }
		PercentageValue { TimeValue.percentage(value.value) }
	}
}

pub fn TimeValue.zero_for_timeline(timeline ?&AnimationTimeline) TimeValue {
	if value := timeline {
		if value.is_progress_based() {
			return TimeValue.percentage(0)
		}
	}
	return TimeValue.milliseconds(0)
}

// Translation of TimeValue::create_zero().
pub fn TimeValue.create_zero(timeline ?&AnimationTimeline) TimeValue {
	return TimeValue.zero_for_timeline(timeline)
}

pub fn (time TimeValue) as_css_numberish() CSSNumberish {
	return match time.type_ {
		.milliseconds { CSSNumberish(time.value) }
		.percentage { CSSNumberish(PercentageValue{time.value}) }
	}
}

pub fn (time TimeValue) negate() TimeValue {
	return TimeValue{time.type_, -time.value}
}

pub fn (time TimeValue) multiply(factor f64) TimeValue {
	return TimeValue{time.type_, time.value * factor}
}

pub fn (time TimeValue) divide(divisor f64) TimeValue {
	return TimeValue{time.type_, time.value / divisor}
}

pub fn (time TimeValue) add(other TimeValue) !TimeValue {
	time.require_same_type(other)!
	return TimeValue{time.type_, time.value + other.value}
}

pub fn (time TimeValue) subtract(other TimeValue) !TimeValue {
	time.require_same_type(other)!
	return TimeValue{time.type_, time.value - other.value}
}

pub fn (time TimeValue) ratio(other TimeValue) !f64 {
	time.require_same_type(other)!
	return time.value / other.value
}

pub fn (time TimeValue) compare(other TimeValue) !int {
	time.require_same_type(other)!
	if time.value < other.value {
		return -1
	}
	if time.value > other.value {
		return 1
	}
	return 0
}

fn (time TimeValue) require_same_type(other TimeValue) ! {
	if time.type_ != other.type_ {
		return error('cannot combine time values with different units')
	}
}

pub fn (time TimeValue) str() string {
	return match time.type_ {
		.milliseconds { '${time.value}ms' }
		.percentage { '${time.value}%' }
	}
}

fn time_min(a TimeValue, b TimeValue) TimeValue {
	if a.type_ != b.type_ {
		panic('cannot compare time values with different units')
	}
	return if a.value <= b.value { a } else { b }
}

fn time_max(a TimeValue, b TimeValue) TimeValue {
	if a.type_ != b.type_ {
		panic('cannot compare time values with different units')
	}
	return if a.value >= b.value { a } else { b }
}
