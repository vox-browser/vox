module browsernet

import adblock
import net
import time

fn serve_accept_fixture(mut listener net.TcpListener) []string {
	mut accepts := []string{}
	for hop in 0 .. 3 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(3 * time.second)
		mut bytes := []u8{len: 8192}
		length := socket.read(mut bytes) or { panic(err) }
		mut accept := ''
		for line in bytes[..length].bytestr().split('\r\n') {
			if line.to_lower().starts_with('accept:') { accept = line.all_after(':').trim_space() }
		}
		accepts << accept
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return accepts
}

fn test_image_accept_survives_redirects_and_other_requests_keep_the_generic_accept() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_accept_fixture(mut listener)
	address := 'http://${listener.addr()!}'
	assert get(adblock.Request{ url: address + '/start', source_url: address, request_type: 'image' }, '')!.response.body == 'ok'
	assert get(adblock.Request{ url: address + '/other', source_url: address, request_type: 'script' }, '')!.response.body == 'ok'
	assert server.wait() == [request_accept_header('image'), request_accept_header('image'), '*/*']
	$if macos {
		assert request_accept_header('image').starts_with('image/webp,')
	}
}
