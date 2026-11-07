module main

import browserjs
import dom
import encoding.base64
import fetch
import html
import layout
import page
import time

const equal_poster_green = 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
const equal_poster_small = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

@[heap]
struct EqualPosterProbe {
mut:
	requests []&fetch.Request
	pending []&fetch.PendingResponse
	controllers []&fetch.FetchController
	stopped []int
	decode_count int
}

fn equal_poster_fixture(foreign_first bool) !(&dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><head><base id="poster-base" href="/first/"></head><body><video id="equal-parsed" preload="none"></video></body>',
		dom.URL{value: 'https://equal-poster.example/root/page.html'}, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut parsed := document.get_element_by_id('equal-parsed') or { return error('missing parsed video') }
	if foreign_first { parsed.set_attribute_ns_for_bindings('urn:equal-poster', 'poster', 'foreign.png')! }
	parsed.set_attribute_value('poster', 'same.png')
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.equalVideos=[document.getElementById("equal-parsed")];const created=document.createElement("video");created.id="equal-created";created.setAttribute("preload","none");document.body.appendChild(created);equalVideos.push(created);0'], runtime, mut messages)
	assert messages == []
	return document, runtime
}

fn equal_poster_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn equal_poster_setup(element &dom.Element) (&html.HTMLVideoElementModel, &EqualPosterProbe) {
	mut video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	video.set_poster_fetch_hook(fn (_ dom.URL) !&dom.Bitmap_ {
		return browser_decode_raster_image_bytes(base64.decode(equal_poster_green))
	})
	mut owner := unsafe { &dom.Element(element) }
	owner.set_attribute_value_ns('poster', 'same.png', none, none)
	assert (video.poster_frame() or { panic('missing seed') }).width == 4
	probe := &EqualPosterProbe{}
	video.set_poster_fetch_transport(&html.PosterFrameFetchTransport{
		host: &fetch.FetchHost{
			perform: fn (_ &fetch.Request) !&fetch.Response { panic('unexpected synchronous host') }
			perform_async_with_params: fn [probe] (params &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
				mut seen := unsafe { &EqualPosterProbe(probe) }
				mut mutable_request := unsafe { &fetch.Request(request) }
				pending := fetch.PendingResponse.create(mut mutable_request, none)
				index := seen.requests.len
				seen.requests << request
				seen.pending << pending
				seen.controllers << params.controller
				mut controller := params.controller
				controller.set_pending_network_request(fetch.RequestServerRequest{
					stop: fn [probe, index] () {
						mut observed := unsafe { &EqualPosterProbe(probe) }
						observed.stopped << index
					}
				})
				return pending
			}
		}
		decode: fn [probe] (bytes []u8) !html.DecodedImageData {
			mut observed := unsafe { &EqualPosterProbe(probe) }
			observed.decode_count++
			return browser_decode_video_poster(bytes)
		}
	})
	return video, probe
}

fn equal_poster_resolve(probe &EqualPosterProbe, index int, bytes []u8) {
	mut response := fetch.Response.create()
	response.url_list = probe.requests[index].url_list.clone()
	response.set_body_bytes(bytes)
	mut pending := unsafe { &fetch.PendingResponse(probe.pending[index]) }
	pending.resolve(response)
}

fn equal_poster_drain(document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	mut queue := loop.task_queue()
	for _ in 0 .. 200 {
		loop.perform_a_microtask_checkpoint()
		if !queue.has_runnable_tasks() { return }
		loop.process()
	}
	panic('poster owner task queue did not drain')
}

fn equal_poster_wait_decode(document &dom.Document, probe &EqualPosterProbe, expected int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 4 * time.second
	loop.spin_until(fn [probe, expected, deadline] () bool {
		return probe.decode_count >= expected || time.sys_mono_now() >= deadline
	})
	assert probe.decode_count == expected
	equal_poster_drain(document)
}

fn test_equal_poster_writes_restart_pending_fetches_for_parsed_and_created_native_owners() {
	$if !darwin { return }
	mut document, mut runtime := equal_poster_fixture(false)!
	defer { runtime.close(); document.finalize() }
	for index, id in ['equal-parsed', 'equal-created'] {
		element := document.get_element_by_id(id)?
		video, probe := equal_poster_setup(element)
		attribute := element.get_attribute_node_ns(none, 'poster')?
		mut independent := dom.DocumentLoadEventDelayer.new(mut document)
		_ = runtime.evaluate_host('equalVideos[${index}].setAttribute("poster","same.png");0')!
		equal_poster_flush(document, runtime)!
		assert probe.requests.len == 1
		_ = runtime.evaluate_host('equalVideos[${index}].setAttribute("POSTER","same.png");equalVideos[${index}].setAttribute("poster","same.png");0')!
		equal_poster_flush(document, runtime)!
		assert probe.requests.len == 3 && probe.stopped == [0, 1]
		assert probe.controllers[0].state() == .stopped && probe.controllers[1].state() == .stopped
		assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
		assert video.poster_frame()?.width == 4 && probe.decode_count == 0
		for request in probe.requests {
			assert request.current_url().serialize() == 'https://equal-poster.example/first/same.png'
			assert request.credentials_mode == .include && request.use_url_credentials
			client := request.client or { panic('missing actual client') }
			assert (client.fetch_request_client_document_url() or { panic('missing client document') }) == document.url
		}
		equal_poster_resolve(probe, 2, base64.decode(equal_poster_small))
		equal_poster_wait_decode(document, probe, 1)
		assert video.poster_frame()?.width == 1 && probe.decode_count == 1
		assert document.anything_is_delaying_the_load_event()
		independent.finish()
		assert !document.anything_is_delaying_the_load_event()
		equal_poster_resolve(probe, 1, base64.decode(equal_poster_green))
		equal_poster_resolve(probe, 0, base64.decode(equal_poster_green))
		equal_poster_drain(document)
		assert video.poster_frame()?.width == 1 && probe.decode_count == 1
		assert video.media.paused() && video.media.current_src() == ''
	}
}

