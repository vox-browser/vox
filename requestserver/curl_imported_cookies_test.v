module requestserver

import dom
import html
import net
import os
import time
import xhr

fn imported_cookie_settings(address string) (&html.EnvironmentSettingsObject, &html.EventLoop) {
	mut document := dom.Document.create(dom.URL{ value: address })
	document.set_origin(document.url.origin())
	window := html.WindowModel.create_top_level(document, none, 'imported-cookie-xhr-owner') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	return settings, settings.responsible_event_loop()
}

fn serve_one_request(mut listener net.TcpListener) string {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(2 * time.second)
	mut received := []u8{}
	mut chunk := []u8{len: 4096}
	for {
		count := socket.read(mut chunk) or { break }
		if count <= 0 { break }
		received << chunk[..count]
		text := received.bytestr()
		if head_end := text.index('\r\n\r\n') {
			length_line := text[..head_end].to_lower().split('\r\n').filter(it.starts_with('content-length:'))
			length := if length_line.len > 0 { length_line[0].all_after(':').trim_space().int() } else { 0 }
			if text.len >= head_end + 4 + length { break }
		}
	}
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}') or { panic(err) }
	return received.bytestr()
}

// Old Reddit's "load more comments" POSTs /api/morechildren from the page.
// Its session lives in the imported cookie jar; without it the server answers
// with a login redirect and the comments never load.
fn test_same_origin_xhr_sends_imported_session_cookies() {
	$if !darwin && !linux {
		return
	}
	previous := os.getenv_opt('VOX_COOKIE_FILE')
	jar := os.join_path(os.temp_dir(), 'vox-xhr-cookie-test-${os.getpid()}-${time.sys_mono_now()}.txt')
	os.write_file(jar, '#HttpOnly_127.0.0.1\tFALSE\t/\tFALSE\t0\tsession\tfixture\n'
		+ '127.0.0.1\tFALSE\t/other\tFALSE\t0\tunrelated\tpath\n')!
	os.setenv('VOX_COOKIE_FILE', jar, true)
	defer {
		if value := previous { os.setenv('VOX_COOKIE_FILE', value, true) } else { os.unsetenv('VOX_COOKIE_FILE') }
		os.rm(jar) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/r/test/comments/1/'
	server := spawn serve_one_request(mut listener)
	settings, owner := imported_cookie_settings(address)
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := xhr.XMLHttpRequest.construct_in_settings(settings, connection.fetch_host())
	request.open('POST', '/api/morechildren', true, none, none)!
	request.set_request_header('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8')!
	request.send_text('link_id=t3_1&children=t1_2')!
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := owner
	loop.spin_until(fn [request, deadline] () bool {
		return request.state == .done || time.sys_mono_now() >= deadline
	})
	assert request.state == .done
	assert request.status() == 200
	received := server.wait()
	assert received.starts_with('POST /api/morechildren '), received
	assert received.to_lower().contains('\r\ncookie: session=fixture\r\n'), received
	assert received.ends_with('link_id=t3_1&children=t1_2'), received
}
