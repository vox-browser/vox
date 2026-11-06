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
import webgl

const maximum_canvas_area = u64(16384 * 16384)

@[heap]
pub struct CanvasExternalContentSource {
pub mut:
	frame ?&dom.DecodedImageFrame_
}

pub fn (mut source CanvasExternalContentSource) clear() {
	source.frame = none
}

pub fn (mut source CanvasExternalContentSource) update(frame ?&dom.DecodedImageFrame_) {
	source.frame = frame
}

pub fn (source &CanvasExternalContentSource) current_frame() ?&dom.DecodedImageFrame_ {
	return source.frame
}

@[heap]
struct HTMLCanvasElementState {
pub:
	element &dom.HTMLCanvasElement
pub mut:
	surface                 &OffscreenCanvas = unsafe { nil }
	context                 ?&CanvasRenderingContext2D
	webgl_context           ?&webgl.WebGLRenderingContext
	external_content_source ?&CanvasExternalContentSource
	transferred             bool
	dirty                   bool
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
	if state := html_canvas_element_states[key] {
		mut mutable_state := unsafe { &HTMLCanvasElementState(state) }
		width, height := html_canvas_element_dimensions(element)
		if state.surface.width() != width || state.surface.height() != height {
			mut surface := state.surface
			surface.set_new_bitmap_size(width, height)!
			mutable_state.dirty = true
			if context := state.webgl_context {
				mut mutable_context := unsafe { &webgl.WebGLRenderingContext(context) }
				mutable_context.set_size(int(width),int(height))
			}
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
	old_value := base.get_attribute('width')
	base.set_attribute_value('width', actual.str())
	html_canvas_element_attribute_changed(&element, 'width', old_value, actual.str(), none)
	html_canvas_element_notify_context_about_canvas_size_change(&element)!
	html_canvas_element_reset_context_to_default_state(&element)!
}

pub fn html_canvas_element_set_height(mut element dom.HTMLCanvasElement, value u32) ! {
	actual := if value > u32(max_int) { u32(150) } else { value }
	mut base := unsafe { &dom.Element(&element) }
	old_value := base.get_attribute('height')
	base.set_attribute_value('height', actual.str())
	html_canvas_element_attribute_changed(&element, 'height', old_value, actual.str(), none)
	html_canvas_element_notify_context_about_canvas_size_change(&element)!
	html_canvas_element_reset_context_to_default_state(&element)!
}

pub fn html_canvas_element_reset_context_to_default_state(element &dom.HTMLCanvasElement) ! {
	mut state := ensure_html_canvas_element_state(element)!
	if source := state.external_content_source {
		mut mutable_source := unsafe { &CanvasExternalContentSource(source) }
		mutable_source.clear()
	}
	if context := state.context {
		mut mutable_context := unsafe { &CanvasRenderingContext2D(context) }
		mutable_context.reset_to_default_state()
	}
}

pub fn html_canvas_element_ensure_external_content_source(element &dom.HTMLCanvasElement) &CanvasExternalContentSource {
	mut state := ensure_html_canvas_element_state(element) or {
		panic('failed to allocate canvas state: ${err}')
	}
	if source := state.external_content_source {
		return source
	}
	source := &CanvasExternalContentSource{}
	state.external_content_source = source
	return source
}

pub fn html_canvas_element_attribute_changed(element &dom.HTMLCanvasElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(local_name, old_value, value, namespace_)
	if local_name in ['width', 'height'] {
		html_canvas_element_notify_context_about_canvas_size_change(element) or { return }
		html_canvas_element_reset_context_to_default_state(element) or { return }
		mut node := unsafe { &dom.Node(dom_element.as_node()) }
		node.set_needs_layout_update(.html_canvas_element_width_or_height_change)
	}
}

pub fn html_canvas_element_notify_context_about_canvas_size_change(element &dom.HTMLCanvasElement) ! {
	mut state := ensure_html_canvas_element_state(element)!
	width, height := html_canvas_element_dimensions(element)
	mut surface := state.surface
	surface.set_new_bitmap_size(width, height)!
	if context := state.webgl_context {
		mut mutable_context := unsafe { &webgl.WebGLRenderingContext(context) }
		mutable_context.set_size(int(width),int(height))
	}
	state.dirty = true
}

pub fn html_canvas_element_create_2d_context(element &dom.HTMLCanvasElement, options ?map[string]dom.JSValue) !&CanvasRenderingContext2D {
	return html_canvas_element_get_context(element, '2d', options)
}

pub fn html_canvas_element_create_webgl_context(element &dom.HTMLCanvasElement, options ?map[string]dom.JSValue) !&webgl.WebGLRenderingContext {
	return html_canvas_element_create_webgl_context_for_version(element,.webgl1,options)
}

pub fn html_canvas_element_bitmap_size_for_canvas(element &dom.HTMLCanvasElement) (u32, u32) {
	return html_canvas_element_dimensions(element)
}

pub fn html_canvas_element_get_bitmap_from_surface(element &dom.HTMLCanvasElement) ?&dom.Bitmap_ {
	width,height := html_canvas_element_dimensions(element)
	if width == 0 || height == 0 { return none }
	state := ensure_html_canvas_element_state(element) or { return none }
	if context := state.webgl_context {
		mut mutable_context := unsafe { &webgl.WebGLRenderingContext(context) }
		frame := mutable_context.native.read_back_drawing_buffer() or { return none }
		return webgl_frame_bitmap(frame)
	}
	return state.surface.bitmap()
}

pub fn html_canvas_element_surface(element &dom.HTMLCanvasElement) ?&dom.Bitmap_ {
	return html_canvas_element_get_bitmap_from_surface(element)
}

// CanvasPaintable::paint() only presents a surface which already exists; a
// layout/paint pass must not allocate a default 300x150 bitmap for a canvas
// whose context has never been requested.
pub fn html_canvas_element_present_existing_surface(element &dom.HTMLCanvasElement) ?&dom.Bitmap_ {
	state := html_canvas_element_states[html_canvas_element_key(element)] or { return none }
	html_canvas_element_present(element)
	return state.surface.bitmap()
}

pub fn html_canvas_element_allocate_painting_surface_if_needed(element &dom.HTMLCanvasElement) ! {
	_ = ensure_html_canvas_element_state(element)!
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
		element: element
	}
	// Rebind the self-references after copying the offscreen implementation
	// into the element-owned context.
	context.OffscreenCanvasRenderingContext2D.CanvasPath.canvas_state_ = &context.OffscreenCanvasRenderingContext2D.CanvasState
	context.OffscreenCanvasRenderingContext2D.CanvasState.set_reset_callback(voidptr(&context.OffscreenCanvasRenderingContext2D), offscreen_canvas_state_reset)
	base_element := unsafe { &dom.Element(element) }
	context.OffscreenCanvasRenderingContext2D.CanvasState.set_font_resolution_document(base_element.as_node().document())
	mut mutable_surface := unsafe { &OffscreenCanvas(surface) }
	mutable_surface.context_ = &context.OffscreenCanvasRenderingContext2D
	return context
}

pub fn (context &CanvasRenderingContext2D) canvas_for_binding() &dom.HTMLCanvasElement {
	return context.element
}

pub fn (context &CanvasRenderingContext2D) get_context_attributes() CanvasRenderingContext2DSettings {
	return context.OffscreenCanvasRenderingContext2D.get_context_attributes()
}

pub fn (context &CanvasRenderingContext2D) surface() ?&dom.Bitmap_ {
	return context.OffscreenCanvasRenderingContext2D.canvas_.bitmap()
}

pub fn (context &CanvasRenderingContext2D) is_canvas_rendering_context_2d() bool {
	_ = context
	return true
}

pub fn (context &CanvasRenderingContext2D) painter_for_canvas_state() voidptr {
	_ = context
	return unsafe { nil }
}

pub fn (mut context CanvasRenderingContext2D) path_for_canvas_state() &CanvasGfxPath {
	return context.OffscreenCanvasRenderingContext2D.CanvasPath.mutable_path_storage()
}

pub fn html_canvas_element_get_context(element &dom.HTMLCanvasElement, type_ string, options ?map[string]dom.JSValue) !&CanvasRenderingContext2D {
	mut state := ensure_html_canvas_element_state(element)!
	if state.transferred {
		return error('InvalidStateError: canvas control was transferred to an OffscreenCanvas')
	}
	if type_ != '2d' {
		return unsafe { nil }
	}
	settings := CanvasRenderingContext2DSettings.from_js_value(options)!
	if state.webgl_context != none { return unsafe { nil } }
	if context := state.context {
		return context
	}
	context := CanvasRenderingContext2D.create(element, state.surface, settings)
	state.context = context
	return context
}

pub fn html_canvas_element_bitmap(element &dom.HTMLCanvasElement) !&dom.Bitmap_ {
	return html_canvas_element_get_bitmap_from_surface(element) or { unsafe { nil } }
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
	if state := html_canvas_element_states[html_canvas_element_key(element)] {
		mut mutable_state := unsafe { &HTMLCanvasElementState(state) }
		if context := state.webgl_context {
			width,height := html_canvas_element_dimensions(element)
			if width == 0 || height == 0 { return }
			if !state.dirty && !context.needs_to_present() { return }
			mut mutable_context := unsafe { &webgl.WebGLRenderingContext(context) }
			if !mutable_context.prepare_for_compositing() { return }
			frame := context.native.painting_surface() or { return }
			mut surface := state.surface
			surface.bitmap_ = webgl_frame_bitmap(frame)
		}
		if source := state.external_content_source {
			mut mutable_source := unsafe { &CanvasExternalContentSource(source) }
			if bitmap := state.surface.bitmap() {
				mutable_source.update(dom.DecodedImageFrame_.create(bitmap.clone()))
			} else {
				mutable_source.clear()
			}
		}
		mutable_state.dirty = false
	}
}

pub fn html_canvas_element_is_origin_clean(element &dom.HTMLCanvasElement) bool {
	state := html_canvas_element_states[html_canvas_element_key(element)] or { return true }
	context := state.context or { return true }
	return context.origin_clean()
}

pub fn html_canvas_element_to_data_url(element &dom.HTMLCanvasElement, type_ string, quality ?f64, encode_png PNGEncodeCallback, encode_jpeg JPEGEncodeCallback) !string {
	if !html_canvas_element_is_origin_clean(element) {
		return error('SecurityError: Canvas is not origin-clean')
	}
	width, height := html_canvas_element_dimensions(element)
	if width == 0 || height == 0 || u64(width) * u64(height) > maximum_canvas_area {
		return 'data:,'
	}
	bitmap := html_canvas_element_get_bitmap_from_surface(element) or { return 'data:,' }
	serialized := serialize_bitmap(bitmap, type_, quality, encode_png, encode_jpeg) or {
		return 'data:,'
	}
	encoded := base64.encode(serialized.buffer)
	return 'data:${serialized.mime_type};base64,' + encoded
}

pub fn html_canvas_element_to_blob(element &dom.HTMLCanvasElement, type_ string, quality ?f64, encode_png PNGEncodeCallback, encode_jpeg JPEGEncodeCallback) !SerializeBitmapResult {
	if !html_canvas_element_is_origin_clean(element) {
		return error('SecurityError: Canvas is not origin-clean')
	}
	width, height := html_canvas_element_dimensions(element)
	if width == 0 || height == 0 || u64(width) * u64(height) > maximum_canvas_area {
		return error('IndexSizeError: canvas has no serializable bitmap')
	}
	bitmap := html_canvas_element_get_bitmap_from_surface(element) or { return error('IndexSizeError: canvas has no bitmap') }
	return serialize_bitmap(bitmap, type_, quality, encode_png, encode_jpeg)
}

pub fn html_canvas_element_transfer_control_to_offscreen(element &dom.HTMLCanvasElement) !&OffscreenCanvas {
	mut state := ensure_html_canvas_element_state(element)!
	if state.context != none || state.webgl_context != none {
		return error('InvalidStateError: canvas already has a rendering context')
	}
	if state.transferred {
		return error('InvalidStateError: canvas control has already been transferred')
	}
	state.transferred = true
	return state.surface
}
