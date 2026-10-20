module requestserver

import dom
import fetch
import html
import net
import os
import platform
import time
import xhr

fn socks_proxy_read_exact(mut socket net.TcpConn, size int) []u8 {
	mut result := []u8{len: size}
	mut offset := 0
	for offset < size {
		mut chunk := []u8{len: size - offset}
		count := socket.read(mut chunk) or { panic(err) }
		if count == 0 { panic('unexpected SOCKS proxy EOF') }
		for index in 0 .. count { result[offset + index] = chunk[index] }
		offset += count
	}
	return result
}

fn serve_native_socks_font_proxy(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(3 * time.second)
	greeting := socks_proxy_read_exact(mut socket, 2)
	assert greeting[0] == 5
	assert u8(0) in socks_proxy_read_exact(mut socket, int(greeting[1]))
	socket.write([u8(5), 0]) or { panic(err) }
	connect := socks_proxy_read_exact(mut socket, 4)
	assert connect == [u8(5), 1, 0, 3], 'socks5h must send the hostname to the proxy'
	length := socks_proxy_read_exact(mut socket, 1)[0]
	assert socks_proxy_read_exact(mut socket, int(length)).bytestr() == 'vox-font-proxy.invalid'
	assert socks_proxy_read_exact(mut socket, 2) == [u8(0), 80]
	socket.write([u8(5), 0, 0, 1, 127, 0, 0, 1, 0, 80]) or { panic(err) }
	mut request := ''
	for !request.contains('\r\n\r\n') {
		mut chunk := []u8{len: 4096}
		count := socket.read(mut chunk) or { panic(err) }
		if count == 0 { panic('unexpected HTTP request EOF') }
		request += chunk[..count].bytestr()
	}
	assert request.starts_with('GET /font.woff ')
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: font/woff\r\nContent-Length: 4\r\nConnection: close\r\n\r\nfont') or { panic(err) }
}

fn restore_native_proxy_test_environment(name string, previous ?string) {
	if value := previous { os.setenv(name, value, true) } else { os.unsetenv(name) }
}

fn test_vox_proxy_routes_native_fetch_through_socks5h_with_remote_dns() {
	$if !darwin && !linux {
		return
	}
	previous := os.getenv_opt('VOX_PROXY')
	previous_no_proxy := os.getenv_opt('NO_PROXY')
	previous_lower_no_proxy := os.getenv_opt('no_proxy')
	defer {
		restore_native_proxy_test_environment('VOX_PROXY', previous)
		restore_native_proxy_test_environment('NO_PROXY', previous_no_proxy)
		restore_native_proxy_test_environment('no_proxy', previous_lower_no_proxy)
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	os.setenv('VOX_PROXY', 'socks5h://${listener.addr()!}', true)
	os.setenv('NO_PROXY', '', true)
	os.setenv('no_proxy', '', true)
	server := spawn serve_native_socks_font_proxy(mut listener)
	settings, owner := native_transport_settings('http://vox-font-proxy.invalid/owner')
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := xhr.XMLHttpRequest.construct_in_settings(settings, connection.fetch_host())
	request.open('GET', '/font.woff', true, none, none)!
	request.send()!
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := owner
	loop.spin_until(fn [request, deadline] () bool {
		return request.state == .done || time.sys_mono_now() >= deadline
	})
	assert request.state == .done
	assert request.status() == 200
	assert request.response_text()! == 'font'
	assert connection.active_request_count() == 0
	server.wait()
}

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
	mut document := dom.Document.create(dom.URL{ value: address })
	document.set_origin(document.url.origin())
	window := html.WindowModel.create_top_level(document, none, 'native-xhr-owner') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	return settings, settings.responsible_event_loop()
}

fn test_actual_curl_socket_timer_transport_streams_into_owning_xhr_model() {
	$if !darwin && !linux {
		return
	}
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
	loop.spin_until(fn [request, deadline] () bool {
		return request.state == .done || time.sys_mono_now() >= deadline
	})
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
	$if !darwin && !linux {
		return
	}
	settings, _ := native_transport_settings('http://127.0.0.1:54321/owner')
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{ value: 'http://127.0.0.1:54321/pending' }]
	request.client = settings
	mut controller := fetch.fetch(request, fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{}), connection.fetch_host(), .no)
	assert connection.active_request_count() == 1
	controller.stop_fetch()
	assert connection.active_request_count() == 0
	assert controller.state() == .stopped
	platform.pump_native_events(0.001)
}

fn test_actual_redirect_does_not_recursively_add_or_remove_handles_in_curl_body_callback() {
	$if !darwin && !linux {
		return
	}
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
	loop.spin_until(fn [request, deadline] () bool {
		return request.state == .done || time.sys_mono_now() >= deadline
	})
	assert request.state == .done
	assert request.status() == 200
	assert request.response_text()! == 'real'
	assert request.response_url().ends_with('/final')
	assert connection.active_request_count() == 0
	assert (request.fetch_request_ or { panic('missing Fetch request') }).redirect_count == 1
	server.wait()
}
