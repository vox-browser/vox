module browsernet

import browsercookies
import json2
import net.http
import os
import time

struct WebSocketFixturePorts {
	proxy_port int
	h1_port    int
	http_port  int
}

struct WebSocketFixtureRequest {
	url     string
	headers map[string]string
}

struct WebSocketFixtureStats {
	websockets  []WebSocketFixtureRequest
	proxy_hosts []string
	pongs       int
}

fn websocket_fixture() !(string, &os.Process, WebSocketFixturePorts) {
	node := os.find_abs_path_of_executable('node')!
	openssl := os.find_abs_path_of_executable('openssl')!
	directory := os.join_path(os.temp_dir(), 'vox-websocket-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	mut process := os.new_process(node)
	process.set_args([os.join_path(os.dir(@FILE), 'fixtures/http2_server.mjs'), directory, openssl])
	process.set_redirect_stdio()
	process.run()
	ready := os.join_path(directory, 'ready.json')
	for _ in 0 .. 1000 {
		if os.exists(ready) { break }
		if !process.is_alive() { return error(process.stderr_slurp()) }
		time.sleep(10 * time.millisecond)
	}
	return directory, process, json2.decode[WebSocketFixturePorts](os.read_file(ready)!)!
}

fn websocket_fixture_stats(directory string) WebSocketFixtureStats {
	return json2.decode[WebSocketFixtureStats](os.read_file(os.join_path(directory, 'stats.json')) or {
		panic(err)
	}) or { panic(err) }
}

// Collects events until `done` accepts them or five seconds pass.
fn websocket_events_until(mut connection WebSocketConnection, mut collected []WebSocketEvent, done fn ([]WebSocketEvent) bool) {
	deadline := time.sys_mono_now() + 5 * time.second
	for !done(collected) && time.sys_mono_now() < deadline {
		collected << connection.take_events()
		time.sleep(5 * time.millisecond)
	}
}

fn websocket_has(kind WebSocketEventKind) fn ([]WebSocketEvent) bool {
	return fn [kind] (events []WebSocketEvent) bool {
		return events.any(it.kind == kind)
	}
}

fn websocket_messages(events []WebSocketEvent) []string {
	return events.filter(it.kind == .message).map(if it.text { it.data.bytestr() } else { 'binary:${it.data.len}' })
}

fn test_websocket_exchanges_fragmented_text_binary_ping_and_close() {
	directory, mut process, ports := websocket_fixture() or {
		eprintln('SKIP WebSocket fixture: Node and OpenSSL required')
		return
	}
	defer {
		process.signal_kill()
		process.wait()
		process.close()
		os.rmdir_all(directory) or {}
	}
	os.setenv('VOX_PROXY', '', true)
	defer { os.unsetenv('VOX_PROXY') }
	mut connection := WebSocketConnection.open('ws://127.0.0.1:${ports.http_port}/ws/echo?room=1',
		'https://owner.example', 'https://owner.example/app', ['chat', 'other'], '', fn () {})
	mut events := []WebSocketEvent{}
	websocket_events_until(mut connection, mut events, fn (events []WebSocketEvent) bool {
		return websocket_messages(events).len >= 1
	})
	assert events.len >= 2, events.str()
	assert events[0].kind == .open && events[0].protocol == 'chat'
	// The greeting arrives as two fragments with a ping between them.
	assert websocket_messages(events) == ['hello']
	connection.send_text('hi')
	big := []u8{len: 70000, init: u8(index % 251)}
	connection.send_binary(big)
	connection.send_binary([u8(1), 2, 3])
	websocket_events_until(mut connection, mut events, fn (events []WebSocketEvent) bool {
		return websocket_messages(events).len >= 4
	})
	assert websocket_messages(events) == ['hello', 'echo:hi', 'binary:70000', 'binary:3']
	assert events.filter(it.kind == .message && !it.text)[0].data == big
	connection.close(1000, 'done')
	websocket_events_until(mut connection, mut events, websocket_has(.close))
	close := events.filter(it.kind == .close)
	assert close.len == 1 && close[0].was_clean && close[0].code == 1000, close.str()
	assert !events.any(it.kind == .error)
	stats := websocket_fixture_stats(directory)
	assert stats.pongs == 1
	request := stats.websockets[0]
	assert request.url == '/ws/echo?room=1'
	assert request.headers['origin'] == 'https://owner.example'
	assert request.headers['sec-websocket-protocol'] == 'chat, other'
	assert request.headers['sec-websocket-version'] == '13'
	// A same-site handshake stores its Set-Cookie for the matching HTTP URL,
	// and the next same-site handshake sends it back.
	site := 'http://127.0.0.1:${ports.http_port}'
	for _ in 0 .. 2 {
		mut same_site := WebSocketConnection.open('ws://127.0.0.1:${ports.http_port}/ws/cookie', site, '${site}/',
			[], '', fn () {})
		mut cookie_events := []WebSocketEvent{}
		websocket_events_until(mut same_site, mut cookie_events, websocket_has(.open))
		same_site.close(1000, '')
		websocket_events_until(mut same_site, mut cookie_events, websocket_has(.close))
	}
	assert browsercookies.request_header('${site}/ws/cookie', '${site}/', false, 'GET').contains('websocket=accepted')
	cookie_requests := websocket_fixture_stats(directory).websockets.filter(it.url == '/ws/cookie')
	assert cookie_requests.len == 2
	assert (cookie_requests[1].headers['cookie'] or { '' }).contains('websocket=accepted')
	deadline := time.sys_mono_now() + 2 * time.second
	for !connection.is_finished() && time.sys_mono_now() < deadline { time.sleep(5 * time.millisecond) }
	assert connection.is_finished()
}

fn test_secure_websocket_through_socks_proxy_and_server_close() {
	directory, mut process, ports := websocket_fixture() or {
		eprintln('SKIP WebSocket fixture: Node and OpenSSL required')
		return
	}
	defer {
		process.signal_kill()
		process.wait()
		process.close()
		os.rmdir_all(directory) or {}
		http.close_idle_connections()
	}
	os.setenv('VOX_PROXY', 'socks5h://127.0.0.1:${ports.proxy_port}', true)
	os.setenv('NO_PROXY', '', true)
	os.setenv('no_proxy', '', true)
	defer {
		os.unsetenv('VOX_PROXY')
		os.unsetenv('NO_PROXY')
		os.unsetenv('no_proxy')
	}
	ca := os.join_path(directory, 'ca.pem')
	mut connection := WebSocketConnection.open('wss://127.0.0.1:${ports.h1_port}/ws/secure', 'https://owner.example',
		'https://owner.example/', [], ca, fn () {})
	mut events := []WebSocketEvent{}
	websocket_events_until(mut connection, mut events, fn (events []WebSocketEvent) bool {
		return websocket_messages(events).len >= 1
	})
	assert events.len >= 2 && events[0].kind == .open && events[0].protocol == '', events.str()
	connection.send_text('close-me')
	websocket_events_until(mut connection, mut events, websocket_has(.close))
	close := events.filter(it.kind == .close)
	assert close.len == 1 && close[0].was_clean && close[0].code == 4001 && close[0].reason == 'bye', close.str()
	assert websocket_fixture_stats(directory).proxy_hosts == ['127.0.0.1']
	// An untrusted certificate fails the connection instead of opening it.
	mut untrusted := WebSocketConnection.open('wss://127.0.0.1:${ports.h1_port}/ws/secure', 'https://owner.example',
		'https://owner.example/', [], os.join_path(directory, 'untrusted-ca.pem'), fn () {})
	mut rejected := []WebSocketEvent{}
	websocket_events_until(mut untrusted, mut rejected, websocket_has(.close))
	assert rejected.map(it.kind) == [WebSocketEventKind.error, .close]
	assert !rejected[1].was_clean && rejected[1].code == 1006
}

fn test_websocket_handshake_rejection_fails_the_connection() {
	directory, mut process, ports := websocket_fixture() or {
		eprintln('SKIP WebSocket fixture: Node and OpenSSL required')
		return
	}
	defer {
		process.signal_kill()
		process.wait()
		process.close()
		os.rmdir_all(directory) or {}
	}
	os.setenv('VOX_PROXY', '', true)
	defer { os.unsetenv('VOX_PROXY') }
	mut connection := WebSocketConnection.open('ws://127.0.0.1:${ports.http_port}/ws/reject', 'https://owner.example',
		'https://owner.example/', [], '', fn () {})
	mut events := []WebSocketEvent{}
	websocket_events_until(mut connection, mut events, websocket_has(.close))
	assert events.map(it.kind) == [WebSocketEventKind.error, .close]
	assert !events[1].was_clean && events[1].code == 1006
	// close() before the handshake completes never opens the connection.
	mut early := WebSocketConnection.open('ws://127.0.0.1:${ports.http_port}/ws/echo', 'https://owner.example',
		'https://owner.example/', [], '', fn () {})
	early.close(1000, '')
	mut early_events := []WebSocketEvent{}
	websocket_events_until(mut early, mut early_events, websocket_has(.close))
	assert early_events.last().kind == .close
}

fn test_websocket_frames_and_targets() {
	target := websocket_target('wss://example.com:8443/socket?v=9&encoding=json')!
	assert target.secure && target.host == 'example.com' && target.port == 8443
	assert target.resource == '/socket?v=9&encoding=json'
	assert target.host_line == 'example.com:8443'
	assert target.http_url == 'https://example.com:8443/socket?v=9&encoding=json'
	assert websocket_target('ws://example.com/')!.host_line == 'example.com'
	if _ := websocket_target('https://example.com/') {
		assert false, 'http URL accepted as a WebSocket target'
	}
	// RFC 6455 section 1.3 example key.
	assert websocket_accept_value('dGhlIHNhbXBsZSBub25jZQ==') == 's3pPLMBiTxaQ9kYGzzhZRbK+xOo='
	frame := websocket_frame(1, 'Hello'.bytes())
	assert frame[0] == 0x81 && frame[1] == 0x85 && frame.len == 2 + 4 + 5
	mask := frame[2..6]
	assert [frame[6] ^ mask[0], frame[7] ^ mask[1], frame[8] ^ mask[2], frame[9] ^ mask[3], frame[10] ^ mask[0]].bytestr() == 'Hello'
	unmasked := [u8(0x81), 0x05, `H`, `e`, `l`, `l`, `o`, 0x89]
	parsed, used := websocket_parse_frame(unmasked)!
	assert parsed.fin && parsed.opcode == 1 && parsed.payload.bytestr() == 'Hello' && used == 7
	if _, _ := websocket_parse_frame(unmasked[7..]) {
		assert false, 'incomplete frame parsed'
	} else {
		assert err.msg() == 'incomplete'
	}
	if _, _ := websocket_parse_frame([u8(0x81), 0x85, 1, 2, 3, 4, 5]) {
		assert false, 'masked server frame accepted'
	}
	if _, _ := websocket_parse_frame([u8(0x09), 0x00]) {
		assert false, 'fragmented control frame accepted'
	}
	extended := [u8(0x82), 126, 0x01, 0x00]
	mut long := extended.clone()
	long << []u8{len: 256}
	long_frame, long_used := websocket_parse_frame(long)!
	assert long_frame.payload.len == 256 && long_used == 260
	assert websocket_close_payload(1000, 'ok') == [u8(0x03), 0xe8, `o`, `k`]
	assert websocket_close_payload(0, '') == []u8{}
}
