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
	for header in headers {
		accept_encoding := header.get(.accept_encoding) or { panic('Missing Accept-Encoding header') }
		assert accept_encoding == 'gzip, deflate, br'
	}
	assert headers[0].get(.accept) or { panic('Missing document Accept header') } == request_accept_header('main_frame')
	assert headers[1].get(.accept) or { panic('Missing script Accept header') } == '*/*'
	assert headers[2].get(.accept) or { panic('Missing image Accept header') } == request_accept_header('image')
}

fn test_document_accept_does_not_change_script_and_image_content_negotiation() {
	assert request_accept_header('sub_frame') == request_accept_header('main_frame')
	assert request_accept_header('script') == '*/*'
	assert request_accept_header('stylesheet') == '*/*'
	assert request_accept_header('image').starts_with('image/')
}

fn serve_document_image_negotiation(mut listener net.TcpListener) []string {
	mut accepts := []string{}
	for hop in 0 .. 3 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(3 * time.second)
		mut input := []u8{len: 8192}
		length := socket.read(mut input) or { panic(err) }
		request := http.parse_request_head_str(input[..length].bytestr()) or { panic(err) }
		accept := request.header.get(.accept) or { '' }
		accepts << accept
		body := if accept.split(',').contains('image/webp') {
			'<img src="photo.webp">'
		} else {
			'<img src="photo.jpg">'
		}
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return accepts
}

fn test_navigation_negotiates_supported_images_in_html_across_redirects_and_frames() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_document_image_negotiation(mut listener)
	address := 'http://${listener.addr()!}'
	for request_type in ['main_frame', 'sub_frame'] {
		response := get(adblock.Request{url: address + '/start', source_url: address, request_type: request_type}, '')!
		$if macos {
			assert response.response.body == '<img src="photo.webp">'
		} $else {
			assert response.response.body == '<img src="photo.jpg">'
		}
	}
	assert server.wait() == [request_accept_header('main_frame'), request_accept_header('main_frame'), request_accept_header('sub_frame')]
}
