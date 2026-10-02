module html

import css
import dom
import fetch
import http
import os
import time

@[heap]
struct FontFetchObservation {
mut:
	requests []&fetch.Request
	pending  []&fetch.PendingResponse
}

fn font_loader_fetch_fixture() (&dom.Document, &EventLoop, &css.FontComputer, &css.FontFaceSet, &FontFetchObservation) {
	mut document := parse_document_with_url('<!doctype html><body>font fetch</body>', dom.URL{
		value: 'https://font-fetch.example/owner'
	})
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'font-fetch') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	state := &FontFetchObservation{}
	mut computer := css.FontComputer.create_for_document(document)
	computer.set_fetch_host(&fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('font fetch must retain its asynchronous transport')
		}
		perform_async: fn [state] (request &fetch.Request) &fetch.PendingResponse {
			mut observation := unsafe { &FontFetchObservation(state) }
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			observation.requests << request
			observation.pending << pending
			return pending
		}
	})
	return document, owner, computer, css.FontFaceSet.create_for_font_computer(computer), state
}

fn finish_font_fetch(state &FontFetchObservation, index int, bytes []u8, mime string, cors bool) {
	mut response := fetch.Response.create()
	response.url_list = state.requests[index].url_list.clone()
	response.header_list.append(http.Header{ name: 'Content-Type', value: mime })
	if cors { response.header_list.append(http.Header{
			name:  'Access-Control-Allow-Origin'
			value: '*'
		}) }
	response.set_body_bytes(bytes)
	mut pending := unsafe { &fetch.PendingResponse(state.pending[index]) }
	pending.resolve(response)
}

fn drain_font_fetch_tasks(owner &EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable() or { return }
		task.execute()
	}
	panic('font task chain did not finish')
}

fn test_font_loader_retains_ongoing_request_and_shared_subscribers_until_font_completion() {
	$if !darwin { return }
	document, owner, mut computer, mut set, state := font_loader_fetch_fixture()
	mut first := css.FontFaceObject.construct_impl('Shared network',
		css.FontFaceSource.from_string('url("font.ttf"), url("unused.ttf")'), css.FontFaceDescriptors{})
	mut second := css.FontFaceObject.construct_impl('Shared network',
		css.FontFaceSource.from_string('url("font.ttf"), url("unused.ttf")'), css.FontFaceDescriptors{})
	set.add(first)!
	set.add(second)!
	first_promise := first.load()
	second_promise := second.load()
	assert first.status() == .loading
	assert second.status() == .loading
	assert first_promise.state == .pending
	assert second_promise.state == .pending
	assert state.requests.len == 1
	request := state.requests[0]
	assert request.current_url().serialize() == 'https://font-fetch.example/font.ttf'
	assert request.destination? == .font
	assert request.mode == .cors
	assert request.credentials_mode == .same_origin
	assert request.use_url_credentials
	assert request.initiator_type? == .script
	mut loader := computer.load_font_face(first.parsed_font_face(), none) or {
		panic('missing shared loader')
	}
	loader.start_loading_next_url()
	assert state.requests.len == 1
	assert loader.urls.len == 1
	assert loader.is_loading()
	assert !loader.may_finish_from_cache()
	assert !document.anything_is_delaying_the_load_event()
	loader.did_request_for_rendering()
	loader.did_request_for_rendering()
	assert document.anything_is_delaying_the_load_event()
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	finish_font_fetch(state, 0, bytes, 'application/octet-stream', false)
	assert !loader.has_completed
	drain_font_fetch_tasks(owner)
	assert loader.has_completed
	assert !loader.is_loading()
	assert !document.anything_is_delaying_the_load_event()
	assert first.status() == .loaded
	assert second.status() == .loaded
	assert first.parsed_font == second.parsed_font
	assert first_promise.state == .fulfilled
	assert second_promise.state == .fulfilled
	loader.start_loading_next_url()
	assert state.requests.len == 1
	assert loader.urls.len == 1
}

fn test_font_loader_tries_next_source_after_network_cors_and_decode_failures() {
	$if !darwin { return }
	document, owner, _, mut set, state := font_loader_fetch_fixture()
	mut face := css.FontFaceObject.construct_impl('Fallback network',
		css.FontFaceSource.from_string('url("https://other-font.example/cross.ttf"), url("truncated.ttf"), url("good.ttf")'), css.FontFaceDescriptors{})
	set.add(face)!
	promise := face.load()
	mut loader := face.font_loader_ or { panic('missing loader') }
	loader.did_request_for_rendering()
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	// A valid cross-origin font without CORS approval must not be decoded.
	finish_font_fetch(state, 0, bytes, 'font/ttf', false)
	drain_font_fetch_tasks(owner)
	assert state.requests.len == 2
	assert face.status() == .loading
	assert promise.state == .pending
	assert document.anything_is_delaying_the_load_event()
	// A font MIME type and sfnt magic do not make truncated bytes a typeface.
	finish_font_fetch(state, 1, [u8(0), 1, 0, 0], 'font/ttf', false)
	drain_font_fetch_tasks(owner)
	assert state.requests.len == 3
	assert face.status() == .loading
	assert document.anything_is_delaying_the_load_event()
	finish_font_fetch(state, 2, bytes, 'font/ttf', false)
	drain_font_fetch_tasks(owner)
	assert face.status() == .loaded
	assert promise.state == .fulfilled
	assert !document.anything_is_delaying_the_load_event()
}

