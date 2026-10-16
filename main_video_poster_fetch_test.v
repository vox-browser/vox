module main

import dom
import encoding.base64
import html
import io
import layout
import net
import os
import page
import requestserver
import time

const native_fetch_poster_png = 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
const native_fetch_poster_data = 'data:image/png;base64,' + native_fetch_poster_png

fn native_fetch_poster_document(address string, poster string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="video" preload="none" poster="${poster}"></video>',
		dom.URL{value: address}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn native_fetch_poster_model(document &dom.Document) &html.HTMLVideoElementModel {
	element := document.get_element_by_id('video') or { panic('missing native video') }
	return html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
}

fn native_fetch_poster_wait(document &dom.Document, phase string) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut owner := settings.responsible_event_loop()
	started := time.sys_mono_now()
	// Native timers and the decoder share a loaded CI host; keep a bounded wait.
	deadline := started + 30 * time.second
	owner.spin_until(fn [document, deadline] () bool {
		return !document.anything_is_delaying_the_load_event() || time.sys_mono_now() >= deadline
	})
	println('native poster ${phase}: ${(time.sys_mono_now() - started) / time.millisecond} ms, load delayed: ${document.anything_is_delaying_the_load_event()}')
	assert !document.anything_is_delaying_the_load_event()
}

fn native_fetch_poster_assert_green(document &dom.Document) {
	model := native_fetch_poster_model(document)
	bitmap := model.poster_frame() or { panic('missing native decoded poster') }
	assert bitmap.width == 4 && bitmap.height == 4 && bitmap.pitch == 16
	assert bitmap.native_rows_are_top_down && bitmap.data.len == 64
	for pixel in 0 .. 16 { assert bitmap.data[pixel * 4..pixel * 4 + 4] == [u8(0), 128, 0, 255] }
	assert (model.natural_element_size() or { panic('missing natural size') }) == html.VideoDimensions{4, 4}
	result := layout.run_document_layout(document, 320, 200) or { panic('missing native layout') }
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_video')
	assert commands.len == 1
	assert (commands[0].video_bitmap or { panic('missing retained bitmap') }).data == bitmap.data
	assert model.media.paused() && model.media.current_src() == ''
	assert model.media.network_state() == .empty && model.media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'error', 'resize'] { assert model.media.event_count(name) == 0 }
}

fn test_native_poster_file_fetch_defers_real_decode_and_publishes_retained_pixels() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	directory := os.join_path(os.temp_dir(), 'vox-poster-fetch-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(directory)!
	defer { os.rmdir_all(directory) or {} }
	os.write_file_array(os.join_path(directory, 'poster.png'), base64.decode(native_fetch_poster_png))!
	mut document := native_fetch_poster_document('file://${directory}/page.html', 'poster.png')!
	defer { document.finalize() }
	element := document.get_element_by_id('video')?
	attribute := element.get_attribute_node_ns(none, 'poster')?
	install_video_poster_fetch_hooks(document)
	assert native_fetch_poster_model(document).poster_frame() == none
	assert document.anything_is_delaying_the_load_event()
	native_fetch_poster_wait(document, 'file decode')
	native_fetch_poster_assert_green(document)
	assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_attribute_value('poster', 'missing.png')
	assert document.anything_is_delaying_the_load_event()
	native_fetch_poster_wait(document, 'missing file')
	assert native_fetch_poster_model(document).poster_frame() == none
	mutable_element.set_attribute_value('poster', native_fetch_poster_data)
	native_fetch_poster_wait(document, 'file recovery')
	native_fetch_poster_assert_green(document)
}

fn native_fetch_poster_serve_redirect(mut listener net.TcpListener, bytes []u8) []string {
	mut requests := []string{}
	for hop in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(4 * time.second)
		mut input := []u8{len: 8192}
		count := socket.read(mut input) or { panic(err) }
		requests << input[..count].bytestr()
		if hop == 0 {
			socket.write_string('HTTP/1.1 302 Found\r\nLocation: /final.png\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or { panic(err) }
		} else {
			socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ${bytes.len}\r\nConnection: close\r\n\r\n') or { panic(err) }
			_ := socket.write(bytes[..16]) or { panic(err) }
			time.sleep(35 * time.millisecond)
			_ := socket.write(bytes[16..]) or { panic(err) }
		}
		socket.close() or {}
	}
	return requests
}

