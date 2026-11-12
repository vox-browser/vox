module browsernet

import adblock
import browsercookies
import net
import net.http
import os
import time

fn serve_persistent_cookie_navigation(mut listener net.TcpListener) []string {
	mut cookies := []string{}
	for hop in 0 .. 3 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(3 * time.second)
		mut bytes := []u8{len: 8192}
		count := socket.read(mut bytes) or { panic(err) }
		request := http.parse_request_head_str(bytes[..count].bytestr()) or { panic(err) }
		cookies << request.header.get(.cookie) or { '' }
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: /search\r\nSet-Cookie: verification=saved; Path=/; Max-Age=600; HttpOnly\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return cookies
}

fn test_navigation_redirect_and_reopened_profile_share_persistent_cookies() {
	previous_proxy := os.getenv_opt('VOX_PROXY')
	os.setenv('VOX_PROXY', '', true)
	defer {
		if value := previous_proxy { os.setenv('VOX_PROXY', value, true) }
		else { os.unsetenv('VOX_PROXY') }
	}
	directory := os.join_path(os.temp_dir(), 'vox-navigation-cookies-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer {
		browsercookies.initialize('') or { panic(err) }
		os.rmdir_all(directory) or {}
	}
	path := os.join_path(directory, 'cookies.json')
	browsercookies.initialize(path)!
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	server := spawn serve_persistent_cookie_navigation(mut listener)
	scope := new_request_scope()
	defer { scope.release() }
	// The actual browser navigation uses the cancellable curl transport.
	result := get_with_scope(adblock.Request{
		url: '${address}/start', source_url: address, request_type: 'main_frame'
	}, '', scope)!
	assert result.response.status_code == 200
	assert result.response.body == 'ok'
	assert result.url == '${address}/search'
	// Drop the entire process-local jar before exercising the other transport.
	browsercookies.initialize(path)!
	assert get(adblock.Request{
		url: '${address}/search?q=next', source_url: address, request_type: 'main_frame'
	}, '')!.response.body == 'ok'
	assert server.wait() == ['', 'verification=saved', 'verification=saved']
}
