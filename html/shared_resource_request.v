// Copyright (c) 2023, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SharedResourceRequest.{h,cpp} and ImageRequest.{h,cpp}.
// Network fetching and image decoding enter through explicit host callbacks;
// ownership, sharing, state transitions, and callback delivery live here.
@[has_globals]
module html

import dom
import platform

pub enum SharedResourceRequestState {
	new_
	fetching
	finished
	failed
}

pub type SharedResourceCallback = fn ()

pub type SharedResourceFetchCallback = fn (&SharedResourceRequest, dom.URL)

pub type SharedResourceDecodeCallback = fn (dom.URL, string, []u8) !DecodedImageData

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
	state_              SharedResourceRequestState
	callbacks           []SharedResourceCallbacks
	image_data_         ?SharedResourceImageData
	load_event_delay    bool
	fetch_controller    voidptr
	decode_callback     ?SharedResourceDecodeCallback
	cache_touch_serial_ u64
}

__global (
	html_shared_resource_requests                  map[string]&SharedResourceRequest
	html_shared_resource_memory_cache_touch_serial u64
	// Native-storage documents whose retirement removes their entries.
	html_shared_resource_request_owners map[voidptr]bool
)

fn shared_resource_request_key(document &dom.Document, url dom.URL) string {
	return '${u64(voidptr(document))}\x00${url.value}'
}

pub fn SharedResourceRequest.get_or_create(document &dom.Document, url dom.URL) &SharedResourceRequest {
	key := shared_resource_request_key(document, url)
	if request := html_shared_resource_requests[key] {
		request.touch_memory_cache_entry()
		return request
	}
	request := &SharedResourceRequest{
		url:      url
		document: document
	}
	request.touch_memory_cache_entry()
	// Upstream keeps this map on the Document. This one is process-wide, so its
	// buckets and keys must not grow inside the caller's document arena, and a
	// document's entries leave it when that document's storage is released.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	html_shared_resource_requests[key] = request
	register_shared_resource_request_owner(document)
	return request
}

fn register_shared_resource_request_owner(document &dom.Document) {
	if document.native_storage() == unsafe { nil } { return }
	owner := voidptr(document)
	if owner in html_shared_resource_request_owners { return }
	html_shared_resource_request_owners[owner] = true
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.add_native_storage_cleanup(fn [owner] () {
		remove_shared_resource_requests_for_document(owner)
	})
}

fn remove_shared_resource_requests_for_document(owner voidptr) {
	html_shared_resource_request_owners.delete(owner)
	prefix := '${u64(owner)}\x00'
	mut keys := []string{}
	for key, _ in html_shared_resource_requests {
		if key.starts_with(prefix) { keys << key }
	}
	for key in keys { html_shared_resource_requests.delete(key) }
}

pub fn shared_resource_request_for_document_and_url(document &dom.Document, url dom.URL) ?&SharedResourceRequest {
	return html_shared_resource_requests[shared_resource_request_key(document, url)] or { none }
}

pub fn (mut request SharedResourceRequest) finalize() {
	html_shared_resource_requests.delete(shared_resource_request_key(request.document, request.url))
}

pub fn (request &SharedResourceRequest) image_data() ?SharedResourceImageData {
	return request.image_data_
}

pub fn (request &SharedResourceRequest) can_be_pruned_from_memory_cache() bool {
	image_data := request.image_data_ or { return false }
	return !image_data.data.has_clients()
}

pub fn (request &SharedResourceRequest) cache_touch_serial() u64 {
	return request.cache_touch_serial_
}

pub fn (request &SharedResourceRequest) touch_memory_cache_entry() {
	mut mutable_request := unsafe { &SharedResourceRequest(request) }
	html_shared_resource_memory_cache_touch_serial++
	mutable_request.cache_touch_serial_ = html_shared_resource_memory_cache_touch_serial
}

pub fn (request &SharedResourceRequest) url() dom.URL {
	return request.url
}

pub fn (request &SharedResourceRequest) fetch_controller() voidptr {
	return request.fetch_controller
}

pub fn (mut request SharedResourceRequest) set_fetch_controller(controller voidptr) {
	request.fetch_controller = controller
}

pub fn (mut request SharedResourceRequest) set_decode_callback(callback ?SharedResourceDecodeCallback) {
	request.decode_callback = callback
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
	prune_shared_resource_requests_for_document(request.document, 8 * 1024 * 1024, 96)
}

pub fn (mut request SharedResourceRequest) handle_successful_fetch(url dom.URL, mime_type string, data []u8, image_data_is_cors_cross_origin bool) {
	decode := request.decode_callback or {
		request.handle_failed_fetch()
		return
	}
	effective_mime_type := shared_resource_effective_image_mime_type(url, mime_type)
	image_data := decode(url, effective_mime_type, data.clone()) or {
		request.handle_failed_fetch()
		return
	}
	image_data.set_is_cors_cross_origin(image_data_is_cors_cross_origin)
	request.handle_successful_resource_load(image_data)
}

pub fn shared_resource_effective_image_mime_type(url dom.URL, mime_type string) string {
	if mime_type == '' && url.basename().ends_with('.svg') {
		return 'image/svg+xml'
	}
	return mime_type
}

fn shared_resource_request_prunable_size_and_count(document &dom.Document) (uint, uint) {
	mut size := uint(0)
	mut count := uint(0)
	for _, request in html_shared_resource_requests {
		if request.document != document || !request.can_be_pruned_from_memory_cache() {
			continue
		}
		image_data := request.image_data_ or { continue }
		image_size := image_data.data.external_memory_size()
		if uint(-1) - size < image_size {
			size = uint(-1)
		} else {
			size += image_size
		}
		count++
	}
	return size, count
}

pub fn prune_shared_resource_requests_for_document(document &dom.Document, external_memory_limit uint, count_limit uint) {
	mut size, mut count := shared_resource_request_prunable_size_and_count(document)
	for size > external_memory_limit || count > count_limit {
		mut least_recently_used_key := ''
		mut least_recently_used_serial := u64(-1)
		for key, request in html_shared_resource_requests {
			if request.document != document || !request.can_be_pruned_from_memory_cache()
				|| request.cache_touch_serial() >= least_recently_used_serial {
				continue
			}
			least_recently_used_key = key
			least_recently_used_serial = request.cache_touch_serial()
		}
		if least_recently_used_key == '' {
			break
		}
		html_shared_resource_requests.delete(least_recently_used_key)
		new_size, new_count := shared_resource_request_prunable_size_and_count(document)
		if new_size == size && new_count == count {
			break
		}
		size = new_size
		count = new_count
	}
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

// https://html.spec.whatwg.org/multipage/images.html#prepare-an-image-for-presentation
pub fn (mut request ImageRequest) prepare_for_presentation(image &dom.HTMLImageElement) {
	// The current upstream implementation has no executable steps yet: EXIF
	// extraction, physical dimensions, and presentation adjustment are FIXMEs.
	_ = image
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
