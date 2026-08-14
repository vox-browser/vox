// Copyright (c) 2020-2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Canvas/CanvasState.{h,cpp}.
//
// This is the canvas drawing-state stack — the genuine state-management logic of the 2D context.
// The actual pixel operations live in Gfx::Painter, which is not translated in this port; the
// C++ save()/restore() also call painter->save()/restore(), and those calls are omitted here
// (documented at each site). Gfx value types (Color, AffineTransform) are represented directly;
// Gfx::PaintStyle / Filter / FontCascadeList and CanvasPattern are held opaquely.
module html

import dom

// Gfx::AffineTransform — a 2x3 affine matrix; the default is the identity transform.
pub struct CanvasAffineTransform {
pub mut:
	a f64 = 1.0
	b f64
	c f64
	d f64 = 1.0
	e f64
	f f64
}

// Map a point through the transform: (a*x + c*y + e, b*x + d*y + f).
pub fn (t CanvasAffineTransform) map(point FloatPoint) FloatPoint {
	return FloatPoint{
		x: t.a * point.x + t.c * point.y + t.e
		y: t.b * point.x + t.d * point.y + t.f
	}
}

// The inverse transform, or none when the matrix is singular.
pub fn (t CanvasAffineTransform) inverse() ?CanvasAffineTransform {
	determinant := t.a * t.d - t.b * t.c
	if determinant == 0 {
		return none
	}
	return CanvasAffineTransform{
		a: t.d / determinant
		b: -t.b / determinant
		c: -t.c / determinant
		d: t.a / determinant
		e: (t.c * t.f - t.d * t.e) / determinant
		f: (t.b * t.e - t.a * t.f) / determinant
	}
}

// Placeholder for HTML::CanvasPattern (CanvasPattern.cpp is not translated yet).
@[heap]
pub struct CanvasPattern {}

// Bindings::CanvasLineCap
pub enum CanvasLineCap {
	butt
	round
	square
}

// Bindings::CanvasLineJoin
pub enum CanvasLineJoin {
	round
	bevel
	miter
}

// Bindings::ImageSmoothingQuality
pub enum ImageSmoothingQuality {
	low
	medium
	high
}

// Bindings::CanvasTextAlign
pub enum CanvasTextAlign {
	start
	end
	left
	right
	center
}

// Bindings::CanvasTextBaseline
pub enum CanvasTextBaseline {
	top
	hanging
	middle
	alphabetic
	ideographic
	bottom
}

// Bindings::CanvasDirection
pub enum CanvasDirection {
	ltr
	rtl
	inherit
}

// Gfx::CompositingAndBlendingOperator (globalCompositeOperation values).
pub enum CompositingAndBlendingOperator {
	source_over
	source_in
	source_out
	source_atop
	destination_over
	destination_in
	destination_out
	destination_atop
	lighter
	copy
	xor
	multiply
	screen
	overlay
	darken
	lighten
	color_dodge
	color_burn
	hard_light
	soft_light
	difference
	exclusion
	hue
	saturation
	color
	luminosity
	plus_darker
	plus_lighter
}

pub fn canvas_color_black() dom.Color {
	return dom.Color{
		r: 0
		g: 0
		b: 0
		a: 255
	}
}

pub fn canvas_color_transparent() dom.Color {
	return dom.Color{
		r: 0
		g: 0
		b: 0
		a: 0
	}
}

pub enum FillOrStrokeKind {
	color
	gradient
	pattern
}

// https://html.spec.whatwg.org/multipage/canvas.html#fill-and-stroke-styles
pub struct FillOrStrokeStyle {
pub mut:
	kind     FillOrStrokeKind = .color
	color    dom.Color
	gradient ?CanvasGradient
	pattern  ?&CanvasPattern
}

pub fn FillOrStrokeStyle.from_color(color dom.Color) FillOrStrokeStyle {
	return FillOrStrokeStyle{
		kind:  .color
		color: color
	}
}

pub fn FillOrStrokeStyle.from_gradient(gradient CanvasGradient) FillOrStrokeStyle {
	return FillOrStrokeStyle{
		kind:     .gradient
		gradient: gradient
	}
}

