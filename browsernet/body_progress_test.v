module browsernet

import adblock
import net
import time

fn serve_progress_response(mut listener net.TcpListener, chunked bool) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	framing := if chunked { 'Transfer-Encoding: chunked' } else { 'Content-Length: 256' }
	socket.write_string('HTTP/1.1 200 OK\r\n${framing}\r\nConnection: close\r\n\r\n') or { panic(err) }
	for index in 0 .. 2 {
		if chunked { socket.write_string('80\r\n') or { panic(err) } }
		socket.write_string('x'.repeat(128)) or { panic(err) }
		if chunked { socket.write_string('\r\n') or { panic(err) } }
		if index == 0 { time.sleep(500 * time.millisecond) }
	}
	if chunked { socket.write_string('0\r\n\r\n') or { panic(err) } }
}

fn test_http_image_responses_preserve_available_prefixes_for_known_and_chunked_lengths() {
	for chunked in [false, true] {
		mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
		server := spawn serve_progress_response(mut listener, chunked)
		address := 'http://${listener.addr()!}/image'
		result := get(adblock.Request{url: address, source_url: address, request_type: 'image'}, '')!
		assert result.response.body == 'x'.repeat(256)
		assert result.bytes_available_before_completion == 128
		server.wait()
		listener.close()!
	}
}

fn test_body_progress_does_not_invent_an_incremental_prefix_for_one_buffered_delivery() {
	for expected in [u64(0), 256] {
		mut progress := ResponseBodyProgress{}
		progress.observe('x'.repeat(256).bytes(), 256, expected, 200)
		assert progress.incomplete_prefix == 0
	}
	mut redirected := ResponseBodyProgress{}
	redirected.observe('x'.repeat(64).bytes(), 64, 128, 302)
	assert redirected.incomplete_prefix == 0
	assert redirected.prefix.len == 0
}
