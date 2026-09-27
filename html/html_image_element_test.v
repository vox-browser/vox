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
	bitmap := &dom.Bitmap_{
		width:  200
		height: 100
		pitch:  800
		data:   []u8{len: 200 * 100 * 4}
	}
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame:    dom.DecodedImageFrame_.create(bitmap)
			duration: 10
		},
		BitmapDecodedImageFrame{
			frame:    dom.DecodedImageFrame_.create(bitmap)
			duration: 10
		},
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
	current_frame := image.current_image_frame() or { panic('missing current decoded frame') }
	assert current_frame.width() == 200
	default_frame := image.default_image_frame() or { panic('missing default decoded frame') }
	assert default_frame == current_frame
	assert image.width() == 200
	assert image.height() == 100
	assert image.event_count('load') == 1
	assert image.decode().state() == .fulfilled
	image.set_width(50)
	image.set_height(25)
	assert image.width() == 50
	assert image.height() == 25
}

fn test_image_decoded_data_tracks_display_client_lifetime() {
	document := dom.Document.create(dom.URL{ value: 'https://image-client.test/' })
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_fetch_hook(image_test_fetch)
	image.set_src('/displayed.png')
	image.update_the_image_data(false, false)
	decoded := image.decoded_image_data() or { panic('missing displayed image data') }
	assert decoded.has_clients()

	image.set_src('/broken.png')
	image.update_the_image_data(false, false)
	assert !decoded.has_clients()
}

fn test_image_decoded_data_tracks_cross_origin_response_tainting() {
	document := dom.Document.create(dom.URL{ value: 'https://frame.test/page' })
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_fetch_hook(image_test_fetch)
	image.set_src('https://images.test/picture.png')
	image.update_the_image_data(false, false)
	assert image.decoded_image_data()?.is_cors_cross_origin()

	mut cors_image := HTMLImageElementModel.create(document, document.base_url())
	cors_image.set_fetch_hook(image_test_fetch)
	cors_image.set_crossorigin('anonymous')
	cors_image.set_src('https://images.test/cors-picture.png')
	cors_image.update_the_image_data(false, false)
	assert !cors_image.decoded_image_data()?.is_cors_cross_origin()
}

fn test_image_decode_waits_for_completely_available_state() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/decode-test' })
	mut image := HTMLImageElementModel.create(document, document.base_url())
	mut request := image.current_request()
	request.set_current_url('https://example.test/async-image.png')
	request.set_state(.partially_available)
	image.add_callbacks_to_image_request(request, false, request.current_url(), '', 0)
	assert image.is_image_pending()
	promise := image.decode()
	assert promise.state() == .pending
	assert image.natural_width() == 0

	mut shared_request := request.shared_resource_request() or { panic('missing shared request') }
	decoded := image_test_fetch(dom.URL{ value: request.current_url() }) or { panic(err) }
	shared_request.handle_successful_resource_load(decoded)
	assert request.state() == .partially_available
	assert promise.state() == .pending

	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert request.state() == .completely_available
	assert !image.is_image_pending()
	assert image.natural_width() == 200
	assert image.natural_height() == 100
	assert promise.state() == .pending

	event_loop.process()
	assert promise.state() == .fulfilled
}

fn test_image_pending_state_distinguishes_sources_from_broken_requests() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut source_less := HTMLImageElementModel.create(document, document.base_url())
	assert !source_less.is_image_pending()

	source_less.set_src('/pending.png')
	assert source_less.is_image_pending()
	mut request := source_less.current_request()
	request.set_state(.broken)
	assert !source_less.is_image_pending()

	mut srcset_image := HTMLImageElementModel.create(document, document.base_url())
	srcset_image.set_srcset('/candidate.png 1x')
	assert srcset_image.is_image_pending()
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

fn test_image_model_coordinates_use_attached_element_layout_geometry() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut image_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(image_element.as_node()) or { panic(err) }
	image := unsafe { &dom.HTMLImageElement(image_element) }
	model := html_image_element_model_for_dom_element(image)
	mut image_node := image_element.as_node()
	mut image_layout_node := &dom.LayoutNode{
		dom_node_:     image_node
		has_geometry_: true
		border_box_:   dom.Rect{27, 43, 80, 40}
	}
	image_node.set_layout_node(image_layout_node)

	document.needs_accumulated_visual_contexts_update = true
	assert model.x() == 27
	assert !document.needs_accumulated_visual_contexts_update
	document.needs_accumulated_visual_contexts_update = true
	assert model.y() == 43
	assert !document.needs_accumulated_visual_contexts_update

	// A layout node without committed geometry is not a box. Its coordinates
	// are zero and querying them must not force paint-property resolution.
	image_layout_node.has_geometry_ = false
	document.needs_accumulated_visual_contexts_update = true
	assert model.x() == 0
	assert model.y() == 0
	assert document.needs_accumulated_visual_contexts_update

	synthetic_model := HTMLImageElementModel.create(document, document.base_url())
	assert synthetic_model.x() == 0
	assert synthetic_model.y() == 0
}

fn test_concrete_image_element_picture_source_requests_roles_and_dimensions() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut navigable := &dom.Navigable{
		active_document_:          document
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
