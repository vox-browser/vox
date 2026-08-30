// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Explicit state-bearing forms of the Canvas CRTP mixins. The public canvas
// contexts expose the WebIDL operations directly; these records preserve the
// header-only mixin contracts and keep their shared-state semantics testable.
module html

import math

@[heap]
pub struct CanvasPathDrawingStyles {
mut:
	state &CanvasState
}

pub fn CanvasPathDrawingStyles.create(state &CanvasState) &CanvasPathDrawingStyles {
	return &CanvasPathDrawingStyles{state: state}
}

fn (styles &CanvasPathDrawingStyles) my_drawing_state() &DrawingState {
	return &styles.state.drawing_state
}

pub fn (mut styles CanvasPathDrawingStyles) set_line_width(line_width f64) {
	if line_width > 0 && is_finite(line_width) {
		styles.state.drawing_state.line_width = line_width
	}
}

pub fn (styles &CanvasPathDrawingStyles) line_width() f64 {
	return styles.my_drawing_state().line_width
}

pub fn (mut styles CanvasPathDrawingStyles) set_line_cap(line_cap CanvasLineCap) {
	styles.state.drawing_state.line_cap = line_cap
}

pub fn (styles &CanvasPathDrawingStyles) line_cap() CanvasLineCap {
	return styles.my_drawing_state().line_cap
}

pub fn (mut styles CanvasPathDrawingStyles) set_line_join(line_join CanvasLineJoin) {
	styles.state.drawing_state.line_join = line_join
}

pub fn (styles &CanvasPathDrawingStyles) line_join() CanvasLineJoin {
	return styles.my_drawing_state().line_join
}

pub fn (mut styles CanvasPathDrawingStyles) set_miter_limit(miter_limit f64) {
	if miter_limit > 0 && is_finite(miter_limit) {
		styles.state.drawing_state.miter_limit = miter_limit
	}
}

pub fn (styles &CanvasPathDrawingStyles) miter_limit() f64 {
	return styles.my_drawing_state().miter_limit
}

pub fn (mut styles CanvasPathDrawingStyles) set_line_dash(segments []f64) {
	if segments.any(!is_finite(it) || it < 0) {
		return
	}
	mut normalized := segments.clone()
	if normalized.len % 2 == 1 {
		normalized << segments
	}
	styles.state.drawing_state.dash_list = normalized
}

pub fn (styles &CanvasPathDrawingStyles) get_line_dash() []f64 {
	return styles.my_drawing_state().dash_list.clone()
}

pub fn (mut styles CanvasPathDrawingStyles) set_line_dash_offset(line_dash_offset f64) {
	if is_finite(line_dash_offset) {
		styles.state.drawing_state.line_dash_offset = line_dash_offset
	}
}

pub fn (styles &CanvasPathDrawingStyles) line_dash_offset() f64 {
	return styles.my_drawing_state().line_dash_offset
}

@[heap]
pub struct CanvasShadowStyles {
mut:
	state &CanvasState
}

pub fn CanvasShadowStyles.create(state &CanvasState) &CanvasShadowStyles {
	return &CanvasShadowStyles{state: state}
}

fn (styles &CanvasShadowStyles) my_drawing_state() &DrawingState {
	return &styles.state.drawing_state
}

@[heap]
pub struct CanvasTransform {
mut:
	state &CanvasState
	path  &CanvasPath
}

pub fn CanvasTransform.create(state &CanvasState, path &CanvasPath) &CanvasTransform {
	return &CanvasTransform{state: state, path: path}
}

pub fn (mut transform CanvasTransform) mutable_path() &CanvasGfxPath {
	mut path := transform.path
	return path.mutable_path_storage()
}

fn (transform &CanvasTransform) my_drawing_state() &DrawingState {
	return &transform.state.drawing_state
}

fn (mut transform CanvasTransform) apply_transform(matrix CanvasAffineTransform) {
	transform.state.drawing_state.transform = canvas_transform_multiply(
		transform.state.drawing_state.transform, matrix)
	if inverse := matrix.inverse() {
		mut path := transform.path
		path.path_ = path.path_.copy_transformed(inverse)
	}
	transform.flush_transform()
}

pub fn (mut transform CanvasTransform) scale(sx f64, sy f64) {
	if !is_finite(sx) || !is_finite(sy) {
		return
	}
	transform.apply_transform(CanvasAffineTransform{a: sx, d: sy})
}

pub fn (mut transform CanvasTransform) translate(tx f64, ty f64) {
	if !is_finite(tx) || !is_finite(ty) {
		return
	}
	transform.apply_transform(CanvasAffineTransform{e: tx, f: ty})
}

pub fn (mut transform CanvasTransform) rotate(radians f64) {
	if !is_finite(radians) {
		return
	}
	sine := math.sin(radians)
	cosine := math.cos(radians)
	transform.apply_transform(CanvasAffineTransform{a: cosine, b: sine, c: -sine, d: cosine})
}

pub fn (mut transform CanvasTransform) transform(matrix CanvasAffineTransform) {
	if [matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f].all(is_finite(it)) {
		transform.apply_transform(matrix)
	}
}

pub fn (transform &CanvasTransform) get_transform() CanvasAffineTransform {
	return transform.my_drawing_state().transform
}

pub fn (mut transform CanvasTransform) set_transform(matrix CanvasAffineTransform) {
	if ![matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f].all(is_finite(it)) {
		return
	}
	original := transform.state.drawing_state.transform
	transform.state.drawing_state.transform = matrix
	mut path := transform.path
	path.path_ = path.path_.copy_transformed(original)
	transform.flush_transform()
}

pub fn (mut transform CanvasTransform) reset_transform() {
	transform.state.drawing_state.transform = CanvasAffineTransform{}
	transform.flush_transform()
}

pub fn (transform &CanvasTransform) flush_transform() {
	// Painter state is supplied by the embedding context. The shared drawing
	// state remains authoritative when no host painter is installed.
	_ = transform
}
