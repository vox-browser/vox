// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// HTMLCanvasElement get_context/create_webgl_context and surface ownership.
module html

import dom
import webgl

pub enum HTMLCanvasContextKind {
	none
	canvas_2d
	webgl
	webgl2
}

// The source RenderingContext variant, retaining concrete context identity.
// Existing typed 2D callers use html_canvas_element_get_context directly.
pub struct HTMLCanvasRenderingContext {
pub:
	kind          HTMLCanvasContextKind
	canvas_2d     ?&CanvasRenderingContext2D
	webgl_context ?&webgl.WebGLRenderingContext
}

fn webgl_dictionary_boolean(dictionary map[string]dom.JSValue, name string) ?bool {
	value := dictionary[name] or { return none }
	if value.is_undefined() { return none }
	return canvas_settings_to_boolean(value)
}

fn webgl_attributes_from_js(options ?map[string]dom.JSValue) !webgl.WebGLContextAttributes {
	dictionary := (options or { return webgl.WebGLContextAttributes{} }).clone()
	mut power := ?string(none)
	if value := dictionary['powerPreference'] {
		if !value.is_undefined() { power = value.to_string_value() }
	}
	return webgl.convert_context_attributes(webgl.ContextAttributeInput{
		alpha:                            webgl_dictionary_boolean(dictionary, 'alpha')
		depth:                            webgl_dictionary_boolean(dictionary, 'depth')
		stencil:                          webgl_dictionary_boolean(dictionary, 'stencil')
		antialias:                        webgl_dictionary_boolean(dictionary, 'antialias')
		premultiplied_alpha:              webgl_dictionary_boolean(dictionary, 'premultipliedAlpha')
		preserve_drawing_buffer:          webgl_dictionary_boolean(dictionary, 'preserveDrawingBuffer')
		power_preference:                 power
		fail_if_major_performance_caveat: webgl_dictionary_boolean(dictionary, 'failIfMajorPerformanceCaveat')
		desynchronized:                   webgl_dictionary_boolean(dictionary, 'desynchronized')
		xr_compatible:                    webgl_dictionary_boolean(dictionary, 'xrCompatible')
	})
}

fn html_canvas_element_create_webgl_context_for_version(element &dom.HTMLCanvasElement, version webgl.WebGLVersion, options ?map[string]dom.JSValue) !&webgl.WebGLRenderingContext {
	mut state := ensure_html_canvas_element_state(element)!
	if state.transferred {
		return error('InvalidStateError: canvas control was transferred to an OffscreenCanvas')
	}
	if state.context != none { return unsafe { nil } }
	if context := state.webgl_context {
		return if context.version == version { context } else { unsafe { nil } }
	}
	attributes := webgl_attributes_from_js(options)!
	mut context := webgl.WebGLRenderingContext.new(version, attributes, [])
	context.bind_canvas_for_binding(voidptr(element))
	context.native.bind_canvas_content_changed(voidptr(element), html_webgl_canvas_content_changed)
	if context.native.is_lost() {
		mut target := unsafe { &dom.EventTarget(element) }
		target.dispatch_event(dom.Event.create('webglcontextcreationerror', dom.EventInit{}))
		return unsafe { nil }
	}
	width, height := html_canvas_element_dimensions(element)
	context.set_size(int(width), int(height))
	state.webgl_context = context
	state.dirty = true
	return context
}

pub fn html_canvas_element_create_webgl2_context(element &dom.HTMLCanvasElement, options ?map[string]dom.JSValue) !&webgl.WebGLRenderingContext {
	return html_canvas_element_create_webgl_context_for_version(element, .webgl2, options)
}

pub fn html_canvas_element_get_rendering_context(element &dom.HTMLCanvasElement, type_ string, options ?map[string]dom.JSValue) !HTMLCanvasRenderingContext {
	if type_ == '2d' {
		context := html_canvas_element_get_context(element, type_, options)!
		if context == unsafe { nil } { return HTMLCanvasRenderingContext{} }
		return HTMLCanvasRenderingContext{ kind: .canvas_2d, canvas_2d: context }
	}
	if type_ in ['webgl', 'experimental-webgl', 'webgl2'] {
		version := if type_ == 'webgl2' {
			webgl.WebGLVersion.webgl2
		} else {
			webgl.WebGLVersion.webgl1
		}
		context := html_canvas_element_create_webgl_context_for_version(element, version, options)!
		if context == unsafe { nil } { return HTMLCanvasRenderingContext{} }
		return HTMLCanvasRenderingContext{ kind: if version == .webgl2 { .webgl2 } else { .webgl }, webgl_context: context }
	}
	return HTMLCanvasRenderingContext{}
}

pub fn html_canvas_element_webgl_context(element &dom.HTMLCanvasElement) ?&webgl.WebGLRenderingContext {
	state := html_canvas_element_states[html_canvas_element_key(element)] or { return none }
	return state.webgl_context
}

fn webgl_frame_bitmap(frame webgl.WebGLPaintingSurface) &dom.Bitmap_ {
	return &dom.Bitmap_{ width: frame.width, height: frame.height, pitch: frame.width * 4, format: 0, alpha_type: 2, data: frame.pixels.clone(), native_rows_are_top_down: true }
}

fn html_webgl_canvas_content_changed(owner voidptr) {
	canvas := unsafe { &dom.HTMLCanvasElement(owner) }
	mut state := html_canvas_element_states[html_canvas_element_key(canvas)] or { return }
	state.dirty = true
	mut node := unsafe { &dom.Node(canvas) }
	node.set_needs_repaint(.paint_commands)
}