fn test_native_poster_http_fetch_follows_redirect_and_decodes_the_streamed_body() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(4 * time.second)
	defer { listener.close() or {} }
	server := spawn native_fetch_poster_serve_redirect(mut listener, base64.decode(native_fetch_poster_png))
	mut document := native_fetch_poster_document('http://${listener.addr()!}/base/page.html', '../poster.png')!
	defer { document.finalize() }
	install_video_poster_fetch_hooks(document)
	assert document.anything_is_delaying_the_load_event() && native_fetch_poster_model(document).poster_frame() == none
	native_fetch_poster_wait(document, 'HTTP redirect body')
	native_fetch_poster_assert_green(document)
	requests := server.wait()
	assert requests.len == 2
	assert requests[0].starts_with('GET /poster.png HTTP/1.1\r\n')
	assert requests[1].starts_with('GET /final.png HTTP/1.1\r\n')
}

fn native_fetch_poster_serve_until_stopped(mut listener net.TcpListener, ready chan bool) string {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(4 * time.second)
	mut input := []u8{len: 8192}
	mut request := ''
	for !request.contains('\r\n\r\n') {
		count := socket.read(mut input) or { panic(err) }
		request += input[..count].bytestr()
	}
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 100000\r\nConnection: close\r\n\r\npartial') or { panic(err) }
	ready <- true
	_ := socket.read(mut input) or {
		if err is io.Eof { return 'eof' }
		if err.code() == C.ECONNRESET { return 'reset' }
		return 'failure ${err.code()}: ${err.msg()}'
	}
	return 'unexpected request bytes'
}

fn test_native_poster_removal_stops_the_live_curl_socket_before_body_completion() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(4 * time.second)
	defer { listener.close() or {} }
	ready := chan bool{cap: 1}
	server := spawn native_fetch_poster_serve_until_stopped(mut listener, ready)
	mut document := native_fetch_poster_document('http://${listener.addr()!}/page.html', 'partial.png')!
	defer { document.finalize() }
	install_video_poster_fetch_hooks(document)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut owner := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 4 * time.second
	owner.spin_until(fn [ready, deadline] () bool { return ready.len > 0 || time.sys_mono_now() >= deadline })
	assert ready.len == 1 && document.anything_is_delaying_the_load_event()
	mut element := document.get_element_by_id('video')?
	element.remove_attribute('poster')
	assert native_fetch_poster_model(document).poster_frame() == none
	assert !document.anything_is_delaying_the_load_event()
	outcome := server.wait()
	assert outcome in ['eof', 'reset'], outcome
	println('native poster cancellation: ${outcome}')
	element.set_attribute_value('poster', native_fetch_poster_data)
	native_fetch_poster_wait(document, 'after cancellation')
	native_fetch_poster_assert_green(document)
}

fn test_native_poster_uses_actual_client_csp_and_releases_decode_failure_blockers() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut document := native_fetch_poster_document('https://native-poster-policy.example/page.html', '')!
	defer { document.finalize() }
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("img-src 'none'", .enforce, document.origin())]})
	install_video_poster_fetch_hooks(document)
	mut element := document.get_element_by_id('video')?
	element.set_attribute_value('poster', native_fetch_poster_data)
	assert document.anything_is_delaying_the_load_event()
	native_fetch_poster_wait(document, 'CSP rejection')
	assert native_fetch_poster_model(document).poster_frame() == none
	settings.set_policy_container(&html.PolicyContainer{})
	element.set_attribute_value('poster', native_fetch_poster_data)
	native_fetch_poster_wait(document, 'CSP recovery')
	native_fetch_poster_assert_green(document)
	element.set_attribute_value('poster', 'data:image/png,invalid')
	assert document.anything_is_delaying_the_load_event()
	native_fetch_poster_wait(document, 'invalid image')
	assert native_fetch_poster_model(document).poster_frame() == none
	assert native_fetch_poster_model(document).natural_element_size() == none
}

fn test_native_poster_transport_keeps_settings_less_document_adapter_working() {
	$if !darwin { return }
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut document := html.parse_document('<!doctype html><video id="video" preload="none" poster="${native_fetch_poster_data}"></video>')
	defer { document.finalize() }
	assert document.relevant_settings_object() == unsafe { nil }
	install_video_poster_fetch_hooks(document)
	assert !document.anything_is_delaying_the_load_event()
	native_fetch_poster_assert_green(document)
}
