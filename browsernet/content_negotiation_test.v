module browsernet

import adblock
import compress.brotli
import compress.gzip
import compress.zlib
import net
import net.http
import time

fn serve_compressed_browser_resources(mut listener net.TcpListener) []http.Header {
	mut requests := []http.Header{}
	for coding in ['gzip', 'deflate', 'br'] {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(3 * time.second)
		mut input := []u8{len: 8192}
		length := socket.read(mut input) or { panic(err) }
		request := http.parse_request_head_str(input[..length].bytestr()) or { panic(err) }
		requests << request.header
		body := [u8(0), 1, 127, 128, 255, 0, 42]
		compressed := match coding {
			'gzip' { gzip.compress(body) or { panic(err) } }
			'deflate' { zlib.compress(body) or { panic(err) } }
			else { brotli.compress(body) or { panic(err) } }
		}
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Encoding: ${coding}\r\nContent-Length: ${compressed.len}\r\nConnection: close\r\n\r\n' + compressed.bytestr()) or { panic(err) }
		socket.close() or {}
	}
	return requests
}

fn test_native_browser_negotiates_only_supported_codings_and_decodes_binary_responses() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_compressed_browser_resources(mut listener)
	address := 'http://${listener.addr()!}'
	for request_type in ['main_frame', 'script', 'image'] {
		response := get(adblock.Request{url: address, source_url: address, request_type: request_type}, '')!
		assert response.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	}
	headers := server.wait()
	for header in headers { assert header.get(.accept_encoding) or { panic(err) } == 'gzip, deflate, br' }
	assert headers[0].get(.accept) or { panic(err) } == 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
	assert headers[1].get(.accept) or { panic(err) } == '*/*'
	assert headers[2].get(.accept) or { panic(err) } == request_accept_header('image')
}

fn test_document_accept_does_not_change_script_and_image_content_negotiation() {
	assert request_accept_header('sub_frame') == request_accept_header('main_frame')
	assert request_accept_header('script') == '*/*'
	assert request_accept_header('stylesheet') == '*/*'
	assert request_accept_header('image').starts_with('image/')
}
