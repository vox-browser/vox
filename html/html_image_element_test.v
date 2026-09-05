module html

import dom

__global image_batch_callback_count int

fn image_batch_test_callback() {
	image_batch_callback_count++
}

fn test_image_batching_dispatcher_queues_and_flushes_callbacks() {
	unsafe { image_batch_callback_count = 0 }
	mut dispatcher := batching_dispatcher()
	dispatcher.enqueue(image_batch_test_callback)
	dispatcher.enqueue(image_batch_test_callback)
	assert unsafe { image_batch_callback_count } == 0
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert unsafe { image_batch_callback_count } == 2
}

fn image_test_fetch(url dom.URL) !DecodedImageData {
	if url.serialize().contains('broken') {
		return error('decode failed')
	}
	bitmap := &dom.ImmutableBitmap_{
		width: 200
		height: 100
		pitch: 800
		data: []u8{len: 200 * 100 * 4}
	}
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ bitmap: bitmap, duration: 10 },
		BitmapDecodedImageFrame{ bitmap: bitmap, duration: 10 },
	], 1, true)
}

fn test_image_source_selection_load_dimensions_and_decode() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_fetch_hook(image_test_fetch)
	image.set_src('/fallback.png')
	image.set_srcset('/one.png 1x, /two.png 2x')
	image.update_the_image_data(false, false)
	assert image.complete()
	assert image.current_src() == 'https://example.test/one.png'
	assert image.natural_width() == 200
	assert image.natural_height() == 100
	assert image.width() == 200
	assert image.height() == 100
	assert image.event_count('load') == 1
	assert image.decode().state() == .fulfilled
	image.set_width(50)
	image.set_height(25)
	assert image.width() == 50
	assert image.height() == 25
}

fn test_image_failure_empty_lazy_sizes_and_animation() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut empty := HTMLImageElementModel.create(document, document.base_url())
	assert empty.complete()
	empty.set_loading(.lazy)
	empty.set_sizes('AUTO, 100vw')
	assert empty.allows_auto_sizes()

	mut broken := HTMLImageElementModel.create(document, document.base_url())
	broken.set_fetch_hook(image_test_fetch)
	broken.set_src('/broken.png')
	broken.update_the_image_data(false, false)
	assert broken.complete()
	assert broken.current_request().state() == .broken
	assert broken.event_count('error') == 1
	assert broken.decode().state() == .rejected

	mut animated := HTMLImageElementModel.create(document, document.base_url())
	animated.set_fetch_hook(image_test_fetch)
	animated.set_src('/animated.png')
	animated.update_the_image_data(false, false)
	animated.animate()
	assert animated.current_frame_index() == 1
	animated.animate()
	assert animated.current_frame_index() == 1
	animated.restart_the_animation()
	assert animated.current_frame_index() == 0
}

fn test_concrete_image_element_picture_source_requests_roles_and_dimensions() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)

	mut picture := document.create_element_ns('http://www.w3.org/1999/xhtml', 'picture') or {
		panic(err)
	}
	mut source := document.create_element_ns('http://www.w3.org/1999/xhtml', 'source') or {
		panic(err)
	}
	mut non_matching_source := document.create_element_ns('http://www.w3.org/1999/xhtml', 'source') or { panic(err) }
	non_matching_source.set_attribute_value('srcset', '/wrong-media.png 1x')
	non_matching_source.set_attribute_value('media', '(max-width: 100px)')
	source.set_attribute_value('srcset', '/picture.png 1x, /retina.png 2x')
	source.set_attribute_value('media', '(min-width: 600px)')
	source.set_attribute_value('type', 'image/png')
	source.set_attribute_value('width', '320')
	mut image_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img') or {
		panic(err)
	}
	image_element.set_attribute_value('src', '/fallback.png')
	image_element.set_attribute_value('alt', 'translated image')
	mut picture_node := unsafe { &dom.Node(picture) }
	picture_node.append_child(non_matching_source.as_node()) or { panic(err) }
	picture_node.append_child(source.as_node()) or { panic(err) }
	picture_node.append_child(image_element.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(picture.as_node()) or { panic(err) }

	image := unsafe { &dom.HTMLImageElement(image_element) }
	mut model := html_image_element_model_for_dom_element(image)
	model.set_fetch_hook(image_test_fetch)
	html_image_element_update_the_image_data(image, false, false)
	assert html_image_element_uses_srcset_or_picture(image)
	assert html_image_element_current_src(image) == 'https://example.test/picture.png'
	assert html_image_element_complete(image)
	assert html_image_element_natural_width(image) == 200
	assert html_image_element_intrinsic_aspect_ratio(image)? == 2.0
	assert html_image_element_dimension_attribute_source(image) == source
	assert html_image_element_default_role(image) == .image
	assert model.event_count('load') == 1

	html_image_element_set_width(image, 75)
	html_image_element_set_height(image, 30)
	assert html_image_element_width(image) == 75
	assert html_image_element_height(image) == 30
	assert image_element.get_attribute_value('width') == '75'
	assert image_element.get_attribute_value('height') == '30'

	image_element.set_attribute_value('alt', '')
	html_image_element_form_associated_element_attribute_changed(image, 'alt', 'translated image', '', none)
	assert html_image_element_default_role(image) == .none_
	assert html_image_element_alternative_text(image)? == ''
}
