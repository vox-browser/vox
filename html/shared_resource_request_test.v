@[has_globals]
module html

import dom

__global (
	shared_resource_test_finished    int
	shared_resource_test_failed      int
	shared_resource_test_decode_url  string
	shared_resource_test_decode_mime string
)

fn shared_resource_test_on_finish() {
	shared_resource_test_finished++
}

fn shared_resource_test_on_fail() {
	shared_resource_test_failed++
}

fn shared_resource_test_fetch_success(request &SharedResourceRequest, _ dom.URL) {
	mut mutable_request := unsafe { &SharedResourceRequest(request) }
	bitmap := &dom.Bitmap_{
		width:  2
		height: 3
	}
	mutable_request.handle_successful_resource_load(BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) },
	], 0, false))
}

fn shared_resource_test_fetch_failure(request &SharedResourceRequest, _ dom.URL) {
	mut mutable_request := unsafe { &SharedResourceRequest(request) }
	mutable_request.handle_failed_fetch()
}

fn shared_resource_test_decode(url dom.URL, mime_type string, bytes []u8) !DecodedImageData {
	shared_resource_test_decode_url = url.serialize()
	shared_resource_test_decode_mime = mime_type
	if bytes.len == 0 {
		return error('empty image')
	}
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width:  4
				height: 5
				data:   bytes.clone()
			})
		},
	], 0, false)
}

fn shared_resource_test_client_update() {}

fn shared_resource_test_image_data(bytes []u8) &BitmapDecodedImageData {
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width:  1
				height: 1
				data:   bytes.clone()
			})
		},
	], 0, false)
}

fn test_shared_resource_request_shares_state_and_callbacks() {
	unsafe {
		shared_resource_test_finished = 0
		shared_resource_test_failed = 0
	}
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	url := dom.URL{
		value: 'https://example.test/image.png'
	}
	mut request := SharedResourceRequest.get_or_create(document, url)
	assert request == SharedResourceRequest.get_or_create(document, url)
	assert request.needs_fetching()
	request.add_callbacks(shared_resource_test_on_finish, shared_resource_test_on_fail)
	request.fetch_resource(shared_resource_test_fetch_success)
	assert request.state() == .finished
	assert !request.is_fetching()
	assert shared_resource_test_finished == 1
	assert shared_resource_test_failed == 0
	assert request.image_data()?.data.frame_count() == 1
	request.add_callbacks(shared_resource_test_on_finish, none)
	assert shared_resource_test_finished == 2
}

fn test_image_request_state_fetch_and_abort() {
	unsafe {
		shared_resource_test_failed = 0
	}
	document := dom.Document.create(dom.URL{ value: 'https://example.test/base/' })
	mut request := ImageRequest.create(document)
	assert request.state() == .unavailable
	assert request.current_pixel_density() == 1
	request.set_current_url('broken.png')
	assert request.current_url() == 'broken.png'
	request.add_callbacks(none, shared_resource_test_on_fail)!
	request.fetch_image(shared_resource_test_fetch_failure)!
	assert shared_resource_test_failed == 1
	assert request.shared_resource_request()?.state() == .failed
	request.set_state(.partially_available)
	assert request.is_available()
	image := &dom.HTMLImageElement{}
	request.prepare_for_presentation(image)
	assert request.state() == .partially_available
	request.set_image_data(SharedResourceImageData{
		data: BitmapDecodedImageData.create([], 0, false)
	})
	abort_the_image_request(request)
	assert request.image_data() == none
}

fn test_shared_resource_request_handle_successful_fetch_decodes_and_finishes() {
	unsafe {
		shared_resource_test_decode_url = ''
		shared_resource_test_decode_mime = ''
	}
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	url := dom.URL{ value: 'https://example.test/image.bin' }
	mut request := SharedResourceRequest.get_or_create(document, url)
	request.set_decode_callback(shared_resource_test_decode)
	request.handle_successful_fetch(url, 'image/test', [u8(1), 2, 3], true)
	assert request.state() == .finished
	assert request.image_data()?.data.intrinsic_width()? == 4
	assert request.image_data()?.data.is_cors_cross_origin()
	assert shared_resource_test_decode_url == url.serialize()
	assert shared_resource_test_decode_mime == 'image/test'
}

fn test_shared_resource_request_prefers_response_mime_type_over_svg_suffix() {
	url := dom.URL{ value: 'https://example.test/transformed.svg' }
	assert shared_resource_effective_image_mime_type(url, 'image/webp') == 'image/webp'
	assert shared_resource_effective_image_mime_type(url, '') == 'image/svg+xml'
	assert shared_resource_effective_image_mime_type(dom.URL{
		value: 'https://example.test/image.webp'
	}, '') == ''
}

fn test_shared_resource_request_pruning_uses_lru_and_preserves_live_images() {
	document := dom.Document.create(dom.URL{ value: 'https://cache-pruning.test/' })
	old_url := dom.URL{ value: 'https://cache-pruning.test/old.png' }
	untouched_url := dom.URL{ value: 'https://cache-pruning.test/untouched.png' }
	protected_url := dom.URL{ value: 'https://cache-pruning.test/protected.png' }
	old_image := shared_resource_test_image_data([u8(1), 2, 3])
	untouched_image := shared_resource_test_image_data([u8(1), 2, 3, 4])
	protected_image := shared_resource_test_image_data([u8(1), 2, 3, 4, 5])
	mut old_request := SharedResourceRequest.get_or_create(document, old_url)
	old_request.handle_successful_resource_load(old_image)
	mut untouched_request := SharedResourceRequest.get_or_create(document, untouched_url)
	untouched_request.handle_successful_resource_load(untouched_image)
	mut protected_request := SharedResourceRequest.get_or_create(document, protected_url)
	protected_request.handle_successful_resource_load(protected_image)
	assert old_request.can_be_pruned_from_memory_cache()
	decoded_image_data_register_client(protected_image, 92, shared_resource_test_client_update)
	assert !protected_request.can_be_pruned_from_memory_cache()

	old_serial := old_request.cache_touch_serial()
	assert SharedResourceRequest.get_or_create(document, old_url) == old_request
	assert old_request.cache_touch_serial() > old_serial
	prune_shared_resource_requests_for_document(document, uint(-1), 1)
	assert shared_resource_request_for_document_and_url(document, old_url) != none
	assert shared_resource_request_for_document_and_url(document, untouched_url) == none
	assert shared_resource_request_for_document_and_url(document, protected_url) != none

	decoded_image_data_unregister_client(protected_image, 92)
	assert protected_request.can_be_pruned_from_memory_cache()
	prune_shared_resource_requests_for_document(document, 0, 0)
	assert shared_resource_request_for_document_and_url(document, old_url) == none
	assert shared_resource_request_for_document_and_url(document, protected_url) == none
}
