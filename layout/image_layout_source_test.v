module layout

import css
import dom
import html

fn image_source_test_document() (&dom.Document, &dom.Element, &html.HTMLImageElementModel) {
	address := dom.URL{value: 'https://images.example/page/'}
	mut document := html.parse_navigation_document('<!doctype html><img id="photo" src="fallback.png" srcset="small.png 1x, large.png 2x" sizes="40px" width="40" height="30">', address, address.origin(), none) or { panic(err) }
	element := document.get_element_by_id('photo') or { panic('missing image') }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	return document, element, model
}

fn test_layout_image_source_uses_attributes_until_a_request_is_available() {
	document, element, model := image_source_test_document()
	defer { document.finalize() }
	mut request := model.current_request()
	request.set_current_url('https://images.example/selected.png')
	for state in [html.ImageRequestState.unavailable, .broken] {
		request.set_state(state)
		assert image_source_for_layout(element) == image_source_selected_from_attributes(element)
	}
	for state in [html.ImageRequestState.partially_available, .completely_available] {
		request.set_state(state)
		assert image_source_for_layout(element) == 'https://images.example/selected.png'
	}
}

fn test_layout_image_source_keeps_attribute_fallback_for_an_empty_available_request() {
	document, element, model := image_source_test_document()
	defer { document.finalize() }
	mut request := model.current_request()
	request.set_state(.completely_available)
	request.set_current_url('')
	assert image_source_for_layout(element) == image_source_selected_from_attributes(element)
}

fn test_layout_image_source_reads_live_request_and_attribute_replacements() {
	document, mut element, model := image_source_test_document()
	defer { document.finalize() }
	mut request := model.current_request()
	request.set_state(.completely_available)
	request.set_current_url('https://images.example/old.png')
	assert image_source_for_layout(element) == 'https://images.example/old.png'
	element.set_attribute_value('srcset', 'next.png 1x, next-large.png 2x')
	element.set_attribute_value('sizes', '120px')
	// A new candidate does not replace the currently available request early.
	assert image_source_for_layout(element) == 'https://images.example/old.png'
	request.set_current_url('https://images.example/next-large.png')
	gc_collect()
	assert image_source_for_layout(element) == 'https://images.example/next-large.png'
	request.set_state(.broken)
	assert image_source_for_layout(element) == image_source_selected_from_attributes(element)
}

fn image_source_test_pixels() html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: 8
			height: 6
			pitch: 32
			data: []u8{len: 8 * 6 * 4, init: 255}
		})
	}], 0, false)
}

fn test_image_constructor_and_relayout_keep_the_available_request_url_and_size() {
	document, element, mut model := image_source_test_document()
	defer { document.finalize() }
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return image_source_test_pixels() })
	model.update_the_image_data(false, false)
	mut request := model.current_request()
	request.set_current_url('https://images.example/redirected.png')
	values := css.ComputedProperties.new()
	mut box := ImageBox.new(document, element, values)
	assert box.source() == 'https://images.example/redirected.png'
	assert box.natural_size().width or { CSSPixels.new(0) } == CSSPixels.new(8)
	request.set_current_url('https://images.example/replaced.png')
	box.reset_for_relayout()
	assert box.source() == 'https://images.example/replaced.png'
	assert box.natural_size().height or { CSSPixels.new(0) } == CSSPixels.new(6)
}

fn test_non_html_images_keep_attribute_source_selection() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for name in ['image', 'img'] {
		mut element := document.create_element_ns('http://www.w3.org/2000/svg', name)!
		element.set_attribute_value('src', 'fallback.png')
		element.set_attribute_value('srcset', 'first.png 1x, second.png 2x')
		assert image_source_for_layout(element) == image_source_selected_from_attributes(element)
	}
}
