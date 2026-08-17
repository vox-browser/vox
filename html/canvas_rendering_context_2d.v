// Copyright (c) 2020-2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLCanvasElement.{h,cpp} and CanvasRenderingContext2D.{h,cpp}.
// The element-owned context shares the tested RGBA raster implementation with
// OffscreenCanvasRenderingContext2D.
@[has_globals]
module html

import dom
import encoding.base64

const maximum_canvas_area = u64(16384 * 16384)

@[heap]
struct HTMLCanvasElementState {
pub:
	element &dom.HTMLCanvasElement
pub mut:
	surface     &OffscreenCanvas = unsafe { nil }
	context     ?&CanvasRenderingContext2D
	transferred bool
	dirty       bool
}

__global html_canvas_element_states map[u64]&HTMLCanvasElementState

fn html_canvas_element_key(element &dom.HTMLCanvasElement) u64 {
	return u64(voidptr(element))
}

fn html_canvas_element_dimensions(element &dom.HTMLCanvasElement) (u32, u32) {
	base := unsafe { &dom.Element(element) }
	width := if value := base.get_attribute('width') {
		parsed := parse_non_negative_integer(value) or { u32(300) }
		if parsed <= u32(max_int) {
			parsed
		} else {
			u32(300)
		}
	} else {
		u32(300)
	}
	height := if value := base.get_attribute('height') {
		parsed := parse_non_negative_integer(value) or { u32(150) }
		if parsed <= u32(max_int) {
			parsed
		} else {
			u32(150)
		}
	} else {
		u32(150)
	}
	return width, height
}

pub fn html_canvas_element_width(element &dom.HTMLCanvasElement) u32 {
	width, _ := html_canvas_element_dimensions(element)
	return width
}

pub fn html_canvas_element_height(element &dom.HTMLCanvasElement) u32 {
	_, height := html_canvas_element_dimensions(element)
	return height
}

fn ensure_html_canvas_element_state(element &dom.HTMLCanvasElement) !&HTMLCanvasElementState {
	key := html_canvas_element_key(element)
	if mut state := html_canvas_element_states[key] {
		width, height := html_canvas_element_dimensions(element)
		if state.surface.width() != width || state.surface.height() != height {
			mut surface := state.surface
			surface.set_new_bitmap_size(width, height)!
			state.dirty = true
		}
		return state
	}
	width, height := html_canvas_element_dimensions(element)
	surface := OffscreenCanvas.create(width, height)!
	state := &HTMLCanvasElementState{
		element: element
		surface: surface
	}
	html_canvas_element_states[key] = state
	return state
}

pub fn html_canvas_element_set_width(mut element dom.HTMLCanvasElement, value u32) ! {
	actual := if value > u32(max_int) { u32(300) } else { value }
	mut base := unsafe { &dom.Element(&element) }
	base.set_attribute_value('width', actual.str())
	state := ensure_html_canvas_element_state(&element)!
	mut surface := state.surface
	surface.set_new_bitmap_size(actual, html_canvas_element_height(&element))!
}

pub fn html_canvas_element_set_height(mut element dom.HTMLCanvasElement, value u32) ! {
	actual := if value > u32(max_int) { u32(150) } else { value }
	mut base := unsafe { &dom.Element(&element) }
	base.set_attribute_value('height', actual.str())
	state := ensure_html_canvas_element_state(&element)!
	mut surface := state.surface
	surface.set_new_bitmap_size(html_canvas_element_width(&element), actual)!
}

@[heap]
pub struct CanvasRenderingContext2D {
	OffscreenCanvasRenderingContext2D
pub:
	element &dom.HTMLCanvasElement
}

pub fn CanvasRenderingContext2D.create(element &dom.HTMLCanvasElement, surface &OffscreenCanvas, settings CanvasRenderingContext2DSettings) &CanvasRenderingContext2D {
	inner := OffscreenCanvasRenderingContext2D.create(surface, settings)
	mut context := &CanvasRenderingContext2D{
		OffscreenCanvasRenderingContext2D: *inner
		element:                           element
	}
	mut mutable_surface := unsafe { &OffscreenCanvas(surface) }
	mutable_surface.context_ = &context.OffscreenCanvasRenderingContext2D
	return context
}

pub fn (context &CanvasRenderingContext2D) canvas_for_binding() &dom.HTMLCanvasElement {
	return context.element
}

pub fn html_canvas_element_get_context(element &dom.HTMLCanvasElement, type_ string, options ?map[string]dom.JSValue) !&CanvasRenderingContext2D {
	mut state := ensure_html_canvas_element_state(element)!
	if state.transferred {
		return error('InvalidStateError: canvas control was transferred to an OffscreenCanvas')
	}
	if type_ != '2d' {
		return unsafe { nil }
	}
	if context := state.context {
		return context
	}
	settings := CanvasRenderingContext2DSettings.from_js_value(options)!
	context := CanvasRenderingContext2D.create(element, state.surface, settings)
	state.context = context
	return context
}

pub fn html_canvas_element_bitmap(element &dom.HTMLCanvasElement) !&dom.ImmutableBitmap_ {
	mut state := ensure_html_canvas_element_state(element)!
	return state.surface.bitmap() or { unsafe { nil } }
}

pub fn html_canvas_element_set_canvas_content_dirty(element &dom.HTMLCanvasElement) ! {
	mut state := ensure_html_canvas_element_state(element)!
	state.dirty = true
}

pub fn html_canvas_element_is_dirty(element &dom.HTMLCanvasElement) bool {
	state := html_canvas_element_states[html_canvas_element_key(element)] or { return false }
	return state.dirty
}

pub fn html_canvas_element_present(element &dom.HTMLCanvasElement) {
	if mut state := html_canvas_element_states[html_canvas_element_key(element)] {
		state.dirty = false
	}
}

pub fn html_canvas_element_to_data_url(element &dom.HTMLCanvasElement, type_ string, quality ?f64, encode_png PNGEncodeCallback, encode_jpeg JPEGEncodeCallback) string {
	width, height := html_canvas_element_dimensions(element)
	if width == 0 || height == 0 || u64(width) * u64(height) > maximum_canvas_area {
		return 'data:,'
	}
	state := ensure_html_canvas_element_state(element) or { return 'data:,' }
	bitmap := state.surface.bitmap() or { return 'data:,' }
	serialized := serialize_bitmap(bitmap, type_, quality, encode_png, encode_jpeg) or {
		return 'data:,'
	}
	return 'data:${serialized.mime_type};base64,${base64.encode(serialized.buffer)}'
}

pub fn html_canvas_element_to_blob(element &dom.HTMLCanvasElement, type_ string, quality ?f64, encode_png PNGEncodeCallback, encode_jpeg JPEGEncodeCallback) !SerializeBitmapResult {
	width, height := html_canvas_element_dimensions(element)
	if width == 0 || height == 0 || u64(width) * u64(height) > maximum_canvas_area {
		return error('IndexSizeError: canvas has no serializable bitmap')
	}
	mut state := ensure_html_canvas_element_state(element)!
	bitmap := state.surface.bitmap() or { return error('IndexSizeError: canvas has no bitmap') }
	return serialize_bitmap(bitmap, type_, quality, encode_png, encode_jpeg)
}

pub fn html_canvas_element_transfer_control_to_offscreen(element &dom.HTMLCanvasElement) !&OffscreenCanvas {
	mut state := ensure_html_canvas_element_state(element)!
	if state.context != none {
		return error('InvalidStateError: canvas already has a rendering context')
	}
	if state.transferred {
		return error('InvalidStateError: canvas control has already been transferred')
	}
	state.transferred = true
	return state.surface
}
