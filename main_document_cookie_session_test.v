module main

import adblock
import browsercookies
import browserjs
import browsernet
import dom
import html
import net
import time

fn cookie_fixture_request(mut socket net.TcpConn) string {
	socket.set_read_timeout(5 * time.second)
	mut input := ''
	for !input.contains('\r\n\r\n') {
		mut buffer := []u8{len: 4096}
		count := socket.read(mut buffer) or { panic(err) }
		assert count > 0
		input += buffer[..count].bytestr()
	}
	return input
}

fn fixture_cookie_header(input string) string {
	for line in input.split('\r\n') {
		if line.to_lower().starts_with('cookie:') { return line.all_after(':').trim_space() }
	}
	return ''
}

fn serve_cookie_session_fixture(mut listener net.TcpListener, path string) []string {
	mut observed := []string{}
	for index in 0 .. 5 {
		mut socket := listener.accept() or { panic(err) }
		input := cookie_fixture_request(mut socket)
		observed << fixture_cookie_header(input)
		headers := match index {
			0 { 'HTTP/1.1 302 Found\r\nLocation: ${path}page\r\nSet-Cookie: nav=server; HttpOnly; Path=${path}\r\n' }
			1 { 'HTTP/1.1 200 OK\r\nSet-Cookie: csrf=initial; Path=${path}\r\n' }
			2 { 'HTTP/1.1 200 OK\r\nSet-Cookie: ignored=omit; Path=${path}\r\n' }
			3 { 'HTTP/1.1 200 OK\r\nSet-Cookie: csrf=updated; Path=${path}\r\nSet-Cookie: transport=fetch; HttpOnly; Path=${path}\r\n' }
			else { 'HTTP/1.1 200 OK\r\nSet-Cookie: js=xhr; Path=${path}\r\n' }
		}
		socket.write_string(headers + 'Content-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok') or { panic(err) }
		socket.close() or {}
	}
	return observed
}

fn test_browser_navigation_document_fetch_and_xhr_use_one_cookie_session() {
	$if !darwin && !linux { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(8 * time.second)
	defer { listener.close() or {} }
	base := 'http://${listener.addr()!}'
	path := '/native-cookie-${listener.addr()!.port()!}/'
	server := spawn serve_cookie_session_fixture(mut listener, path)
	loaded := browsernet.get(adblock.Request{url: base + path + 'start', source_url: base, request_type: 'main_frame'}, '')!
	assert loaded.url == base + path + 'page'
	mut document := parse_browser_navigation_document('<!doctype html><p>cookies</p>', dom.URL{value: loaded.url}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, loaded.url, [r'
globalThis.cookieBefore=document.cookie;
document.cookie="js=script; Path="+location.pathname.slice(0,location.pathname.lastIndexOf("/")+1);
globalThis.cookieDone=false;globalThis.cookieFailure="";
fetch("omit",{credentials:"omit"}).then(r=>r.text()).then(()=>fetch("fetch")).then(r=>r.text()).then(()=>{
 globalThis.cookieAfterFetch=document.cookie;
 const request=new XMLHttpRequest();
 request.open("GET","xhr");request.onload=()=>{globalThis.cookieAfterXHR=document.cookie;cookieDone=true;};
 request.onerror=()=>{cookieFailure="xhr failed";cookieDone=true;};request.send();
}).catch(error=>{cookieFailure=String(error);cookieDone=true;});
'], runtime, mut messages)
	assert messages == []
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := html.main_thread_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('cookieDone') or { 'false' }) == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('cookieDone+":"+cookieFailure')! == 'true:'
	assert runtime.evaluate_host('cookieBefore')! == 'csrf=initial'
	assert runtime.evaluate_host('cookieAfterFetch')! == 'csrf=updated; js=script'
	assert runtime.evaluate_host('cookieAfterXHR')! == 'csrf=updated; js=xhr'
	assert server.wait() == ['', 'nav=server', '', 'nav=server; csrf=initial; js=script', 'nav=server; csrf=updated; js=script; transport=fetch']
}

fn serve_cross_origin_cookie_fixture(mut listener net.TcpListener, path string, origin string) []string {
	mut observed := []string{}
	for index in 0 .. 3 {
		mut socket := listener.accept() or { panic(err) }
		observed << fixture_cookie_header(cookie_fixture_request(mut socket))
		name := ['default', 'include', 'omit'][index]
		socket.write_string('HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: ${origin}\r\nAccess-Control-Allow-Credentials: true\r\nSet-Cookie: ${name}=response; Path=${path}\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok') or { panic(err) }
		socket.close() or {}
	}
	return observed
}

fn test_cross_origin_fetch_requires_include_and_omit_rejects_response_cookies() {
	$if !darwin && !linux { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(8 * time.second)
	defer { listener.close() or {} }
	// Ports create different origins while retaining a same-site HTTP context.
	mut owner_listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { owner_listener.close() or {} }
	origin := 'http://${owner_listener.addr()!}'
	target := 'http://${listener.addr()!}'
	path := '/cross-cookie-${listener.addr()!.port()!}/'
	browsercookies.store_response_cookies(target + path, origin, false, 'GET', ['seed=initial; Path=${path}'])
	server := spawn serve_cross_origin_cookie_fixture(mut listener, path, origin)
	address := origin + path + 'page'
	mut document := parse_browser_navigation_document('<!doctype html>', dom.URL{value: address}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	source := 'globalThis.cookieDone=false;globalThis.cookieFailure="";fetch("${target}${path}default").then(r=>r.text()).then(()=>fetch("${target}${path}include",{credentials:"include"})).then(r=>r.text()).then(()=>fetch("${target}${path}omit",{credentials:"omit"})).then(r=>r.text()).then(()=>{cookieDone=true}).catch(error=>{cookieFailure=String(error);cookieDone=true;});'
	run_document_javascript(document, address, [source], runtime, mut messages)
	assert messages == []
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := html.main_thread_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('cookieDone') or { 'false' }) == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('cookieDone+":"+cookieFailure')! == 'true:'
	assert runtime.evaluate_host('document.cookie')! == 'seed=initial; include=response'
	assert server.wait() == ['', 'seed=initial', '']
}
