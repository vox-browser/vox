// Copyright (c) 2020-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/Geometry/DOMRectReadOnly.cpp and
// DOMRect.cpp — an axis-aligned rectangle (x, y, width, height) with a read-only base and a mutable
// subclass. The top/right/bottom/left edges are derived, using min/max so that negative widths and
// heights are handled, and returning NaN when the relevant inputs are NaN (coordinates are
// `unrestricted double`). Typed structured-clone records are in serialization.v. As with DOMPoint,
// V has no default arguments, so the IDL defaults (all 0) live
// on the DOMRectInit dictionary used by fromRect and the constructors take explicit values.
//
// NOTE: dom.DOMRect is a separate minimal value-struct used by the CSSOM-view bounding-rect path; this
// is the full Geometry DOMRect interface.
// https://drafts.fxtf.org/geometry/#domrectreadonly
module geometry

import math

// https://drafts.fxtf.org/geometry/#dictdef-domrectinit
pub struct DOMRectInit {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
}

// https://drafts.fxtf.org/geometry/#domrectreadonly
@[heap]
pub struct DOMRectReadOnly {
mut:
	x_      f64
	y_      f64
	width_  f64
	height_ f64
}

// The DOMRectReadOnly(x, y, width, height) constructor.
pub fn DOMRectReadOnly.construct(x f64, y f64, width f64, height f64) &DOMRectReadOnly {
	return &DOMRectReadOnly{
		x_: x
		y_: y
		width_: width
		height_: height
	}
}

pub fn DOMRectReadOnly.construct_impl(x f64, y f64, width f64, height f64) &DOMRectReadOnly {
	return DOMRectReadOnly.construct(x, y, width, height)
}

// DOMRectReadOnly::create(realm) — the empty rectangle (all coordinates 0).
pub fn DOMRectReadOnly.create() &DOMRectReadOnly {
	return &DOMRectReadOnly{}
}

// https://drafts.fxtf.org/geometry/#create-a-domrect-from-the-dictionary
pub fn DOMRectReadOnly.from_rect(other DOMRectInit) &DOMRectReadOnly {
	return DOMRectReadOnly.dom_rect_read_only_from_rect(other)
}

pub fn DOMRectReadOnly.dom_rect_read_only_from_rect(other DOMRectInit) &DOMRectReadOnly {
	return DOMRectReadOnly.construct(other.x, other.y, other.width, other.height)
}

pub fn (rect &DOMRectReadOnly) x() f64 {
	return rect.x_
}

pub fn (rect &DOMRectReadOnly) y() f64 {
	return rect.y_
}

pub fn (rect &DOMRectReadOnly) width() f64 {
	return rect.width_
}

pub fn (rect &DOMRectReadOnly) height() f64 {
	return rect.height_
}

// https://drafts.fxtf.org/geometry/#dom-domrectreadonly-top — min(y, y + height).
pub fn (rect &DOMRectReadOnly) top() f64 {
	if math.is_nan(rect.y_) || math.is_nan(rect.height_) {
		return math.nan()
	}
	other_edge := rect.y_ + rect.height_
	return if other_edge < rect.y_ { other_edge } else { rect.y_ }
}

// https://drafts.fxtf.org/geometry/#dom-domrectreadonly-right — max(x, x + width).
pub fn (rect &DOMRectReadOnly) right() f64 {
	if math.is_nan(rect.x_) || math.is_nan(rect.width_) {
		return math.nan()
	}
	other_edge := rect.x_ + rect.width_
	return if rect.x_ < other_edge { other_edge } else { rect.x_ }
}

// https://drafts.fxtf.org/geometry/#dom-domrectreadonly-bottom — max(y, y + height).
pub fn (rect &DOMRectReadOnly) bottom() f64 {
	if math.is_nan(rect.y_) || math.is_nan(rect.height_) {
		return math.nan()
	}
	other_edge := rect.y_ + rect.height_
	return if rect.y_ < other_edge { other_edge } else { rect.y_ }
}

// https://drafts.fxtf.org/geometry/#dom-domrectreadonly-left — min(x, x + width).
pub fn (rect &DOMRectReadOnly) left() f64 {
	if math.is_nan(rect.x_) || math.is_nan(rect.width_) {
		return math.nan()
	}
	other_edge := rect.x_ + rect.width_
	return if other_edge < rect.x_ { other_edge } else { rect.x_ }
}

// https://drafts.fxtf.org/geometry/#domrect — DOMRect : DOMRectReadOnly, adding writable coordinates.
@[heap]
pub struct DOMRect {
	DOMRectReadOnly
}

// The DOMRect(x, y, width, height) constructor.
pub fn DOMRect.construct(x f64, y f64, width f64, height f64) &DOMRect {
	return &DOMRect{
		DOMRectReadOnly: DOMRectReadOnly{
			x_: x
			y_: y
			width_: width
			height_: height
		}
	}
}

// DOMRect::create(realm) — the empty rectangle.
pub fn DOMRect.create() &DOMRect {
	return &DOMRect{}
}

// Typed view for IDL inheritance; writable and readonly getters share storage.
pub fn (rect &DOMRect) as_read_only() &DOMRectReadOnly {
	return &rect.DOMRectReadOnly
}

// https://drafts.fxtf.org/geometry/#create-a-domrect-from-the-dictionary
pub fn DOMRect.from_rect(other DOMRectInit) &DOMRect {
	return DOMRect.dom_rect_from_rect(other)
}

pub fn DOMRect.dom_rect_from_rect(other DOMRectInit) &DOMRect {
	return DOMRect.construct(other.x, other.y, other.width, other.height)
}

pub fn (mut rect DOMRect) set_x(x f64) {
	rect.x_ = x
}

pub fn (mut rect DOMRect) set_y(y f64) {
	rect.y_ = y
}

pub fn (mut rect DOMRect) set_width(width f64) {
	rect.width_ = width
}

pub fn (mut rect DOMRect) set_height(height f64) {
	rect.height_ = height
}
