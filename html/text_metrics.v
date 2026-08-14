// Copyright (c) 2021, sin-ack <sin-ack@protonmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/TextMetrics.cpp (and the inline getters/setters
// in TextMetrics.h). A plain data holder populated by CanvasRenderingContext2D::measure_text.
module html

@[heap]
pub struct TextMetrics {
mut:
	width_                       f64
	actual_bounding_box_left_    f64
	actual_bounding_box_right_   f64
	font_bounding_box_ascent_    f64
	font_bounding_box_descent_   f64
	actual_bounding_box_ascent_  f64
	actual_bounding_box_descent_ f64
	em_height_ascent_            f64
	em_height_descent_           f64
	hanging_baseline_            f64
	alphabetic_baseline_         f64
	ideographic_baseline_        f64
}

pub fn TextMetrics.create() &TextMetrics {
	return &TextMetrics{}
}

pub fn (t &TextMetrics) width() f64 {
	return t.width_
}

pub fn (t &TextMetrics) actual_bounding_box_left() f64 {
	return t.actual_bounding_box_left_
}

pub fn (t &TextMetrics) actual_bounding_box_right() f64 {
	return t.actual_bounding_box_right_
}

pub fn (t &TextMetrics) font_bounding_box_ascent() f64 {
	return t.font_bounding_box_ascent_
}

pub fn (t &TextMetrics) font_bounding_box_descent() f64 {
	return t.font_bounding_box_descent_
}

pub fn (t &TextMetrics) actual_bounding_box_ascent() f64 {
	return t.actual_bounding_box_ascent_
}

pub fn (t &TextMetrics) actual_bounding_box_descent() f64 {
	return t.actual_bounding_box_descent_
}

pub fn (t &TextMetrics) em_height_ascent() f64 {
	return t.em_height_ascent_
}

pub fn (t &TextMetrics) em_height_descent() f64 {
	return t.em_height_descent_
}

pub fn (t &TextMetrics) hanging_baseline() f64 {
	return t.hanging_baseline_
}

pub fn (t &TextMetrics) alphabetic_baseline() f64 {
	return t.alphabetic_baseline_
}

pub fn (t &TextMetrics) ideographic_baseline() f64 {
	return t.ideographic_baseline_
}

pub fn (mut t TextMetrics) set_width(width f64) {
	t.width_ = width
}

pub fn (mut t TextMetrics) set_actual_bounding_box_left(left f64) {
	t.actual_bounding_box_left_ = left
}

pub fn (mut t TextMetrics) set_actual_bounding_box_right(right f64) {
	t.actual_bounding_box_right_ = right
}

pub fn (mut t TextMetrics) set_font_bounding_box_ascent(ascent f64) {
	t.font_bounding_box_ascent_ = ascent
}

pub fn (mut t TextMetrics) set_font_bounding_box_descent(descent f64) {
	t.font_bounding_box_descent_ = descent
}

pub fn (mut t TextMetrics) set_actual_bounding_box_ascent(ascent f64) {
	t.actual_bounding_box_ascent_ = ascent
}

pub fn (mut t TextMetrics) set_actual_bounding_box_descent(descent f64) {
	t.actual_bounding_box_descent_ = descent
}

pub fn (mut t TextMetrics) set_em_height_ascent(ascent f64) {
	t.em_height_ascent_ = ascent
}

pub fn (mut t TextMetrics) set_em_height_descent(descent f64) {
	t.em_height_descent_ = descent
}

pub fn (mut t TextMetrics) set_hanging_baseline(baseline f64) {
	t.hanging_baseline_ = baseline
}

pub fn (mut t TextMetrics) set_alphabetic_baseline(baseline f64) {
	t.alphabetic_baseline_ = baseline
}

pub fn (mut t TextMetrics) set_ideographic_baseline(baseline f64) {
	t.ideographic_baseline_ = baseline
}
