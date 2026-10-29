// Compile against the modules from tools/prepare_http_compat.py.
module main

import net
import net.http
import time

fn serve_targets(mut listener net.TcpListener, count int) []string {
	mut targets := []string{}
	for _ in 0 .. count {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(2 * time.second)
		mut bytes := []u8{len: 4096}
		length := socket.read(mut bytes) or { panic(err) }
		targets << bytes[..length].bytestr().all_before('\r\n')
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok') or { panic(err) }
		socket.close() or {}
	}
	return targets
}

fn main() {
	targets := [
		'/css2?family=DM+Sans:wght@400;450;500;550;600;650;700&family=IBM+Plex+Mono:wght@400;500&display=swap',
		'/asset?z=%2f&a=one+two&z=%2F&flag&&empty=',
		'//nested///path?value=a;b',
		'/empty?',
		'/plain',
	]
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	server := spawn serve_targets(mut listener, targets.len)
	for target in targets {
		response := http.fetch(url: address + target, allow_redirect: false)!
		assert response.body == 'ok'
	}
	assert server.wait() == targets.map('GET ${it} HTTP/1.1')
	println('HTTP request targets preserved: semicolons, duplicate keys, escapes, order and empty query')
}
