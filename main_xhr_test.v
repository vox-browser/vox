module main

import browserjs
import dom
import html
import net
import time

fn serve_native_browser_xhr(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut bytes := []u8{len: 4096}
	_ := socket.read(mut bytes) or { panic(err) }
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 16\r\nConnection: close\r\n\r\nnative XHR paint') or { panic(err) }
}

fn test_native_browser_async_xhr_callback_replays_into_the_actual_document_before_paint() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_native_browser_xhr(mut listener)
	address := 'http://${listener.addr()!}/owner'
	mut document := html.parse_document_with_url('<div id="result">pending</div>', dom.URL{value: address})
	document.set_origin(document.url.origin())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, address, [r'
 const nativeRequest=new XMLHttpRequest();
 nativeRequest.onload=function(){document.getElementById("result").textContent=this.responseText;};
 nativeRequest.open("GET","/result");nativeRequest.send();
 '], runtime, mut messages)
	assert messages.len == 0
	assert document.get_element_by_id('result')?.text_content()? == 'pending'
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := html.main_thread_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('nativeRequest.readyState===XMLHttpRequest.DONE') or { 'false' }) == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('nativeRequest.readyState===XMLHttpRequest.DONE&&nativeRequest.status===200')! == 'true'
	assert runtime.evaluate_host('document.getElementById("result").textContent')! == 'native XHR paint'
	mut app := BrowserApp{ document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 200 }
	app.poll_javascript_tasks()
	assert app.js_messages.len == 0
	assert document.get_element_by_id('result')?.text_content()? == 'native XHR paint'
	assert !runtime.take_document_state_dirty()
	server.wait()
}
