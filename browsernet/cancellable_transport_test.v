module browsernet

import net
import net.http
import io
import time

#include <errno.h>

fn serve_cancelled_resource(mut listener net.TcpListener, partial_body bool,
	started chan bool, closed chan bool) {
	mut connection := listener.accept() or {
		closed <- false
		return
	}
	defer { connection.close() or {} }
	connection.set_read_timeout(3 * time.second)
	mut request := ''
	for !request.contains('\r\n\r\n') {
		mut buffer := []u8{len: 4096}
		count := connection.read(mut buffer) or {
			closed <- false
			return
		}
		if count == 0 {
			closed <- false
			return
		}
		request += buffer[..count].bytestr()
	}
	if partial_body {
		connection.write_string('HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\npartial') or {
			closed <- false
			return
		}
	}
	started <- true
	mut buffer := []u8{len: 1}
	count := connection.read(mut buffer) or {
		// Closing a socket with an unread response can send RST instead of FIN.
		// Both retire the transport; a read timeout is deliberately rejected.
		closed <- err is io.Eof || err.code() == int(C.ECONNRESET)
		return
	}
	closed <- count == 0
}

fn fetch_cancelled_resource(address string, scope &RequestScope, finished chan int) {
	defer { scope.release() }
	scope.acquire_request_slot() or {
		finished <- err.code()
		return
	}
	defer { release_request_slot() }
	mut progress := ResponseBodyProgress{}
	fetch_cancellable(http.FetchConfig{ url: address }, scope, mut progress) or {
		finished <- err.code()
		return
	}
	finished <- 0
}

fn check_stalled_resource_cancellation(partial_body bool) {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0') or { panic(err) }
	defer { listener.close() or {} }
	scope := new_request_scope()
	defer { scope.release() }
	started := chan bool{cap: 1}
	closed := chan bool{cap: 1}
	finished := chan int{cap: 1}
	server := spawn serve_cancelled_resource(mut listener, partial_body, started, closed)
	scope.retain()
	spawn fetch_cancelled_resource('http://${listener.addr() or { panic(err) }}/stall', scope, finished)
	select {
		_ := <-started {
		}
		3 * time.second {
			assert false, 'The transport never reached the controlled server'
		}
	}
	scope.cancel()
	select {
		code := <-finished {
			assert code == request_cancelled_code
		}
		2 * time.second {
			assert false, 'A stalled request ignored cancellation'
		}
	}
	select {
		was_closed := <-closed {
			assert was_closed, 'Cancelled transport left the origin connection open'
		}
		2 * time.second {
			assert false, 'The origin did not observe transport retirement'
		}
	}
	server.wait()
}

fn test_cancellation_stops_a_request_waiting_for_response_headers() {
	check_stalled_resource_cancellation(false)
}

fn test_cancellation_stops_a_request_with_a_stalled_response_body() {
	check_stalled_resource_cancellation(true)
}

fn serve_cancellable_resource(mut listener net.TcpListener) {
	mut connection := listener.accept() or { panic(err) }
	defer { connection.close() or {} }
	connection.set_read_timeout(3 * time.second)
	mut request := ''
	for !request.contains('\r\n\r\n') {
		mut buffer := []u8{len: 4096}
		count := connection.read(mut buffer) or { panic(err) }
		assert count > 0
		request += buffer[..count].bytestr()
	}
	assert request.contains('Accept: image/webp')
	assert request.contains('User-Agent: Vox lifecycle test')
	connection.write_string('HTTP/1.1 201 Native reason\r\nContent-Length: 4\r\nContent-Type: image/test\r\nSet-Cookie: first=1\r\nSet-Cookie: second=2\r\nConnection: close\r\n\r\nbody') or { panic(err) }
}

fn test_cancellable_transport_preserves_response_and_request_metadata() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0') or { panic(err) }
	defer { listener.close() or {} }
	server := spawn serve_cancellable_resource(mut listener)
	scope := new_request_scope()
	defer { scope.release() }
	mut progress := ResponseBodyProgress{}
	before := time.now().unix_milli()
	result := fetch_cancellable(http.FetchConfig{
		url:        'http://${listener.addr() or { panic(err) }}/resource'
		user_agent: 'Vox lifecycle test'
		header:     http.new_header(key: .accept, value: 'image/webp')
	}, scope, mut progress) or { panic(err) }
	assert result.response.status_code == 201
	assert result.response.status_msg == 'Native reason'
	assert result.response.body == 'body'
	assert result.response.header.custom_values('Set-Cookie') == ['first=1', 'second=2']
	assert result.response.header.get(.content_type) or { '' } == 'image/test'
	assert result.response_time >= before
	assert result.response_time <= time.now().unix_milli()
	server.wait()
}
