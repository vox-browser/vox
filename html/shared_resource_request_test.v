@[has_globals]
module html

import dom

__global (
	shared_resource_test_finished int
	shared_resource_test_failed   int
)

fn shared_resource_test_on_finish() {
	shared_resource_test_finished++
}

fn shared_resource_test_on_fail() {
	shared_resource_test_failed++
}

fn shared_resource_test_fetch_success(request &SharedResourceRequest, _ dom.URL) {
	mut mutable_request := unsafe { &SharedResourceRequest(request) }
	bitmap := &dom.ImmutableBitmap_{
		width:  2
		height: 3
	}
	mutable_request.handle_successful_resource_load(BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ bitmap: bitmap },
	], 0, false))
}

fn shared_resource_test_fetch_failure(request &SharedResourceRequest, _ dom.URL) {
	mut mutable_request := unsafe { &SharedResourceRequest(request) }
	mutable_request.handle_failed_fetch()
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
	request.set_image_data(SharedResourceImageData{
		data: BitmapDecodedImageData.create([], 0, false)
	})
	abort_the_image_request(request)
	assert request.image_data() == none
}
