module html

import dom
import fetch

@[heap]
struct PosterFetchRequestProbe {
mut:
	requests []&fetch.Request
	legacy_urls []string
	published []int
	independent ?dom.DocumentLoadEventDelayer
}

fn poster_fetch_request_document(address string, markup string) !&dom.Document {
	url := dom.URL{value: address}
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn poster_fetch_request_video(document &dom.Document) (&dom.Element, &HTMLVideoElementModel) {
	element := document.get_element_by_id('video') or { panic('missing poster request video') }
	return element, html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
}

fn poster_fetch_request_bitmap(width int) &dom.Bitmap_ {
	return &dom.Bitmap_{width: width, height: 7, pitch: width * 4, data: []u8{len: width * 7 * 4}}
}

fn (settings &EnvironmentSettingsObject) poster_request_settings_identity() voidptr {
	return voidptr(settings)
}

fn poster_fetch_request_check(request &fetch.Request, document &dom.Document, address string) {
	assert request.url().serialize() == address && request.current_url().serialize() == address
	assert request.url_list.len == 1 && request.method == 'GET'
	assert (request.destination or { panic('missing poster destination') }) == .image && (request.initiator_type or { panic('missing poster initiator') }) == .video
	assert request.credentials_mode == .include && request.use_url_credentials
	assert request.mode == .no_cors && request.redirect_mode == .follow
	assert request.client_present && request.client_is_window
	client := request.client or { panic('missing actual poster request client') }
	if client is EnvironmentSettingsObject {
		assert client.poster_request_settings_identity() == document.relevant_settings_object()
		assert voidptr(client.responsible_document() or { panic('missing client document') }) == voidptr(document)
	} else {
		panic('poster client must be the actual environment settings object')
	}
	assert (client.fetch_request_client_document_url() or { panic('missing client URL') }) == document.url
	assert client.fetch_request_client_origin() == document.origin()
}

fn test_poster_request_uses_the_source_metadata_and_actual_settings_before_transport() {
	for crossorigin in ['', ' crossorigin="anonymous"', ' crossorigin="use-credentials"'] {
		mut document := poster_fetch_request_document('https://poster-request.example/base/page.html',
			'<!doctype html><video id="video" preload="none"${crossorigin}></video>')!
		defer { document.finalize() }
		mut element, mut video := poster_fetch_request_video(document)
		seen := &PosterFetchRequestProbe{}
		video.set_poster_request_fetch_hook(fn [document, seen] (request &fetch.Request) !&dom.Bitmap_ {
			poster_fetch_request_check(request, document, 'https://alice:secret@images.example/cover.png?x=%20#frame')
			assert document.anything_is_delaying_the_load_event()
			mut probe := unsafe { &PosterFetchRequestProbe(seen) }
			probe.requests << request
			return poster_fetch_request_bitmap(13)
		})
		element.set_attribute_value('poster', 'https://alice:secret@images.example/cover.png?x=%20#frame')
		assert seen.requests.len == 1 && video.poster_frame()?.width == 13
		assert video.natural_element_size()? == VideoDimensions{13, 7}
		assert !document.anything_is_delaying_the_load_event()
		assert video.media.paused() && video.media.current_src() == ''
		assert video.media.ready_state() == .have_nothing && video.media.network_state() == .empty
		for name in ['loadstart', 'play', 'playing', 'error', 'resize'] { assert video.media.event_count(name) == 0 }
	}
}

fn test_poster_request_reprocessing_uses_the_adopted_document_base_and_client() {
	mut original := poster_fetch_request_document('https://poster-request-old.example/base/page.html',
		'<!doctype html><base href="https://old-images.example/"><video id="video"></video>')!
	mut destination := poster_fetch_request_document('https://poster-request-new.example/next/page.html',
		'<!doctype html><base id="base" href="https://new-images.example/covers/"><body></body>')!
	defer { original.finalize(); destination.finalize() }
	mut element, mut video := poster_fetch_request_video(original)
	seen := &PosterFetchRequestProbe{}
	video.set_poster_request_fetch_hook(fn [element, seen] (request &fetch.Request) !&dom.Bitmap_ {
		mut probe := unsafe { &PosterFetchRequestProbe(seen) }
		address := if probe.requests.len == 0 { 'https://old-images.example/frame.png' } else {
			'https://new-images.example/current/frame.png'
		}
		poster_fetch_request_check(request, element.document(), address)
		probe.requests << request
		return poster_fetch_request_bitmap(13)
	})
	element.set_attribute_value('poster', 'frame.png')
	first := video.poster_frame()?
	destination.adopt_node(element.as_node())
	assert seen.requests.len == 1 && voidptr(video.poster_frame()?) == voidptr(first)
	mut base := destination.get_element_by_id('base') or { panic('missing current poster base') }
	base.set_attribute_value('href', 'https://new-images.example/current/')
	element.set_attribute_value('poster', 'frame.png')
	assert seen.requests.len == 2 && voidptr(seen.requests[0]) != voidptr(seen.requests[1])
	poster_fetch_request_check(seen.requests[0], original, 'https://old-images.example/frame.png')
	poster_fetch_request_check(seen.requests[1], destination, 'https://new-images.example/current/frame.png')
	assert !original.anything_is_delaying_the_load_event() && !destination.anything_is_delaying_the_load_event()
}

fn test_typed_poster_transport_reentry_keeps_the_latest_frame_and_independent_load_delay() {
	for outer_fails in [false, true] {
		mut document := poster_fetch_request_document('https://poster-request-reentry.example/base/page.html',
			'<!doctype html><video id="video"></video>')!
		defer { document.finalize() }
		mut element, mut video := poster_fetch_request_video(document)
		seen := &PosterFetchRequestProbe{}
		video.set_paint_facts_update_hook(fn [seen] (owner &dom.HTMLVideoElement) {
			model := html_video_element_model_for_dom_element(owner)
			mut probe := unsafe { &PosterFetchRequestProbe(seen) }
			probe.published << if frame := model.poster_frame() { frame.width } else { 0 }
		})
		video.set_poster_request_fetch_hook(fn [document, element, seen, outer_fails] (request &fetch.Request) !&dom.Bitmap_ {
			poster_fetch_request_check(request, document, request.url().serialize())
			assert document.anything_is_delaying_the_load_event()
			mut probe := unsafe { &PosterFetchRequestProbe(seen) }
			probe.requests << request
			if request.url().serialize().ends_with('/inner.png') { return poster_fetch_request_bitmap(13) }
			mut owner := unsafe { &dom.Element(element) }
			owner.set_attribute_value('poster', 'inner.png')
			assert !document.anything_is_delaying_the_load_event()
			mut current := unsafe { &dom.Document(document) }
			probe.independent = dom.DocumentLoadEventDelayer.new(mut current)
			if outer_fails { return error('superseded typed poster failure') }
			return poster_fetch_request_bitmap(31)
		})
		element.set_attribute_value('poster', 'outer.png')
		assert seen.requests.len == 2 && seen.published == [13]
		assert video.poster_frame()?.width == 13 && video.poster_? == 'inner.png'
		assert document.anything_is_delaying_the_load_event()
		mut probe := unsafe { &PosterFetchRequestProbe(seen) }
		if mut independent := probe.independent { independent.finish() }
		assert !document.anything_is_delaying_the_load_event()
	}
}

fn test_poster_request_transport_priority_legacy_fallback_and_absent_client_boundaries() {
	mut document := poster_fetch_request_document('https://poster-request-adapter.example/base/page.html',
		'<!doctype html><video id="video"></video>')!
	defer { document.finalize() }
	mut element, mut video := poster_fetch_request_video(document)
	seen := &PosterFetchRequestProbe{}
	video.set_poster_fetch_hook(fn [seen] (url dom.URL) !&dom.Bitmap_ {
		mut probe := unsafe { &PosterFetchRequestProbe(seen) }
		probe.legacy_urls << url.serialize()
		return poster_fetch_request_bitmap(19)
	})
	video.set_poster_request_fetch_hook(fn [document, seen] (request &fetch.Request) !&dom.Bitmap_ {
		poster_fetch_request_check(request, document, request.url().serialize())
		mut probe := unsafe { &PosterFetchRequestProbe(seen) }
		probe.requests << request
		if request.url().serialize().ends_with('/failed.png') { return error('typed poster failure') }
		return poster_fetch_request_bitmap(13)
	})
	element.set_attribute_value('poster', '')
	element.set_attribute_value('poster', 'http://[invalid')
	element.remove_attribute('poster')
	assert seen.requests == [] && seen.legacy_urls == [] && !document.anything_is_delaying_the_load_event()
	element.set_attribute_value('poster', 'typed.png')
	assert seen.requests.len == 1 && seen.legacy_urls == [] && video.poster_frame()?.width == 13
	element.set_attribute_value('poster', 'failed.png')
	assert seen.requests.len == 2 && seen.legacy_urls == [] && video.poster_frame() == none
	assert !document.anything_is_delaying_the_load_event()
	video.set_poster_request_fetch_hook(none)
	element.set_attribute_value('poster', 'legacy.png')
	assert seen.requests.len == 2 && seen.legacy_urls == ['https://poster-request-adapter.example/base/legacy.png']
	assert video.poster_frame()?.width == 19
	video.set_poster_fetch_hook(none)
	element.set_attribute_value('poster', 'no-transport.png')
	assert video.poster_frame() == none && seen.requests.len == 2 && seen.legacy_urls.len == 1
	assert !document.anything_is_delaying_the_load_event()

	base := dom.URL{value: 'https://poster-request-standalone.example/base/page.html'}
	mut media := HTMLMediaElement.create(none, base)
	defer { media.remove_queued_media_element_tasks(); media.finalize() }
	mut standalone := HTMLVideoElementModel.create(media, base)
	standalone.set_poster_request_fetch_hook(fn [seen] (request &fetch.Request) !&dom.Bitmap_ {
		assert request.url().serialize() == 'https://poster-request-standalone.example/base/frame.png'
		assert request.client == none && !request.client_present && !request.client_is_window
		assert (request.destination or { panic('missing poster destination') }) == .image && (request.initiator_type or { panic('missing poster initiator') }) == .video
		assert request.credentials_mode == .include && request.use_url_credentials
		mut probe := unsafe { &PosterFetchRequestProbe(seen) }
		probe.requests << request
		return poster_fetch_request_bitmap(13)
	})
	standalone.set_poster('frame.png')
	assert seen.requests.len == 3 && standalone.poster_frame()?.width == 13
}
