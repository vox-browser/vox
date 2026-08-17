// Copyright (c) 2023, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SharedResourceRequest.{h,cpp} and ImageRequest.{h,cpp}.
// Network fetching and image decoding enter through explicit host callbacks;
// ownership, sharing, state transitions, and callback delivery live here.
@[has_globals]
module html

import dom

pub enum SharedResourceRequestState {
	new_
	fetching
	finished
	failed
}

pub type SharedResourceCallback = fn ()

pub type SharedResourceFetchCallback = fn (&SharedResourceRequest, dom.URL)

pub struct SharedResourceCallbacks {
	on_finish ?SharedResourceCallback
	on_fail   ?SharedResourceCallback
}

pub struct SharedResourceImageData {
pub:
	data DecodedImageData
}

@[heap]
pub struct SharedResourceRequest {
pub:
	url      dom.URL
	document &dom.Document
mut:
	state_           SharedResourceRequestState
	callbacks        []SharedResourceCallbacks
	image_data_      ?SharedResourceImageData
	load_event_delay bool
	fetch_controller voidptr
}

__global html_shared_resource_requests map[string]&SharedResourceRequest

fn shared_resource_request_key(document &dom.Document, url dom.URL) string {
	return '${u64(voidptr(document))}\x00${url.value}'
}

pub fn SharedResourceRequest.get_or_create(document &dom.Document, url dom.URL) &SharedResourceRequest {
	key := shared_resource_request_key(document, url)
	if request := html_shared_resource_requests[key] {
		return request
	}
	request := &SharedResourceRequest{
		url:      url
		document: document
	}
	html_shared_resource_requests[key] = request
	return request
}

pub fn (mut request SharedResourceRequest) finalize() {
	html_shared_resource_requests.delete(shared_resource_request_key(request.document, request.url))
}

pub fn (request &SharedResourceRequest) image_data() ?SharedResourceImageData {
	return request.image_data_
}

pub fn (request &SharedResourceRequest) fetch_controller() voidptr {
	return request.fetch_controller
}

pub fn (mut request SharedResourceRequest) set_fetch_controller(controller voidptr) {
	request.fetch_controller = controller
}

pub fn (mut request SharedResourceRequest) fetch_resource(fetch SharedResourceFetchCallback) {
	if request.state_ != .new_ {
		return
	}
	request.state_ = .fetching
	request.load_event_delay = true
	fetch(request, request.url)
}

pub fn (mut request SharedResourceRequest) add_callbacks(on_finish ?SharedResourceCallback, on_fail ?SharedResourceCallback) {
	if request.state_ == .finished {
		if callback := on_finish { callback() }
		return
	}
	if request.state_ == .failed {
		if callback := on_fail { callback() }
		return
	}
	request.callbacks << SharedResourceCallbacks{
		on_finish: on_finish
		on_fail:   on_fail
	}
}

pub fn (mut request SharedResourceRequest) handle_failed_fetch() {
	request.state_ = .failed
	request.load_event_delay = false
	for callbacks in request.callbacks {
		if callback := callbacks.on_fail { callback() }
	}
	request.callbacks.clear()
}

pub fn (mut request SharedResourceRequest) handle_successful_resource_load(image_data DecodedImageData) {
	request.image_data_ = SharedResourceImageData{
		data: image_data
	}
	request.state_ = .finished
	request.load_event_delay = false
	for callbacks in request.callbacks {
		if callback := callbacks.on_finish { callback() }
	}
	request.callbacks.clear()
}

pub fn (request &SharedResourceRequest) needs_fetching() bool {
	return request.state_ == .new_
}

pub fn (request &SharedResourceRequest) is_fetching() bool {
	return request.state_ == .fetching
}

pub fn (request &SharedResourceRequest) state() SharedResourceRequestState {
	return request.state_
}

pub enum ImageRequestState {
	unavailable
	partially_available
	completely_available
	broken
}

pub struct ImageRequestFloatSize {
pub:
	width  f64
	height f64
}

@[heap]
pub struct ImageRequest {
pub:
	document &dom.Document
mut:
	state_                                  ImageRequestState
	current_url_                            string
	image_data_                             ?SharedResourceImageData
	current_pixel_density_                  f32 = 1
	preferred_density_corrected_dimensions_ ?ImageRequestFloatSize
	shared_resource_request_                ?&SharedResourceRequest
}

pub fn ImageRequest.create(document &dom.Document) &ImageRequest {
	return &ImageRequest{
		document: document
	}
}

pub fn (request &ImageRequest) is_available() bool {
	return request.state_ in [.partially_available, .completely_available]
}

pub fn (request &ImageRequest) is_fetching() bool {
	resource_request := request.shared_resource_request_ or { return false }
	return resource_request.is_fetching()
}

pub fn (request &ImageRequest) state() ImageRequestState {
	return request.state_
}

pub fn (mut request ImageRequest) set_state(state ImageRequestState) {
	request.state_ = state
}

pub fn (request &ImageRequest) current_url() string {
	return request.current_url_
}

pub fn (mut request ImageRequest) set_current_url(url string) {
	request.current_url_ = url
	parsed := dom.dom_url_parse(url, request.document.base_url(), 'UTF-8') or {
		request.shared_resource_request_ = none
		return
	}
	request.shared_resource_request_ = SharedResourceRequest.get_or_create(request.document, parsed)
}

pub fn (request &ImageRequest) image_data() ?SharedResourceImageData {
	return request.image_data_
}

pub fn (mut request ImageRequest) set_image_data(data ?SharedResourceImageData) {
	request.image_data_ = data
}

pub fn (request &ImageRequest) current_pixel_density() f32 {
	return request.current_pixel_density_
}

pub fn (mut request ImageRequest) set_current_pixel_density(density f32) {
	request.current_pixel_density_ = density
}

pub fn (request &ImageRequest) preferred_density_corrected_dimensions() ?ImageRequestFloatSize {
	return request.preferred_density_corrected_dimensions_
}

pub fn (mut request ImageRequest) set_preferred_density_corrected_dimensions(dimensions ?ImageRequestFloatSize) {
	request.preferred_density_corrected_dimensions_ = dimensions
}

pub fn (mut request ImageRequest) fetch_image(fetch SharedResourceFetchCallback) ! {
	mut resource_request := request.shared_resource_request_ or {
		return error('ImageRequest has no valid current URL')
	}

	resource_request.fetch_resource(fetch)
}

pub fn (mut request ImageRequest) add_callbacks(on_finish ?SharedResourceCallback, on_fail ?SharedResourceCallback) ! {
	mut resource_request := request.shared_resource_request_ or {
		return error('ImageRequest has no valid current URL')
	}

	resource_request.add_callbacks(on_finish, on_fail)
}

pub fn (request &ImageRequest) shared_resource_request() ?&SharedResourceRequest {
	return request.shared_resource_request_
}

pub fn abort_the_image_request(request ?&ImageRequest) {
	mut image_request := request or { return }
	image_request.set_image_data(none)
}
