module browsernet

import adblock
import net
import os
import time

fn serve_imported_cookie_redirect(mut listener net.TcpListener) []string {
	mut requests := []string{}
	for hop in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(time.second)
		mut buffer := []u8{len: 8192}
		count := socket.read(mut buffer) or { panic(err) }
		requests << buffer[..count].bytestr()
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: /other\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return requests
}

fn test_network_navigation_recomputes_imported_cookie_header_after_redirect() {
	previous := os.getenv_opt('VOX_COOKIE_FILE')
	jar := os.join_path(os.temp_dir(), 'vox-cookie-test-${os.getpid()}-${time.sys_mono_now()}.txt')
	os.write_file(jar, '#HttpOnly_127.0.0.1\tFALSE\t/\tFALSE\t0\tsession\tfixture\n'
		+ '127.0.0.1\tFALSE\t/account\tFALSE\t0\tpage\taccount\n')!
	os.setenv('VOX_COOKIE_FILE', jar, true)
	defer {
		if value := previous { os.setenv('VOX_COOKIE_FILE', value, true) }
		else { os.unsetenv('VOX_COOKIE_FILE') }
		os.rm(jar) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(2 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_imported_cookie_redirect(mut listener)
	address := 'http://${listener.addr()!}'
	response := get(adblock.Request{
		url: '${address}/account/start'
		source_url: address
		request_type: 'main_frame'
	}, '')!
	assert response.response.body == 'ok'
	requests := server.wait()
	assert requests[0].to_lower().contains('cookie: page=account; session=fixture\r\n'), requests[0]
	assert requests[1].to_lower().contains('cookie: session=fixture\r\n'), requests[1]
	assert !requests[1].contains('page=account')
}
