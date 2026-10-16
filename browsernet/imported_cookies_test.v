module browsernet

import adblock
import net
import os
import time

fn test_imported_cookie_jar_scopes_http_only_session_and_persistent_cookies() {
	jar := '# Netscape HTTP Cookie File\n'
		+ '#HttpOnly_.reddit.com\tTRUE\t/\tTRUE\t200\tsession\tsecret\n'
		+ 'old.reddit.com\tFALSE\t/r\tFALSE\t0\tview\tcompact\n'
		+ '.reddit.com\tTRUE\t/\tFALSE\t99\texpired\tno\n'
		+ '.reddit.com\tTRUE\t/\tFALSE\t100\tboundary\tno\n'
		+ '.reddit.com\tTRUE\t/\tFALSE\t0\tempty\t\n'
	assert imported_cookie_header(jar, 'https://old.reddit.com/r/worldnews/',
		'https://old.reddit.com/', 100) == 'view=compact; session=secret; empty='
	assert imported_cookie_header(jar, 'http://old.reddit.com/r/worldnews/',
		'http://old.reddit.com/', 100) == 'view=compact; empty='
	assert imported_cookie_header(jar, 'https://www.reddit.com/r/worldnews/',
		'https://old.reddit.com/', 100) == 'session=secret; empty='
	assert imported_cookie_header(jar, 'https://old.reddit.com/rubbish',
		'https://old.reddit.com/', 100) == 'session=secret; empty='
	assert imported_cookie_header(jar, 'https://old.reddit.com/r',
		'https://old.reddit.com/', 100) == 'view=compact; session=secret; empty='
}

fn test_imported_cookies_do_not_cross_site_scheme_or_domain_boundaries() {
	jar := '.reddit.com\tTRUE\t/\tFALSE\t0\tsession\tsecret\n'
	for address in ['https://notreddit.com/', 'https://reddit.com.evil.test/',
		'https://evilreddit.com/', 'file:///reddit.com/'] {
		assert imported_cookie_header(jar, address, address, 100) == ''
	}
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'https://evil.test/', 100) == ''
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'http://old.reddit.com/', 100) == ''
	assert imported_cookie_header(jar, 'https://old.reddit.com/', '', 100) == ''
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'https://old.reddit.com/', 100) == 'session=secret'
}

fn test_imported_cookie_parser_rejects_malformed_fields_and_header_injection() {
	mut jar := '# ignored\nnot a cookie\n'
	for domain in ['.com', 'reddit.com:443', 'user@reddit.com', 'reddit.com/path',
		'reddit.com?query', 'reddit.com#fragment'] {
		jar += '${domain}\tTRUE\t/\tFALSE\t0\tsession\tbad\n'
	}
	for name in ['bad name', 'bad=name', 'bad;name', 'bad\rname', ''] {
		jar += '.reddit.com\tTRUE\t/\tFALSE\t0\t${name}\tbad\n'
	}
	for value in ['bad;injected=1', 'bad\rX-Header:yes', 'bad value', 'bad\tvalue'] {
		jar += '.reddit.com\tTRUE\t/\tFALSE\t0\tsession\t${value}\n'
	}
	for expiry in ['invalid', '-1', '99999999999999999999999999999'] {
		jar += '.reddit.com\tTRUE\t/\tFALSE\t${expiry}\tsession\tbad\n'
	}
	jar += '.reddit.com\tTRUE\t/\tFALSE\t0\tvalid\ta=b%20c\r\n'
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'https://old.reddit.com/', 100) == 'valid=a=b%20c'
}

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
