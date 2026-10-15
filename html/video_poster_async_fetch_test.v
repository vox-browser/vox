module html

import dom
import fetch
import http
import streams

type AsyncPosterDecodeObserver = fn ([]u8)

@[heap]
struct AsyncPosterProbe {
mut:
	requests []&fetch.Request
	pending []&fetch.PendingResponse
	decoded [][]u8
	published []int
	on_decode ?AsyncPosterDecodeObserver
}

fn async_poster_bitmap(width int) &dom.Bitmap_ {
	return &dom.Bitmap_{width: width, height: 7, pitch: width * 4, data: []u8{len: width * 28}}
}

fn async_poster_image(width int) DecodedImageData {
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{frame: dom.DecodedImageFrame_.create(async_poster_bitmap(width))},
		BitmapDecodedImageFrame{frame: dom.DecodedImageFrame_.create(async_poster_bitmap(31))},
	], 0, false)
}

fn async_poster_transport(probe &AsyncPosterProbe) &PosterFrameFetchTransport {
	return &PosterFrameFetchTransport{
		host: &fetch.FetchHost{
			perform: fn (_ &fetch.Request) !&fetch.Response { panic('unexpected synchronous host') }
			perform_async: fn [probe] (request &fetch.Request) &fetch.PendingResponse {
				mut seen := unsafe { &AsyncPosterProbe(probe) }
				mut owner := unsafe { &fetch.Request(request) }
				pending := fetch.PendingResponse.create(mut owner, none)
				seen.requests << request
				seen.pending << pending
				return pending
			}
		}
		decode: fn [probe] (bytes []u8) !DecodedImageData {
			mut seen := unsafe { &AsyncPosterProbe(probe) }
			seen.decoded << bytes.clone()
			if callback := seen.on_decode { callback(bytes) }
			if bytes == 'decode-error'.bytes() { return error('controlled decoder failure') }
			if bytes.len == 0 { return BitmapDecodedImageData.create([], 0, false) }
			return async_poster_image(int(bytes[0]))
		}
	}
}

fn async_poster_setup(tag string) (&dom.Document, &dom.Element, &HTMLVideoElementModel, &AsyncPosterProbe, &EventLoop) {
	url := dom.URL{value: 'https://async-poster-${tag}.example/base/page.html'}
	mut document := parse_navigation_document('<!doctype html><video id="video" preload="none"></video>',
		url, url.origin(), none) or { panic(err) }
	assert document.is_fully_active()
	mut settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	mut element := document.get_element_by_id('video') or { panic('missing async poster owner') }
	mut video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	video.set_poster_fetch_hook(fn (_ dom.URL) !&dom.Bitmap_ { return async_poster_bitmap(3) })
	element.set_attribute_value('poster', 'seed.png')
	probe := &AsyncPosterProbe{}
	video.set_paint_facts_update_hook(fn [probe] (owner &dom.HTMLVideoElement) {
		current := html_video_element_model_for_dom_element(owner)
		mut seen := unsafe { &AsyncPosterProbe(probe) }
		seen.published << if frame := current.poster_frame() { frame.width } else { 0 }
	})
	video.set_poster_fetch_transport(async_poster_transport(probe))
	assert probe.requests == [] && (video.poster_frame() or { panic('missing seed poster') }).width == 3
	return document, element, video, probe, loop
}

fn async_poster_response(probe &AsyncPosterProbe, index int, bytes []u8) &fetch.Response {
	mut response := fetch.Response.create()
	response.url_list = probe.requests[index].url_list.clone()
	response.header_list.append(http.Header{name: 'Content-Type', value: 'image/png'})
	response.header_list.append(http.Header{name: 'Cache-Control', value: 'no-store'})
	response.set_body_bytes(bytes)
	return response
}

fn async_poster_resolve(probe &AsyncPosterProbe, index int, response &fetch.Response) {
	mut pending := unsafe { &fetch.PendingResponse(probe.pending[index]) }
	pending.resolve(response)
}

fn async_poster_drain(loop &EventLoop) {
	mut queue := loop.task_queue()
	for _ in 0 .. 100 {
		mut task := queue.take_first_runnable() or { assert queue.is_empty(); return }
		task.execute()
	}
	panic('async poster queue did not drain')
}

fn async_poster_assert_idle(video &HTMLVideoElementModel, document &dom.Document) {
	assert video.poster_fetch_controller_ == none
	assert !document.anything_is_delaying_the_load_event()
	assert video.media.paused() && video.media.current_src() == ''
	assert video.media.network_state() == .empty && video.media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'error', 'resize'] { assert video.media.event_count(name) == 0 }
}

