module browsernet

import adblock
import net
import time

fn serve_adblock_redirect_fixture(mut listener net.TcpListener, target string) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	socket.write_string('HTTP/1.1 302 Found\r\nLocation: ${target}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {
		panic(err)
	}
}

fn serve_adblock_allowed_fixture(mut listener net.TcpListener) []string {
	mut requests := []string{}
	for hop in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(time.second)
		mut input := []u8{len: 4096}
		count := socket.read(mut input) or { panic(err) }
		requests << input[..count].bytestr().all_before('\r\n')
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: ../final?allowed=1\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 7\r\nConnection: close\r\n\r\nallowed'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return requests
}

fn test_default_filter_blocks_tracker_before_network_transport() {
	assert adblock.is_enabled()
	_ := get(adblock.Request{
		url:          'https://www.google-analytics.com/g/collect?v=2'
		source_url:   'https://www.theverge.com/'
		request_type: 'xmlhttprequest'
	}, '') or {
		assert err.msg().starts_with('Blocked by adblock:'), err.msg()
		return
	}
	assert false, 'tracker unexpectedly reached the network'
}

fn test_http_redirect_target_is_filtered_before_following_it() {
	_ := filter(adblock.Request{ url: 'http://127.0.0.1/', request_type: 'xmlhttprequest' })!
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(2 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_adblock_redirect_fixture(mut listener,
		'https://www.google-analytics.com/g/collect?v=2')
	_ := get(adblock.Request{
		url:          'http://${listener.addr()!}/redirect'
		source_url:   'https://www.theverge.com/'
		request_type: 'xmlhttprequest'
	}, '') or {
		server.wait()
		assert err.msg().starts_with('Blocked by adblock:'), err.msg()
		return
	}
	server.wait()
	assert false, 'redirected tracker unexpectedly reached the network'
}

fn test_allowed_redirect_keeps_final_document_url_and_resolves_relative_location() {
	_ := filter(adblock.Request{ url: 'http://127.0.0.1/', request_type: 'main_frame' })!
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(2 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_adblock_allowed_fixture(mut listener)
	address := 'http://${listener.addr()!}'
	result := get(adblock.Request{
		url:          '${address}/nested/start'
		source_url:   address
		request_type: 'main_frame'
	}, '')!
	assert result.url == '${address}/final?allowed=1'
	assert result.response.status_code == 200
	assert result.response.body == 'allowed'
	assert server.wait() == ['GET /nested/start HTTP/1.1', 'GET /final?allowed=1 HTTP/1.1']
}
