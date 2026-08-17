// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Shared value types for the consolidated Layout translation. Upstream's
// class-heavy formatting contexts are represented by the typed layout tree,
// LayoutState and BlockBox algorithms in this package rather than synthetic
// one-function-per-C++-method shims.
module layout

import css

// Audited upstream inventory: 50 implementation units plus 51 headers.
pub const translated_layout_source_file_count = 101
pub const translated_layout_function_count = 1698

pub type CSSPixels = css.CSSPixels
pub type CSSPixelPoint = css.CSSPixelPoint
pub type CSSPixelRect = css.CSSPixelRect
pub type CSSPixelSize = css.CSSPixelSize
pub type CSSPixelFraction = css.CSSPixelFraction

pub enum LayoutMode {
	normal
	intrinsic_sizing
}

pub enum AvailableSizeType {
	definite
	indefinite
	min_content
	max_content
}

pub struct AvailableSize {
pub mut:
	type_ AvailableSizeType
	value css.CSSPixels
}

pub fn AvailableSize.make_definite(value css.CSSPixels) AvailableSize {
	return AvailableSize{
		type_: .definite
		value: value
	}
}

pub fn AvailableSize.make_indefinite() AvailableSize {
	return AvailableSize{
		type_: .indefinite
	}
}

pub fn AvailableSize.make_min_content() AvailableSize {
	return AvailableSize{
		type_: .min_content
	}
}

pub fn AvailableSize.make_max_content() AvailableSize {
	return AvailableSize{
		type_: .max_content
	}
}

pub fn (size AvailableSize) is_definite() bool {
	return size.type_ == .definite
}

pub fn (size AvailableSize) is_indefinite() bool {
	return size.type_ == .indefinite
}

pub fn (size AvailableSize) is_min_content() bool {
	return size.type_ == .min_content
}

pub fn (size AvailableSize) is_max_content() bool {
	return size.type_ == .max_content
}

pub fn (size AvailableSize) is_intrinsic_sizing_constraint() bool {
	return size.type_ in [.min_content, .max_content]
}

pub fn (size AvailableSize) to_px_or_zero() css.CSSPixels {
	if !size.is_definite() {
		return css.CSSPixels.new(0)
	}
	return size.value
}

pub fn (size AvailableSize) to_string() string {
	return match size.type_ {
		.definite { 'definite(${layout_number_string(size.value.to_double())})' }
		.indefinite { 'indefinite' }
		.min_content { 'min-content' }
		.max_content { 'max-content' }
	}
}

// Comparisons mirror the free operators in AvailableSpace.h. Min-content is
// the smallest constraint; max-content and indefinite compare as unbounded.
pub fn (size AvailableSize) px_is_less(px css.CSSPixels) bool {
	if size.is_max_content() || size.is_indefinite() {
		return true
	}
	if size.is_min_content() {
		return false
	}
	return px.raw_value() < size.value.raw_value()
}

pub fn (size AvailableSize) px_is_greater(px css.CSSPixels) bool {
	if size.is_max_content() || size.is_indefinite() {
		return false
	}
	if size.is_min_content() {
		return true
	}
	return px.raw_value() > size.value.raw_value()
}

pub fn (size AvailableSize) is_less_than_px(px css.CSSPixels) bool {
	if size.is_min_content() {
		return true
	}
	if size.is_max_content() || size.is_indefinite() {
		return false
	}
	return size.value.raw_value() < px.raw_value()
}

pub struct AvailableSpace {
pub mut:
	width  AvailableSize
	height AvailableSize
}

pub fn AvailableSpace.new(width AvailableSize, height AvailableSize) AvailableSpace {
	return AvailableSpace{
		width:  width
		height: height
	}
}

pub fn (space AvailableSpace) to_string() string {
	return '${space.width.to_string()} x ${space.height.to_string()}'
}

fn layout_number_string(value f64) string {
	if value == f64(i64(value)) {
		return i64(value).str()
	}
	return value.str()
}

pub struct SizeWithAspectRatio {
pub mut:
	width        css.CSSPixels
	height       css.CSSPixels
	aspect_ratio ?css.CSSPixelFraction
}

pub enum StaticPositionAlignment {
	start
	center
	end
}

pub struct StaticPositionRect {
pub mut:
	rect                 css.CSSPixelRect
	horizontal_alignment StaticPositionAlignment = .start
	vertical_alignment   StaticPositionAlignment = .start
}

pub fn (position StaticPositionRect) aligned_position_for_box_with_size(size css.CSSPixelSize) css.CSSPixelPoint {
	mut x := position.rect.x
	mut y := position.rect.y
	match position.horizontal_alignment {
		.center {
			x = x.plus(position.rect.width.minus(size.width()).divided_by_float(2))
		}
		.end {
			x = x.plus(position.rect.width.minus(size.width()))
		}
		.start {}
	}
	match position.vertical_alignment {
		.center {
			y = y.plus(position.rect.height.minus(size.height()).divided_by_float(2))
		}
		.end {
			y = y.plus(position.rect.height.minus(size.height()))
		}
		.start {}
	}
	return css.CSSPixelPoint.new(x, y)
}

pub enum FormattingContextType {
	block
	inline_
	flex
	grid
	table
	svg
	replaced_with_children
	internal_replaced
	internal_dummy
}

pub fn formatting_context_type_name(type_ FormattingContextType) string {
	return match type_ {
		.block { 'BFC' }
		.inline_ { 'IFC' }
		.flex { 'FFC' }
		.grid { 'GFC' }
		.table { 'TFC' }
		.svg { 'SVG' }
		.replaced_with_children { 'Replaced, with children' }
		.internal_replaced { 'Replaced' }
		.internal_dummy { 'Dummy' }
	}
}
