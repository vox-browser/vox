module main

import dom
import html
import layout

fn test_large_data_images_keep_a_bounded_distinct_decode_identity() {
	assert chromium_image_decode_resource_identity('') == ''
	assert chromium_image_decode_resource_identity('https://image.test/a') == 'url:https://image.test/a'
	boundary := 'x'.repeat(16380)
	assert chromium_image_decode_resource_identity(boundary).len == 16384
	data := 'data:image/avif;base64,' + 'A'.repeat(20000)
	key := chromium_image_decode_resource_identity(data)
	assert key.starts_with('sha256:') && key.len == 71
	assert key == chromium_image_decode_resource_identity(data.clone())
	assert key != chromium_image_decode_resource_identity(data + 'B')
	assert key != chromium_image_decode_resource_identity(key)
	assert key != chromium_image_decode_resource_identity(data.replace('image/avif', 'image/jpeg'))
}


fn decode_policy_test_document(markup string) &dom.Document {
	address := dom.URL{ value: 'https://image.test/' }
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn install_decode_policy_test_pixels(element &dom.Element) &html.HTMLImageElementModel {
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width: 2
				height: 2
				pitch: 8
				data: [u8(255)].repeat(16)
			})
		}], 0, false)
	})
	model.update_the_image_data(false, false)
	return model
}

fn test_image_decode_policy_reads_live_html_hints_and_owner() {
	mut document := decode_policy_test_document('<img id="image" src="https://image.test/pixel.png"><div id="other"></div>')
	defer { document.finalize() }
	mut other_document := decode_policy_test_document('<p>other document</p>')
	defer { other_document.finalize() }
	mut image := document.get_element_by_id('image') or { panic('image') }
	_ = install_decode_policy_test_pixels(image)
	id := image.as_node().unique_id().value()
	assert chromium_image_decoding_hint(document, id) == 0
	for hint in ['async', 'ASYNC', 'AsYnC'] {
		image.set_attribute_value('decoding', hint)
		assert chromium_image_decoding_hint(document, id) == 1
	}
	for hint in ['sync', 'auto', '', 'invalid', ' async '] {
		image.set_attribute_value('decoding', hint)
		assert chromium_image_decoding_hint(document, id) == 0
	}
	assert chromium_image_decoding_hint(other_document, id) == -1
	assert chromium_image_decoding_hint(document, 0) == -1
	other := document.get_element_by_id('other') or { panic('other') }
	assert chromium_image_decoding_hint(document, other.as_node().unique_id().value()) == -1
}

fn test_unavailable_image_does_not_contribute_a_decode_task() {
	mut document := decode_policy_test_document('<img id="image" src="https://image.test/pixel.png" decoding="async">')
	defer { document.finalize() }
	image := document.get_element_by_id('image') or { panic('image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	model.set_async_fetch_hook(fn (_ dom.URL, _ html.HTMLImageFetchCompletion) {})
	model.update_the_image_data(false, false)
	id := image.as_node().unique_id().value()
	assert chromium_image_decoding_hint(document, id) == -1
	_ = install_decode_policy_test_pixels(image)
	assert chromium_image_decoding_hint(document, id) == 1
}

fn test_replaced_image_commands_retain_the_html_element_identity() {
	mut document := decode_policy_test_document('<!doctype html><style>body{margin:0}img{width:30px;height:20px;object-fit:cover}</style><img id="image" src="https://image.test/pixel.png" decoding="async">')
	defer { document.finalize() }
	image := document.get_element_by_id('image') or { panic('image') }
	_ = install_decode_policy_test_pixels(image)
	_ = layout.layout_document_typed_in_viewport(document, 200, 100)
	commands := layout.display_list_commands(document.record_display_list() or { panic('commands') })
	images := commands.filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	assert images[0].image().image_element_id == image.as_node().unique_id().value()
	assert chromium_paint_image_decoding_hint(document, &images[0]) == 1
	zero_width := layout.PaintCommand{ ...images[0] width: 0 }
	zero_height := layout.PaintCommand{ ...images[0] height: 0 }
	assert chromium_paint_image_decoding_hint(document, &zero_width) == -1
	assert chromium_paint_image_decoding_hint(document, &zero_height) == -1
}

fn test_animated_image_vetoes_async_checkering() {
	mut document := decode_policy_test_document('<img id="image" src="https://image.test/animation.gif" decoding="async">')
	defer { document.finalize() }
	image := document.get_element_by_id('image') or { panic('image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		frame := html.BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width: 1
				height: 1
				pitch: 4
				data: [u8(255), 0, 0, 255]
			})
		}
		return html.BitmapDecodedImageData.create([frame, frame], 0, true)
	})
	model.update_the_image_data(false, false)
	assert chromium_image_decoding_hint(document, image.as_node().unique_id().value()) == 0
}