fn test_equal_poster_write_supersedes_queued_completion_and_rechecks_a_finished_request() {
	$if !darwin { return }
	mut document, mut runtime := equal_poster_fixture(false)!
	defer { runtime.close(); document.finalize() }
	element := document.get_element_by_id('equal-parsed')?
	video, probe := equal_poster_setup(element)
	_ = runtime.evaluate_host('equalVideos[0].setAttribute("poster","same.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests.len == 1
	equal_poster_resolve(probe, 0, base64.decode(equal_poster_green))
	_ = runtime.evaluate_host('equalVideos[0].setAttribute("poster","same.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests.len == 2 && probe.stopped == [0]
	equal_poster_drain(document)
	assert probe.decode_count == 0 && document.anything_is_delaying_the_load_event()
	equal_poster_resolve(probe, 1, base64.decode(equal_poster_small))
	equal_poster_wait_decode(document, probe, 1)
	assert probe.decode_count == 1 && video.poster_frame()?.width == 1
	assert !document.anything_is_delaying_the_load_event()
	_ = runtime.evaluate_host('equalVideos[0].setAttribute("poster","same.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests.len == 3 && video.poster_frame()?.width == 1
	equal_poster_resolve(probe, 2, 'invalid encoded image'.bytes())
	equal_poster_wait_decode(document, probe, 2)
	assert probe.decode_count == 2 && video.poster_frame() == none && video.natural_element_size() == none
	assert !document.anything_is_delaying_the_load_event()
}

fn test_equal_poster_write_reparses_the_live_document_base_and_paints_the_refetched_frame() {
	$if !darwin { return }
	mut document, mut runtime := equal_poster_fixture(false)!
	defer { runtime.close(); document.finalize() }
	element := document.get_element_by_id('equal-parsed')?
	video, probe := equal_poster_setup(element)
	attribute := element.get_attribute_node_ns(none, 'poster')?
	_ = runtime.evaluate_host('equalVideos[0].setAttribute("poster","same.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests.len == 1
	_ = runtime.evaluate_host('document.getElementById("poster-base").setAttribute("href","/second/");equalVideos[0].setAttribute("poster","same.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests.len == 2 && probe.stopped == [0]
	assert probe.requests[1].current_url().serialize() == 'https://equal-poster.example/second/same.png'
	assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
	equal_poster_resolve(probe, 1, base64.decode(equal_poster_small))
	equal_poster_wait_decode(document, probe, 1)
	assert video.natural_element_size()? == html.VideoDimensions{1, 1}
	result := layout.run_document_layout(document, 320, 200)?
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_video')
	assert commands.len == 2
	posters := commands.filter(it.video_bitmap != none)
	assert posters.len == 1 && posters[0].video_bitmap?.data == video.poster_frame()?.data
	equal_poster_resolve(probe, 0, base64.decode(equal_poster_green))
	equal_poster_drain(document)
	assert probe.decode_count == 1 && video.poster_frame()?.width == 1
}

fn test_equal_poster_replay_keeps_first_qualified_attribute_identity_and_namespace_filtering() {
	$if !darwin { return }
	mut document, mut runtime := equal_poster_fixture(true)!
	defer { runtime.close(); document.finalize() }
	element := document.get_element_by_id('equal-parsed')?
	video, probe := equal_poster_setup(element)
	foreign := element.get_attribute_node_ns('urn:equal-poster', 'poster')?
	actual := element.get_attribute_node_ns(none, 'poster')?
	_ = runtime.evaluate_host('equalVideos[0].setAttribute("poster","foreign.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests == [] && video.poster_frame()?.width == 4
	assert voidptr(element.get_attribute_node('poster')?) == voidptr(foreign)
	_ = runtime.evaluate_host('equalVideos[0].removeAttribute("poster");equalVideos[0].setAttribute("poster","same.png");0')!
	equal_poster_flush(document, runtime)!
	assert probe.requests.len == 1 && foreign.owner_element() == none
	assert voidptr(element.get_attribute_node('poster')?) == voidptr(actual)
	equal_poster_resolve(probe, 0, base64.decode(equal_poster_small))
	equal_poster_wait_decode(document, probe, 1)
	assert video.poster_frame()?.width == 1 && probe.decode_count == 1
}