fn test_async_poster_fetch_reads_streamed_bytes_on_the_actual_owner_queue_and_uses_the_first_frame() {
	mut document, mut element, video, probe, loop := async_poster_setup('stream'); defer { document.finalize() }
	element.set_attribute_value('poster', 'stream.png')
	assert probe.requests.len == 1 && video.poster_frame()?.width == 3
	request := probe.requests[0]
	assert (request.destination or { panic('missing destination') }) == .image
	assert (request.initiator_type or { panic('missing initiator') }) == .video
	assert request.credentials_mode == .include && request.use_url_credentials
	client := request.client or { panic('missing actual client') }
	assert (client.fetch_request_client_document_url() or { panic('missing client document') }) == document.url
	assert document.anything_is_delaying_the_load_event() && probe.decoded == []
	mut response := async_poster_response(probe, 0, [])
	body := fetch.Body.streaming()
	mut producer := body.stream()
	response.body = body
	async_poster_resolve(probe, 0, response)
	assert probe.decoded == []
	async_poster_drain(loop)
	producer.enqueue(streams.bytes_value([u8(13), 5]))!
	producer.enqueue(streams.bytes_value([u8(7), 9]))!
	async_poster_drain(loop)
	assert probe.decoded == [] && video.poster_frame()?.width == 3
	producer.close()
	assert probe.decoded == []
	async_poster_drain(loop)
	assert probe.decoded == [[u8(13), 5, 7, 9]] && probe.published == [13]
	assert video.poster_frame()?.width == 13 && video.natural_element_size()? == VideoDimensions{13, 7}
	async_poster_assert_idle(video, document)
}

fn test_async_poster_network_body_decoder_and_empty_frame_results_finalize_only_the_current_request() {
	for result in ['network', 'body', 'decoder', 'empty', 'http-error', 'opaque'] {
		mut document, mut element, video, probe, loop := async_poster_setup(result); defer { document.finalize() }
		element.set_attribute_value('poster', if result == 'opaque' { 'https://async-poster-cross.example/image.png' } else { 'result.png' })
		mut response := async_poster_response(probe, 0, if result == 'decoder' { 'decode-error'.bytes() } else if result == 'empty' { []u8{} } else { [u8(17)] })
		if result == 'network' { response = fetch.Response.network_error('controlled network failure') }
		if result == 'http-error' { response.status = 404 }
		mut producer := fetch.Body.streaming().stream()
		if result == 'body' { response.body = fetch.Body.create(producer, .readable_stream, none) }
		async_poster_resolve(probe, 0, response)
		async_poster_drain(loop)
		if result == 'body' {
			assert document.anything_is_delaying_the_load_event()
			producer.error('controlled body failure')
			async_poster_drain(loop)
		}
		if result in ['http-error', 'opaque'] {
			assert video.poster_frame()?.width == 17 && probe.published == [17]
		} else { assert video.poster_frame() == none && probe.published == [0] }
		assert probe.decoded.len == if result in ['network', 'body'] { 0 } else { 1 }
		async_poster_assert_idle(video, document)
	}
}

fn test_async_poster_replacement_and_clearing_stop_real_controllers_and_discard_late_or_queued_results() {
	for queued in [false, true] {
		mut document, mut element, video, probe, loop := async_poster_setup(if queued { 'queued' } else { 'late' }); defer { document.finalize() }
		element.set_attribute_value('poster', 'old.png')
		old := video.poster_fetch_controller_ or { panic('missing old controller') }
		if queued { async_poster_resolve(probe, 0, async_poster_response(probe, 0, [u8(31)])) }
		element.set_attribute_value('poster', 'current.png')
		assert old.state() == .stopped && old.ongoing_task_count() == 0
		if !queued { async_poster_resolve(probe, 0, async_poster_response(probe, 0, [u8(31)])) }
		async_poster_drain(loop)
		assert probe.decoded == [] && probe.published == [] && document.anything_is_delaying_the_load_event()
		async_poster_resolve(probe, 1, async_poster_response(probe, 1, [u8(13)]))
		async_poster_drain(loop)
		assert video.poster_frame()?.width == 13 && probe.published == [13]
		element.set_attribute_value('poster', 'discard.png')
		last := video.poster_fetch_controller_ or { panic('missing discarded controller') }
		element.remove_attribute('poster')
		assert last.state() == .stopped && video.poster_frame() == none
		async_poster_resolve(probe, 2, async_poster_response(probe, 2, [u8(31)]))
		async_poster_drain(loop)
		assert probe.decoded == [[u8(13)]] && probe.published == [13, 0]
		async_poster_assert_idle(video, document)
	}
}

fn test_async_poster_decoder_reentry_keeps_the_new_request_and_its_independent_load_blocker() {
	for fails in [false, true] {
		mut document, mut element, video, probe, loop := async_poster_setup(if fails { 'decode-fail' } else { 'decode-success' }); defer { document.finalize() }
		independent := dom.DocumentLoadEventDelayer.new(mut document)
		mut seen := unsafe { &AsyncPosterProbe(probe) }
		seen.on_decode = fn [element] (_ []u8) {
			mut owner := unsafe { &dom.Element(element) }
			owner.set_attribute_value('poster', 'inner.png')
		}
		element.set_attribute_value('poster', 'outer.png')
		async_poster_resolve(probe, 0, async_poster_response(probe, 0, if fails { 'decode-error'.bytes() } else { [u8(31)] }))
		async_poster_drain(loop)
		assert probe.requests.len == 2 && probe.published == [] && video.poster_frame()?.width == 3
		seen.on_decode = none
		async_poster_resolve(probe, 1, async_poster_response(probe, 1, [u8(13)]))
		async_poster_drain(loop)
		assert video.poster_frame()?.width == 13 && probe.published == [13]
		assert document.anything_is_delaying_the_load_event()
		mut blocker := independent; blocker.finish()
		async_poster_assert_idle(video, document)
	}
}

