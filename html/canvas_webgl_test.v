module html

import dom
import webgl

fn canvas_webgl_test_element() &dom.HTMLCanvasElement {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or { panic(err) }
	return unsafe { &dom.HTMLCanvasElement(element) }
}

fn test_html_webgl_getter_preserves_kind_identity_options_and_source_null_results() {
	canvas := canvas_webgl_test_element()
	first := html_canvas_element_get_rendering_context(canvas, 'experimental-webgl', {
		'preserveDrawingBuffer': dom.js_string('truthy')
		'alpha':                 dom.js_number(0)
		'powerPreference':       dom.js_string('high-performance')
	}) or { panic(err) }
	mut context := first.webgl_context or { panic('native context') }
	assert first.kind == .webgl
	assert context.version == .webgl1
	assert context.canvas_for_binding() == voidptr(canvas)
	assert context.attributes.preserve_drawing_buffer
	assert !context.attributes.alpha
	assert context.attributes.power_preference == .high_performance
	assert context.drawing_buffer_width() == 300
	assert context.drawing_buffer_height() == 150
	second := html_canvas_element_get_rendering_context(canvas, 'webgl', {
		'powerPreference': dom.js_string('invalid')
	}) or { panic(err) }
	assert second.webgl_context? == context
	assert (html_canvas_element_get_rendering_context(canvas, 'webgl2', none) or { panic(err) }).kind == .none
	assert (html_canvas_element_get_rendering_context(canvas, '2d', none) or { panic(err) }).kind == .none
	assert (html_canvas_element_get_rendering_context(canvas, 'WEBGL', none) or { panic(err) }).kind == .none
	if _ := html_canvas_element_transfer_control_to_offscreen(canvas) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	other := canvas_webgl_test_element()
	if _ := html_canvas_element_create_webgl_context(other, {
		'powerPreference': dom.js_string('invalid')
	}) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	html_canvas_element_get_context(other, '2d', none) or { panic(err) }
	assert (html_canvas_element_get_rendering_context(other, 'webgl', none) or { panic(err) }).kind == .none
}

fn test_html_webgl_native_surface_reaches_existing_paint_registry_and_readback() {
	mut canvas := canvas_webgl_test_element()
	html_canvas_element_set_width(mut canvas, 2) or { panic(err) }
	html_canvas_element_set_height(mut canvas, 2) or { panic(err) }
	mut context := html_canvas_element_create_webgl2_context(canvas, none) or { panic(err) }
	mut source := html_canvas_element_ensure_external_content_source(canvas)
	context.clear_color(1, 0, 0, 1)
	context.clear(0x4000)
	assert html_canvas_element_is_dirty(canvas)
	presented := html_canvas_element_present_existing_surface(canvas) or { panic('presented surface') }
	assert presented.width == 2 && presented.height == 2
	assert presented.alpha_type == 2
	assert presented.native_rows_are_top_down
	assert presented.data[..4] == [u8(255), 0, 0, 255]
	frame := source.current_frame() or { panic('retained decoded frame') }
	assert frame.bitmap().data == presented.data
	assert !context.needs_to_present()
	// The retained display frame survives another paint after implicit discard.
	assert (html_canvas_element_present_existing_surface(canvas) or { panic('retained') }).data == presented.data
	assert (html_canvas_element_get_bitmap_from_surface(canvas) or { panic('live readback') }).data == []u8{len: 16}
	context.clear_color(0, 0, 1, 1)
	context.clear(0x4000)
	assert (html_canvas_element_present_existing_surface(canvas) or { panic('updated') }).data[..4] == [
		u8(0),
		0,
		255,
		255,
	]
	html_canvas_element_set_width(mut canvas, 3) or { panic(err) }
	assert context.drawing_buffer_width() == 3
	assert source.current_frame() == none
	assert (html_canvas_element_present_existing_surface(canvas) or { panic('resized') }).data == []u8{len: 24}
	assert context.get_error() == webgl.no_error
	html_canvas_element_set_width(mut canvas, 0) or { panic(err) }
	assert html_canvas_element_get_bitmap_from_surface(canvas) == none
	assert html_canvas_element_present_existing_surface(canvas) == none
}
