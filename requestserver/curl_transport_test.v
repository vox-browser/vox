module requestserver

import dom
import fetch
import html
import net
import platform
import time
import xhr

fn serve_streaming_response(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	socket.write_string('HTTP/1.1 201 Native reason\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Length: 7\r\nX-Transport: curl\r\nConnection: close\r\n\r\nreal') or { panic(err) }
	time.sleep(35 * time.millisecond)
	socket.write_string('ity') or { panic(err) }
}

fn serve_redirect_response(mut listener net.TcpListener) {
	for hop in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		mut input := []u8{len: 4096}
		_ := socket.read(mut input) or { panic(err) }
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 3\r\nConnection: close\r\n\r\nold'
		} else {
			'HTTP/1.1 200 Final\r\nContent-Type: text/plain\r\nContent-Length: 4\r\nConnection: close\r\n\r\nreal'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
}

fn native_transport_settings(address string) (&html.EnvironmentSettingsObject, &html.EventLoop) {
	mut document := dom.Document.create(dom.URL{address})
	document.set_origin(document.url.origin())
	window := html.WindowModel.create_top_level(document, none, 'native-xhr-owner') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	return settings, settings.responsible_event_loop()
}

fn test_actual_curl_socket_timer_transport_streams_into_owning_xhr_model() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/owner'
	server := spawn serve_streaming_response(mut listener)
	settings, owner := native_transport_settings(address)
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := xhr.XMLHttpRequest.construct_in_settings(settings, connection.fetch_host())
	request.open('GET', '/stream', true, none, none)!
	request.send()!
	assert request.state == .opened
	assert connection.active_request_count() == 1
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := owner
	loop.spin_until(fn [request, deadline] () bool { return request.state == .done || time.sys_mono_now() >= deadline })
	assert request.state == .done
	assert request.status() == 201
	assert request.status_text() == 'Native reason'
	assert request.response_text()! == 'reality'
	assert request.get_response_header('X-Transport')? == 'curl'
	assert request.response_url().ends_with('/stream')
	assert (request.fetch_request_ or { panic('missing live Fetch request') }).done
	assert connection.active_request_count() == 0
	assert request.events.filter(it.type_ == 'load').len == 1
	assert request.events.filter(it.type_ == 'loadend').len == 1
	server.wait()
}

fn test_source_stop_fetch_removes_the_real_curl_request_from_multi() {
	$if !darwin { return }
	settings, _ := native_transport_settings('http://127.0.0.1:54321/owner')
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{'http://127.0.0.1:54321/pending'}]
	request.client = settings
	mut controller := fetch.fetch(request, fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{}), connection.fetch_host(), .no)
	assert connection.active_request_count() == 1
	controller.stop_fetch()
	assert connection.active_request_count() == 0
	assert controller.state() == .stopped
	platform.pump_native_events(0.001)
}

fn test_actual_redirect_does_not_recursively_add_or_remove_handles_in_curl_body_callback() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_redirect_response(mut listener)
	settings, owner := native_transport_settings('http://${listener.addr()!}/owner')
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := xhr.XMLHttpRequest.construct_in_settings(settings, connection.fetch_host())
	request.open('GET', '/redirect', true, none, none)!
	request.send()!
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := owner
	loop.spin_until(fn [request, deadline] () bool { return request.state == .done || time.sys_mono_now() >= deadline })
	assert request.state == .done
	assert request.status() == 200
	assert request.response_text()! == 'real'
	assert request.response_url().ends_with('/final')
	assert connection.active_request_count() == 0
	assert (request.fetch_request_ or { panic('missing Fetch request') }).redirect_count == 1
	server.wait()
}
