module html

import dom

fn async_image_test_active_document() &dom.Document {
	document := dom.Document.create(dom.URL{value: 'https://async-image.test/'})
	_ = WindowModel.create_top_level(document, none, 'async-image-test') or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_document_type(.html)
	mutable_document.set_cached_navigable(&dom.Navigable{active_document_: document, is_top_level_traversable_: true})
	return document
}

@[heap]
struct PendingImageTestFetches {
mut:
	callbacks []HTMLImageFetchCompletion
}

fn (pending &PendingImageTestFetches) hook() HTMLImageAsyncFetchHook {
	return fn [pending] (_ dom.URL, complete HTMLImageFetchCompletion) {
		mut requests := unsafe { &PendingImageTestFetches(pending) }
		requests.callbacks << complete
	}
}

fn async_test_image_data(width int) DecodedImageData {
	return BitmapDecodedImageData.create([BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: width
			height: 1
			pitch: width * 4
			data: []u8{len: width * 4}
		})
	}], 0, false)
}

fn test_async_image_remains_pending_until_completion_and_delays_document_load() {
	mut document := async_image_test_active_document()
	defer { document.finalize() }
	mut pending := &PendingImageTestFetches{}
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_async_fetch_hook(pending.hook())
	image.set_src('/thumbnail.png')
	image.update_the_image_data(false, false)
	assert image.has_fetch_hook() && image.has_pending_request()
	assert image.is_image_pending() && !image.complete()
	assert document.anything_is_delaying_the_load_event()
	assert image.event_count('load') == 0 && image.event_count('error') == 0
	pending.callbacks[0](async_test_image_data(3))
	assert image.complete() && !image.is_image_pending()
	assert image.natural_width() == 3
	assert image.event_count('load') == 1
	assert !document.anything_is_delaying_the_load_event()
	pending.callbacks[0](async_test_image_data(9))
	assert image.natural_width() == 3 && image.event_count('load') == 1
}

fn test_late_async_image_response_cannot_replace_newer_source_or_release_its_load_delay() {
	mut document := async_image_test_active_document()
	defer { document.finalize() }
	mut pending := &PendingImageTestFetches{}
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_async_fetch_hook(pending.hook())
	image.set_src('/old.png')
	image.update_the_image_data(false, false)
	image.set_src('/new.png')
	image.update_the_image_data(false, false)
	pending.callbacks[0](async_test_image_data(8))
	assert !image.complete() && image.natural_width() == 0
	assert document.anything_is_delaying_the_load_event()
	assert image.event_count('load') == 0
	pending.callbacks[1](async_test_image_data(4))
	assert image.complete() && image.natural_width() == 4
	assert image.current_src().ends_with('/new.png')
	assert image.event_count('load') == 1
	assert !document.anything_is_delaying_the_load_event()
}

fn test_async_image_failure_then_retry_and_source_removal_keep_request_state_consistent() {
	mut document := async_image_test_active_document()
	defer { document.finalize() }
	mut pending := &PendingImageTestFetches{}
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_async_fetch_hook(pending.hook())
	image.set_src('/thumbnail.png')
	image.update_the_image_data(false, false)
	pending.callbacks[0](none)
	assert image.complete() && image.current_request().state() == .broken
	assert image.event_count('error') == 1
	assert !document.anything_is_delaying_the_load_event()
	image.update_the_image_data(false, false)
	assert !image.complete() && image.is_image_pending()
	image.set_src(none)
	image.update_the_image_data(false, false)
	assert image.complete() && !document.anything_is_delaying_the_load_event()
	pending.callbacks[1](async_test_image_data(7))
	assert image.natural_width() == 0 && image.event_count('load') == 0
}

fn test_async_cross_origin_no_cors_pixels_remain_opaque() {
	mut document := async_image_test_active_document()
	defer { document.finalize() }
	mut pending := &PendingImageTestFetches{}
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_async_fetch_hook(pending.hook())
	image.set_src('https://other.test/image.png')
	image.update_the_image_data(false, false)
	pending.callbacks[0](async_test_image_data(1))
	assert image.decoded_image_data()?.is_cors_cross_origin()
}

fn test_adopting_pending_async_image_restarts_against_new_owner_and_ignores_old_response() {
	mut document := async_image_test_active_document()
	mut replacement := dom.Document.create(dom.URL{value: 'https://replacement-async-image.test/'})
	replacement.set_document_type(.html)
	_ = WindowModel.create_top_level(replacement, none, 'replacement-image-test')!
	replacement.set_cached_navigable(&dom.Navigable{active_document_: replacement, is_top_level_traversable_: true})
	defer { document.finalize(); replacement.finalize() }
	mut element := document.create_element('img')!
	element.set_attribute_value('src', 'thumbnail.png')
	mut pending := &PendingImageTestFetches{}
	image_element := unsafe { &dom.HTMLImageElement(element) }
	mut image := html_image_element_model_for_dom_element(image_element)
	image.set_async_fetch_hook(pending.hook())
	assert document.is_fully_active()
	assert image.src() == 'thumbnail.png'
	assert image.has_fetch_hook()
	image.update_the_image_data(false, false)
	assert pending.callbacks.len == 1
	replacement.adopt_node(element.as_node())
	assert pending.callbacks.len == 2
	assert !document.anything_is_delaying_the_load_event()
	assert replacement.anything_is_delaying_the_load_event()
	pending.callbacks[0](async_test_image_data(9))
	assert !image.complete() && image.natural_width() == 0
	pending.callbacks[1](async_test_image_data(2))
	assert image.complete() && image.natural_width() == 2
	assert image.current_src() == 'https://replacement-async-image.test/thumbnail.png'
	assert !replacement.anything_is_delaying_the_load_event()
}

fn test_returning_to_decoded_source_cancels_pending_replacement_and_releases_load_delay() {
	mut document := async_image_test_active_document()
	defer { document.finalize() }
	mut pending := &PendingImageTestFetches{}
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_async_fetch_hook(pending.hook())
	image.set_src('/original.png')
	image.update_the_image_data(false, false)
	pending.callbacks[0](async_test_image_data(3))
	image.set_src('/replacement.png')
	image.update_the_image_data(false, false)
	assert !image.complete()
	image.set_src('/original.png')
	image.update_the_image_data(false, false)
	assert image.complete() && image.natural_width() == 3
	assert !document.anything_is_delaying_the_load_event()
	pending.callbacks[1](async_test_image_data(9))
	assert image.complete() && image.natural_width() == 3
	assert image.current_src().ends_with('/original.png')
}
