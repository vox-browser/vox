module main

import browserjs
import dom
import encoding.base64
import html
import layout
import os
import page
import requestserver
import time

const created_poster_green_png = 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
const created_poster_small_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
const created_poster_data = 'data:image/png;base64,' + created_poster_green_png

fn created_poster_document(address string, markup string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{value: address}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn created_poster_wait(document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 4 * time.second
	loop.spin_until(fn [document, deadline] () bool {
		return !document.anything_is_delaying_the_load_event() || time.sys_mono_now() >= deadline
	})
	assert !document.anything_is_delaying_the_load_event()
}

fn created_poster_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn created_poster_owner(runtime &browserjs.Runtime) !&dom.Element {
	target := runtime.native_event_target(runtime.evaluate_host_value('createdPoster')!)!
	return unsafe { &dom.Element(target) }
}

fn created_poster_model(element &dom.Element) &html.HTMLVideoElementModel {
	return html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
}

fn created_poster_assert_green(element &dom.Element) {
	model := created_poster_model(element)
	frame := model.poster_frame() or { panic('missing created poster') }
	assert frame.width == 4 && frame.height == 4 && frame.pitch == 16
	assert frame.native_rows_are_top_down && frame.data.len == 64
	for pixel in 0 .. 16 { assert frame.data[pixel * 4..pixel * 4 + 4] == [u8(0), 128, 0, 255] }
	assert model.media.paused() && model.media.current_src() == ''
	assert model.media.network_state() == .empty && model.media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'error', 'resize'] { assert model.media.event_count(name) == 0 }
}

fn test_script_created_video_installs_poster_transport_before_disconnected_attribute_replay() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut document := created_poster_document('https://created-poster.example/page.html',
		'<!doctype html><video id="parsed" preload="none" poster="${created_poster_data}"></video><body></body>')!
	install_video_poster_fetch_hooks(document)
	created_poster_wait(document)
	parsed := document.get_element_by_id('parsed')?
	parsed_frame := created_poster_model(parsed).poster_frame()?
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.createdPoster=document.createElement("video");createdPoster.id="created-poster";createdPoster.setAttribute("preload","none");void createdPoster.paused;0'], runtime, mut messages)
	assert messages == []
	element := created_poster_owner(runtime)!
	assert element.document() == document && element.as_node().parent() == none
	video_owner := unsafe { &dom.HTMLVideoElement(element) }
	assert video_owner.video_element_model_ != unsafe { nil }
	assert !document.anything_is_delaying_the_load_event() && created_poster_model(element).poster_frame() == none
	_ = runtime.evaluate_host('createdPoster.setAttribute("poster","${created_poster_data}");void createdPoster.paused;0')!
	assert element.get_attribute_ns(none, 'poster')? == created_poster_data
	assert document.anything_is_delaying_the_load_event() && created_poster_model(element).poster_frame() == none
	created_poster_wait(document)
	created_poster_assert_green(element)
	frame := created_poster_model(element).poster_frame()?
	_ = runtime.evaluate_host(r'document.body.appendChild(createdPoster);void createdPoster.paused;globalThis.createdAudio=document.createElement("audio");document.body.appendChild(createdAudio);globalThis.createdForeign=document.createElementNS("http://www.w3.org/2000/svg","video");createdForeign.id="foreign-poster";document.body.appendChild(createdForeign);0')!
	created_poster_flush(document, runtime)!
	assert voidptr(document.get_element_by_id('created-poster')?) == voidptr(element)
	assert voidptr(created_poster_model(element).poster_frame()?) == voidptr(frame)
	assert voidptr(created_poster_model(parsed).poster_frame()?) == voidptr(parsed_frame)
	assert !document.anything_is_delaying_the_load_event()
	assert runtime.evaluate_host('createdAudio.paused&&typeof createdForeign.paused==="undefined"')! == 'true'
	assert html.html_media_element_for_dom_element(document.get_element_by_id('foreign-poster')?) == none
	result := layout.run_document_layout(document, 320, 200)?
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_video')
	assert commands.len == 2 && commands.all(it.video_bitmap != none)
}

fn test_script_created_video_poster_obeys_actual_client_csp_and_recovers_after_removal() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut document := created_poster_document('https://created-poster-policy.example/page.html', '<!doctype html><body></body>')!
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("img-src 'none'", .enforce, document.origin())]})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.createdPoster=document.createElement("video");createdPoster.id="blocked";createdPoster.setAttribute("preload","none");createdPoster.setAttribute("poster","${created_poster_data}");document.body.appendChild(createdPoster);void createdPoster.paused;0'], runtime, mut messages)
	assert messages == []
	element := created_poster_owner(runtime)!
	assert document.anything_is_delaying_the_load_event()
	created_poster_wait(document)
	assert created_poster_model(element).poster_frame() == none
	settings.set_policy_container(&html.PolicyContainer{})
	_ = runtime.evaluate_host('createdPoster.removeAttribute("poster");void createdPoster.paused;createdPoster.setAttribute("poster","${created_poster_data}");void createdPoster.paused;0')!
	assert document.anything_is_delaying_the_load_event()
	created_poster_wait(document)
	created_poster_assert_green(element)
}

fn test_created_poster_resolves_relative_file_and_load_blocker_from_the_adopted_document() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	directory := os.join_path(os.temp_dir(), 'vox-created-poster-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(os.join_path(directory, 'first'))!
	os.mkdir_all(os.join_path(directory, 'second'))!
	defer { os.rmdir_all(directory) or {} }
	os.write_file_array(os.join_path(directory, 'first/poster.png'), base64.decode(created_poster_green_png))!
	os.write_file_array(os.join_path(directory, 'second/poster.png'), base64.decode(created_poster_small_png))!
	mut first := created_poster_document('file://${directory}/first/page.html', '<!doctype html><body></body>')!
	mut second := created_poster_document('file://${directory}/second/page.html', '<!doctype html><body></body>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); first.finalize(); second.finalize() }
	mut messages := []string{}
	run_document_javascript(first, first.url.serialize(), [r'globalThis.createdPoster=document.createElement("video");createdPoster.setAttribute("preload","none");createdPoster.setAttribute("poster","poster.png");document.body.appendChild(createdPoster);void createdPoster.paused;0'], runtime, mut messages)
	assert messages == []
	element := created_poster_owner(runtime)!
	created_poster_wait(first)
	created_poster_assert_green(element)
	mut body := second.body()?.as_node()
	body.append_child(element.as_node())!
	assert element.document() == second
	_ = runtime.evaluate_host(r'createdPoster.setAttribute("poster","./poster.png");void createdPoster.paused;0')!
	assert second.anything_is_delaying_the_load_event() && !first.anything_is_delaying_the_load_event()
	created_poster_wait(second)
	assert created_poster_model(element).poster_frame()?.width == 1
	assert created_poster_model(element).natural_element_size()? == html.VideoDimensions{1, 1}
}

fn test_created_video_keeps_legacy_poster_decoder_when_no_process_transport_is_installed() {
	$if !darwin { return }
	assert requestserver.native_resource_fetch_host() == none
	mut document := created_poster_document('https://created-poster-legacy.example/page.html', '<!doctype html><body></body>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.createdPoster=document.createElement("video");createdPoster.setAttribute("preload","none");createdPoster.setAttribute("poster","${created_poster_data}");document.body.appendChild(createdPoster);void createdPoster.paused;0'], runtime, mut messages)
	assert messages == [] && !document.anything_is_delaying_the_load_event()
	created_poster_assert_green(created_poster_owner(runtime)!)
}
