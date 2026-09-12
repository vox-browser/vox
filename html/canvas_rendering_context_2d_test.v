@[has_globals]
module html

import dom

fn html_canvas_test_png(bitmap &dom.ImmutableBitmap_) ![]u8 {
	return bitmap.data.clone()
}

fn html_canvas_test_jpeg(bitmap &dom.ImmutableBitmap_, quality ?int) ![]u8 {
	_ = quality
	return bitmap.data.clone()
}

fn test_html_canvas_defaults_context_pixels_and_serialization() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	assert html_canvas_element_width(canvas) == 300
	assert html_canvas_element_height(canvas) == 150
	mut context := html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }
	assert voidptr(context) == voidptr(html_canvas_element_get_context(canvas, '2d', none) or {
		panic(err)
	})
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ b: 255, a: 255 })
	context.fill_rect(0, 0, 2, 2)
	pixel := context.get_image_data(0, 0, 1, 1, none) or { panic(err) }
	assert pixel.data() == [u8(0), 0, 255, 255]

	data_url := html_canvas_element_to_data_url(canvas, 'image/png', none, html_canvas_test_png,
		html_canvas_test_jpeg)
	assert data_url.starts_with('data:image/png;base64,')
}

fn test_html_canvas_resize_resets_context_and_offscreen_transfer_rules() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut first_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	mut first_canvas := unsafe { &dom.HTMLCanvasElement(first_element) }
	mut context := html_canvas_element_get_context(first_canvas, '2d', none) or { panic(err) }
	context.set_global_alpha(0.3)
	html_canvas_element_set_width(mut first_canvas, 10) or { panic(err) }
	assert context.global_alpha() == 1.0
	assert html_canvas_element_width(first_canvas) == 10
	if _ := html_canvas_element_transfer_control_to_offscreen(first_canvas) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}

	second_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	second_canvas := unsafe { &dom.HTMLCanvasElement(second_element) }
	offscreen := html_canvas_element_transfer_control_to_offscreen(second_canvas) or { panic(err) }
	assert offscreen.width() == 300
	if _ := html_canvas_element_get_context(second_canvas, '2d', none) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
}

fn test_canvas_attribute_change_and_external_content_source_follow_element_lifecycle() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	mut context := html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }
	context.set_global_alpha(0.25)
	source := html_canvas_element_ensure_external_content_source(canvas)
	assert !source.cleared
	element.set_attribute_value('width', '24')
	html_canvas_element_attribute_changed(canvas, 'width', none, '24', none)
	assert html_canvas_element_width(canvas) == 24
	assert context.global_alpha() == 1.0
	assert source.cleared
}

fn test_canvas_font_uses_detached_document_resolution_context() {
	// A Document created directly has no Window or navigable, matching the
	// createHTMLDocument() regression from upstream.
	mut detached_document := dom.Document.create(dom.url_about_blank())
	detached_document.set_viewport_rect(dom.Rect{ width: 500, height: 300 })
	element := detached_document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	mut context := html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }

	context.set_font('10vw serif')
	assert context.font() == '10vw serif'
	assert context.drawing_state.font_size_px == 50
	context.fill_text('a', 0, 50, none)
	context.stroke_text('a', 0, 50, none)
	metrics := context.measure_text('aa')
	assert metrics.width() == 50
}

fn test_canvas_text_preparation_preserves_non_ascii_code_points() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	context := html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }

	decomposed_text := 'o' + rune(0x301).str()
	precomposed := context.prepare_text('ó', 100)
	decomposed := context.prepare_text(decomposed_text, 100)
	assert precomposed.text == 'ó'
	assert decomposed.text == decomposed_text
	assert context.measure_text('ó').width() > 0
	assert context.measure_text('ó').width() == context.measure_text(decomposed_text).width()
	assert context.measure_text('Kraków').width() > context.measure_text('Krakw').width()
}
