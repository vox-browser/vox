// Ordinary production executable: V test assertions do not survive -prod.
// Exercises actual XHR, native HTTP transport and owning DOM event dispatch.
module main

import dom
import html
import net
import requestserver
import time
import xhr

@[heap]
struct Completion {
mut:
	loaded bool
}

fn serve(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	socket.write_string('HTTP/1.1 200 Production\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Length: 15\r\nConnection: close\r\n\r\nproduction data') or { panic(err) }
}

fn main() {
	$if !darwin { panic('Native XHR production smoke requires the macOS host') }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0') or { panic(err) }
	defer { listener.close() or {} }
	server := spawn serve(mut listener)
	address := listener.addr() or { panic(err) }
	mut document := dom.Document.create(dom.URL{value: 'http://${address}/owner'})
	document.set_origin(document.url.origin())
	_ := html.WindowModel.create_top_level(document, none, '') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut connection := requestserver.CurlConnection.create() or { panic(err) }
	defer { connection.close() }
	mut request := xhr.XMLHttpRequest.construct_in_settings(settings, connection.fetch_host())
	completion := &Completion{}
	request.set_event_handler_callback('load', &dom.CallbackType{ handle_event: fn [completion] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		mut state := unsafe { &Completion(completion) }
		state.loaded = true
		return dom.js_undefined()
	} })
	request.open('GET', '/production', true, none, none) or { panic(err) }
	request.send() or { panic(err) }
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := html.main_thread_event_loop()
	loop.spin_until(fn [completion, deadline] () bool {
		return completion.loaded || time.sys_mono_now() >= deadline
	})
	actual := request.response_text() or { panic(err) }
	if !completion.loaded || request.status() != 200 || request.status_text() != 'Production' || actual != 'production data' || !request.response_url().ends_with('/production') {
		panic('Native production XHR failed: ${request.status()} ${actual}')
	}
	server.wait()
	println('Native production XMLHttpRequest transport passed')
}