fn test_font_loader_prepares_woff2_on_source_workers_before_owning_font_task_settlement() {
	$if !darwin { return }
	document, mut owner, _, mut set, state := font_loader_fetch_fixture()
	mut face := css.FontFaceObject.construct_impl('Worker WOFF2',
		css.FontFaceSource.from_string('url("font.woff2"), url("unused.ttf")'), css.FontFaceDescriptors{})
	set.add(face)!
	promise := face.load()
	mut loader := face.font_loader_ or { panic('missing loader') }
	loader.did_request_for_rendering()
	bytes := os.read_bytes(os.join_path(os.dir(@FILE), '..', 'gfxfont', 'testdata', 'variable-font-example.woff2'))!
	finish_font_fetch(state, 0, bytes, 'font/woff2', false)
	drain_font_fetch_tasks(owner)
	assert face.status() == .loading
	assert promise.state == .pending
	assert !loader.has_completed
	assert loader.has_received_font_data_
	assert document.anything_is_delaying_the_load_event()
	loader.start_loading_next_url()
	assert state.requests.len == 1
	deadline := time.sys_mono_now() + 4 * time.second
	owner.spin_until(fn [promise, deadline] () bool {
		return promise.state != .pending || time.sys_mono_now() >= deadline
	})
	assert promise.state == .fulfilled
	assert face.status() == .loaded
	assert loader.has_completed
	assert !document.anything_is_delaying_the_load_event()
	assert loader.urls.len == 1
	assert state.requests.len == 1
}

fn test_font_loader_worker_decode_failure_resumes_source_fallback_on_the_origin_loop() {
	$if !darwin { return }
	document, mut owner, _, mut set, state := font_loader_fetch_fixture()
	mut face := css.FontFaceObject.construct_impl('Worker fallback',
		css.FontFaceSource.from_string('url("broken.woff2"), url("good.ttf")'), css.FontFaceDescriptors{})
	set.add(face)!
	promise := face.load()
	mut loader := face.font_loader_ or { panic('missing loader') }
	loader.did_request_for_rendering()
	finish_font_fetch(state, 0, 'wOF2'.bytes(), 'font/woff2', false)
	drain_font_fetch_tasks(owner)
	assert state.requests.len == 1
	assert promise.state == .pending
	deadline := time.sys_mono_now() + 4 * time.second
	owner.spin_until(fn [state, deadline] () bool {
		return state.requests.len == 2 || time.sys_mono_now() >= deadline
	})
	assert state.requests.len == 2
	assert state.requests[1].current_url().serialize() == 'https://font-fetch.example/good.ttf'
	assert promise.state == .pending
	assert document.anything_is_delaying_the_load_event()
	finish_font_fetch(state, 1, os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!, 'font/ttf', false)
	drain_font_fetch_tasks(owner)
	assert promise.state == .fulfilled
	assert face.status() == .loaded
	assert !document.anything_is_delaying_the_load_event()
}

fn test_font_loader_exhausted_sources_releases_load_delay_and_rejects_status() {
	document, owner, _, mut set, state := font_loader_fetch_fixture()
	mut face := css.FontFaceObject.construct_impl('Exhausted network',
		css.FontFaceSource.from_string('url("failed.woff")'), css.FontFaceDescriptors{})
	set.add(face)!
	promise := face.load()
	mut loader := face.font_loader_ or { panic('missing loader') }
	loader.did_request_for_rendering()
	assert document.anything_is_delaying_the_load_event()
	mut pending := unsafe { &fetch.PendingResponse(state.pending[0]) }
	pending.resolve(fetch.Response.network_error('Disconnected transport'))
	drain_font_fetch_tasks(owner)
	assert face.status() == .error
	assert promise.state == .rejected
	assert loader.has_completed
	assert !loader.is_loading()
	assert !document.anything_is_delaying_the_load_event()
	assert state.requests.len == 1
}

fn test_css_connected_font_fetch_uses_source_stylesheet_base_and_initiator() {
	_, _, mut computer, set, state := font_loader_fetch_fixture()
	mut sheet :=
		css.parse_css_stylesheet_with_parser('@font-face { font-family: RuleFont; src: url("../assets/rule-font.ttf"); }', none)
	sheet.base_url = 'https://font-fetch.example/styles/main.css'
	computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
	mut face := unsafe { &css.FontFaceObject(set.set_entries()[0]) }
	face.load()
	request := state.requests[0]
	assert request.current_url().serialize() == 'https://font-fetch.example/assets/rule-font.ttf'
	assert request.initiator_type? == .css
	assert request.referrer.url?.serialize() == 'https://font-fetch.example/styles/main.css'
}
