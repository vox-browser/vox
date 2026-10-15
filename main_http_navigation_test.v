module main

import net
import os
import time

fn serve_http_navigation_responses(mut listener net.TcpListener, responses []string) {
	for response in responses {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(2 * time.second)
		mut input := []u8{len: 4096}
		_ := socket.read(mut input) or { panic(err) }
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
}

fn http_navigation_response(status string, content_type string, body string) string {
	return 'HTTP/1.1 ${status}\r\nContent-Type: ${content_type}\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}'
}

fn test_http_navigation_renders_error_documents_without_caching_them() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-http-navigation-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	markup := '<!doctype html><title>Verification</title><h1>Checking your browser</h1><script src="/verify.js"></script>'
	statuses := ['403 Forbidden', '404 Not Found', '429 Too Many Requests', '503 Service Unavailable']
	server := spawn serve_http_navigation_responses(mut listener, statuses.map(http_navigation_response(it, 'text/html; charset=UTF-8', markup)))
	for status in statuses {
		address := 'http://${listener.addr()!}/${status.all_before(' ')}'
		loaded := fetch_page(address, '')!
		assert loaded.url == address
		assert loaded.markup == markup
		assert loaded.status.starts_with('HTTP ${status.all_before(' ')} · ')
		assert read_cached_page(address) == none
	}
	server.wait()
}

fn test_http_navigation_challenge_preserves_final_url_and_successful_cache() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-http-redirect-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	good := '<!doctype html><title>Questions</title>'
	challenge := '<!doctype html><title>Just a moment...</title><script src="./verify.js"></script>'
	server := spawn serve_http_navigation_responses(mut listener, [
		http_navigation_response('200 OK', 'text/html', good),
		'HTTP/1.1 302 Found\r\nLocation: /questions\r\nContent-Length: 0\r\nConnection: close\r\n\r\n',
		http_navigation_response('403 Forbidden', 'text/html', challenge),
		http_navigation_response('200 OK', 'text/html', good + '<p>Recovered</p>'),
	])
	assert fetch_page('${address}/questions', '')!.markup == good
	assert read_cached_page('${address}/questions')?.markup == good
	loaded := fetch_page('${address}/', '')!
	assert loaded.url == '${address}/questions'
	assert loaded.markup == challenge
	assert resolve_document_reference('./verify.js', loaded.url) == '${address}/verify.js'
	assert read_cached_page('${address}/questions')?.markup == good
	assert fetch_page('${address}/questions', '')!.markup == good + '<p>Recovered</p>'
	assert read_cached_page('${address}/questions')?.markup == good + '<p>Recovered</p>'
	server.wait()
}

fn test_http_navigation_escapes_text_errors_and_reports_empty_errors() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_http_navigation_responses(mut listener, [
		http_navigation_response('500 Internal Server Error', 'text/plain', '<script>bad()</script>&'),
		http_navigation_response('403 Forbidden', 'text/html', ''),
	])
	address := 'http://${listener.addr()!}'
	loaded := fetch_page('${address}/text', '')!
	assert loaded.markup.contains('<pre>&lt;script&gt;bad()&lt;/script&gt;&amp;</pre>')
	mut failed := false
	_ := fetch_page('${address}/empty', '') or {
		failed = true
		assert err.msg() == 'HTTP 403 Forbidden'
		LoadedPage{}
	}
	assert failed
	server.wait()
}