pub fn FillOrStrokeStyle.from_pattern(pattern &CanvasPattern) FillOrStrokeStyle {
	return FillOrStrokeStyle{
		kind:    .pattern
		pattern: pattern
	}
}

// Optional<Gfx::Color> as_color(): the solid color, if this is a color style.
pub fn (style &FillOrStrokeStyle) as_color() ?dom.Color {
	if style.kind == .color {
		return style.color
	}
	return none
}

// Gfx::Color to_color_but_fixme_should_accept_any_paint_style(): the color, or black.
pub fn (style &FillOrStrokeStyle) to_color_but_fixme_should_accept_any_paint_style() dom.Color {
	return style.as_color() or { canvas_color_black() }
}

// https://html.spec.whatwg.org/multipage/canvas.html#drawing-state
pub struct DrawingState {
pub mut:
	transform                                 CanvasAffineTransform
	fill_style                                FillOrStrokeStyle = FillOrStrokeStyle.from_color(canvas_color_black())
	stroke_style                              FillOrStrokeStyle = FillOrStrokeStyle.from_color(canvas_color_black())
	shadow_offset_x                           f64
	shadow_offset_y                           f64
	shadow_blur                               f64
	shadow_color                              dom.Color = canvas_color_transparent()
	filter_string                             ?string
	line_width                                f64            = 1.0
	line_cap                                  CanvasLineCap  = .butt
	line_join                                 CanvasLineJoin = .miter
	miter_limit                               f64            = 10.0
	dash_list                                 []f64
	line_dash_offset                          f64
	image_smoothing_enabled                   bool                           = true
	image_smoothing_quality                   ImageSmoothingQuality          = .low
	global_alpha                              f64                            = 1.0
	current_compositing_and_blending_operator CompositingAndBlendingOperator = .source_over
	text_align                                CanvasTextAlign                = .start
	text_baseline                             CanvasTextBaseline             = .alphabetic
	direction                                 CanvasDirection                = .inherit
	// CSS::Length letter_spacing (default 0px); represented as px in this port.
	letter_spacing_px f64
	// Opaque Gfx handles (out of scope for this port): Gfx::Filter, CSS::StyleValue font,
	// Gfx::FontCascadeList.
}

// https://html.spec.whatwg.org/multipage/canvas.html#canvasstate
@[heap]
pub struct CanvasState {
pub mut:
	drawing_state DrawingState
mut:
	drawing_state_stack []DrawingState
	// https://html.spec.whatwg.org/multipage/canvas.html#concept-canvas-context-lost
	context_lost_ bool
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-save
pub fn (mut state CanvasState) save() {
	// Push a copy of the current drawing state onto the drawing state stack.
	state.drawing_state_stack << state.drawing_state
	// NOTE: the C++ also calls painter_for_canvas_state()->save(); no painter in this port.
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-restore
pub fn (mut state CanvasState) restore() {
	// Pop the top entry in the drawing state stack; do nothing if there is no saved state.
	if state.drawing_state_stack.len == 0 {
		return
	}
	state.drawing_state = state.drawing_state_stack.pop()
	// NOTE: the C++ also calls painter_for_canvas_state()->restore(); no painter in this port.
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-reset
pub fn (mut state CanvasState) reset() {
	// Reset the rendering context to its default state. The C++ delegates to the concrete
	// context's reset_to_default_state(), which also resets the backing bitmap (painter-side,
	// out of scope here).
	state.reset_drawing_state()
	state.clear_drawing_state_stack()
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-iscontextlost
pub fn (state &CanvasState) is_context_lost() bool {
	return state.context_lost_
}

pub fn (mut state CanvasState) set_context_lost(context_lost bool) {
	state.context_lost_ = context_lost
}

pub fn (mut state CanvasState) clear_drawing_state_stack() {
	state.drawing_state_stack.clear()
}

pub fn (mut state CanvasState) reset_drawing_state() {
	state.drawing_state = DrawingState{}
}

pub fn (state &CanvasState) drawing_state_stack_depth() int {
	return state.drawing_state_stack.len
}
