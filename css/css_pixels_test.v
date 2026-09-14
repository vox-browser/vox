module css

import math

// Translation of Tests/LibWeb/TestCSSPixels.cpp. V does not overload arithmetic
// operators, so the corresponding named methods are used below.

fn test_css_pixels_addition1() {
	a := CSSPixels.new(10)
	b := CSSPixels.new(20)
	c := a.plus(b)
	assert c == CSSPixels.new(30)
}

fn test_css_pixels_subtraction1() {
	a := CSSPixels.new(30)
	b := CSSPixels.new(10)
	c := a.minus(b)
	assert c == CSSPixels.new(20)
}

fn test_css_pixels_division1() {
	a := CSSPixels.new(10)
	b := CSSPixels.new(5)
	c := a.divided_by(b).to_css_pixels()
	assert c == CSSPixels.new(2)
	large := CSSPixels.from_raw(0x3fff_ffff)
	quarter := CSSPixels.nearest_value_for(0.25)
	assert !large.might_be_saturated()
	assert large.divided_by(quarter).to_css_pixels().might_be_saturated()
}

fn test_css_pixels_multiplication1() {
	a := CSSPixels.new(3)
	b := CSSPixels.new(4)
	c := a.times(b)
	assert c == CSSPixels.new(12)
}

fn test_css_pixels_addition2() {
	mut a := CSSPixels.new(3)
	a = a.plus(CSSPixels.new(2))
	assert a == CSSPixels.new(5)
}

fn test_css_pixels_to_double() {
	a := CSSPixels.new(10)
	assert a.to_double() == 10.0
	assert a.to_float() == f32(10)
	assert a.to_int() == 10
}

fn test_css_pixels_comparison1() {
	assert CSSPixels.new(1).to_double() < CSSPixels.new(2).to_double()
}

fn test_css_pixels_comparison2() {
	assert CSSPixels.new(123) == CSSPixels.new(123)
}

fn test_css_pixels_multiplication_large_values() {
	a := CSSPixels.new(1200)
	b := CSSPixels.new(647)
	c := a.times(b)
	assert c == CSSPixels.new(776400)
}

fn test_css_pixels_nearest_value_for() {
	assert CSSPixels.nearest_value_for(2.0) == CSSPixels.new(2)
	assert CSSPixels.nearest_value_for(0.0) == CSSPixels.new(0)
}

fn test_css_pixels_float_conversion() {
	value := 620.0 * 0.333333
	assert CSSPixels.nearest_value_for(value) == CSSPixels.from_raw(13227)
	assert CSSPixels.floored_value_for(value) == CSSPixels.from_raw(13226)
	assert CSSPixels.truncated_value_for(value) == CSSPixels.from_raw(13226)

	assert CSSPixels.floored_value_for(-value) == CSSPixels.from_raw(-13227)
	assert CSSPixels.truncated_value_for(-value) == CSSPixels.from_raw(-13226)

	assert CSSPixels.truncated_value_for(math.inf(1)) == CSSPixels.max()
	assert CSSPixels.truncated_value_for(math.inf(-1)) == CSSPixels.min()
}

fn test_css_pixels_saturating_arithmetic() {
	assert CSSPixels.max().plus(CSSPixels.new(1)) == CSSPixels.max()
	assert CSSPixels.min().minus(CSSPixels.new(1)) == CSSPixels.min()
}

fn test_css_pixels_saturated_abs() {
	assert CSSPixels.min().abs() == CSSPixels.max()
	assert CSSPixels.from_raw(-5).abs() == CSSPixels.from_raw(5)
	assert CSSPixels.from_raw(5).abs() == CSSPixels.from_raw(5)
}

fn test_css_pixels_floor_ceil_round() {
	assert css_pixels_ceil(CSSPixels.nearest_value_for(0.5)) == CSSPixels.new(1)
	assert css_pixels_ceil(CSSPixels.nearest_value_for(-1.7)) == CSSPixels.new(-1)
	assert css_pixels_floor(CSSPixels.nearest_value_for(1.7)) == CSSPixels.new(1)
	assert css_pixels_floor(CSSPixels.nearest_value_for(-1.3)) == CSSPixels.new(-2)
	assert css_pixels_round(CSSPixels.nearest_value_for(1.5)) == CSSPixels.new(2)
	assert css_pixels_round(CSSPixels.nearest_value_for(-1.5)) == CSSPixels.new(-2)
}