fn test_async_poster_adoption_retargets_the_blocker_and_keeps_the_original_request_client_and_queue() {
	mut original, mut element, video, probe, loop := async_poster_setup('adopt-old'); defer { original.finalize() }
	mut destination, _, _, _, destination_loop := async_poster_setup('adopt-new'); defer { destination.finalize() }
	element.set_attribute_value('poster', 'adopted.png')
	client := probe.requests[0].client or { panic('missing original client') }
	destination.adopt_node(element.as_node())
	assert !original.anything_is_delaying_the_load_event() && destination.anything_is_delaying_the_load_event()
	async_poster_resolve(probe, 0, async_poster_response(probe, 0, [u8(13)]))
	async_poster_drain(destination_loop)
	assert probe.decoded == []
	async_poster_drain(loop)
	assert (client.fetch_request_client_document_url() or { panic('lost original client') }) == original.url
	assert video.poster_frame()?.width == 13 && probe.published == [13]
	async_poster_assert_idle(video, destination)
}

fn test_async_poster_fetch_enforces_the_actual_client_csp_before_calling_the_host() {
	mut document, mut element, video, probe, loop := async_poster_setup('csp'); defer { document.finalize() }
	mut settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	settings.set_policy_container(&PolicyContainer{csp_list: [parse_response_csp_policy("img-src 'none'", .enforce, document.origin())]})
	element.set_attribute_value('poster', 'blocked.png')
	assert probe.requests == [] && probe.decoded == []
	async_poster_drain(loop)
	assert video.poster_frame() == none && probe.published == [0]
	async_poster_assert_idle(video, document)
}

fn test_async_poster_stop_callback_reentry_preserves_the_new_attribute_request_and_load_delay() {
	mut document, mut element, video, probe, loop := async_poster_setup('stop-reentry'); defer { document.finalize() }
	element.set_attribute_value('poster', 'old.png')
	mut old := video.poster_fetch_controller_ or { panic('missing stop-reentry controller') }
	old.set_pending_network_request(fetch.RequestServerRequest{stop: fn [element] () {
		mut owner := unsafe { &dom.Element(element) }
		owner.set_attribute_value('poster', 'inner.png')
	}})
	element.remove_attribute('poster')
	assert old.state() == .stopped && probe.requests.len == 2
	assert element.get_attribute_value('poster') == 'inner.png' && video.poster_frame()?.width == 3
	assert document.anything_is_delaying_the_load_event() && probe.published == []
	async_poster_resolve(probe, 0, async_poster_response(probe, 0, [u8(31)]))
	async_poster_resolve(probe, 1, async_poster_response(probe, 1, [u8(13)]))
	async_poster_drain(loop)
	assert video.poster_frame()?.width == 13 && probe.decoded == [[u8(13)]] && probe.published == [13]
	async_poster_assert_idle(video, document)
}

fn test_synchronous_poster_fetch_host_reentry_keeps_the_real_client_and_new_controller() {
	mut document, mut element, mut video, probe, loop := async_poster_setup('host-reentry'); defer { document.finalize() }
	video.set_poster_fetch_transport(&PosterFrameFetchTransport{
		host: &fetch.FetchHost{perform: fn [element] (request &fetch.Request) !&fetch.Response {
			assert request.client != none
			mut owner := unsafe { &dom.Element(element) }
			owner.set_attribute_value('poster', 'data:image/png,%11')
			mut response := fetch.Response.create()
			response.url_list = request.url_list.clone()
			response.header_list.append(http.Header{name: 'Content-Type', value: 'image/png'})
			response.set_body_bytes([u8(31)])
			return response
		}}
		decode: fn [probe] (bytes []u8) !DecodedImageData {
			mut seen := unsafe { &AsyncPosterProbe(probe) }; seen.decoded << bytes.clone()
			return async_poster_image(int(bytes[0]))
		}
	})
	element.set_attribute_value('poster', 'outer.png')
	assert element.get_attribute_value('poster') == 'data:image/png,%11'
	assert document.anything_is_delaying_the_load_event() && probe.decoded == []
	assert video.poster_fetch_controller_ != none && video.poster_frame()?.width == 3
	async_poster_drain(loop)
	assert video.poster_frame()?.width == 17 && probe.decoded == [[u8(17)]] && probe.published == [17]
	async_poster_assert_idle(video, document)
}
