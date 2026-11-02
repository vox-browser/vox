module browsernet

import adblock
import json2
import net.http
import os
import time

struct HTTP2TLSFixture {
	directory       string
	h2_port         int
	h1_port         int
	wrong_host_port int
	process         &os.Process = unsafe { nil }
}

struct HTTP2TLSReady {
	h2_port         int
	h1_port         int
	wrong_host_port int
	node_version    string
}

struct HTTP2TLSStats {
	handshakes     map[string]int
	maximum_active int
	requests       []HTTP2TLSRequest
}

struct HTTP2TLSRequest {
	url      string
	method   string
	protocol string
	headers  map[string]string
}

struct HTTP2TLSReply {
	response HTTPResult
	error    string
}

fn start_http2_tls_fixture() ?HTTP2TLSFixture {
	node := os.find_abs_path_of_executable('node') or { return none }
	openssl := os.find_abs_path_of_executable('openssl') or { return none }
	directory := os.join_path(os.temp_dir(), 'vox-http2-tls-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	mut process := os.new_process(node)
	process.set_args([os.join_path(os.dir(@FILE), 'fixtures/http2_server.mjs'), directory, openssl])
	process.set_redirect_stdio()
	process.run()
	ready := os.join_path(directory, 'ready.json')
	for _ in 0 .. 1000 {
		if os.exists(ready) {
			ports := json2.decode[HTTP2TLSReady](os.read_file(ready) or { panic(err) }) or { panic(err) }
			return HTTP2TLSFixture{ directory: directory, h2_port: ports.h2_port, h1_port: ports.h1_port, wrong_host_port: ports.wrong_host_port, process: process }
		}
		if !process.is_alive() { panic('TLS fixture exited: ${process.stderr_slurp()}') }
		time.sleep(10 * time.millisecond)
	}
	process.signal_kill()
	panic('Timed out starting local TLS fixture')
}

fn (fixture HTTP2TLSFixture) close() {
	mut process := fixture.process
	process.signal_kill()
	process.wait()
	process.close()
	os.rmdir_all(fixture.directory) or {}
}

fn http2_tls_request(address string) adblock.Request {
	return adblock.Request{ url: address, source_url: 'https://www.theverge.com/', request_type: 'image' }
}

fn http2_tls_fixture_get(address string, ca string, replies chan HTTP2TLSReply) {
	response := get(http2_tls_request(address), ca) or {
		replies <- HTTP2TLSReply{ error: err.msg() }
		return
	}
	replies <- HTTP2TLSReply{ response: response }
}

fn test_https_preloads_multiplex_distinct_requests_and_preserve_binary_gzip_headers() {
	fixture := start_http2_tls_fixture() or {
		eprintln('SKIP HTTP2 TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	ca := os.join_path(fixture.directory, 'ca.pem')
	address := 'https://127.0.0.1:${fixture.h2_port}'
	replies := chan HTTP2TLSReply{cap: 6}
	for index in 0 .. 6 { spawn http2_tls_fixture_get('${address}/pooled/${index}', ca, replies) }
	for _ in 0 .. 6 {
		reply := <-replies
		assert reply.error == '', reply.error
		assert reply.response.response.status_code == 200
		assert reply.response.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	}
	stats := json2.decode[HTTP2TLSStats](os.read_file(os.join_path(fixture.directory, 'stats.json')) or { panic(err) }) or { panic(err) }
	assert stats.handshakes['h2'] == 1
	assert stats.maximum_active > 1
	compressed := get(http2_tls_request('${address}/gzip'), ca) or { panic(err) }
	assert compressed.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	assert compressed.response.header.get(.content_type) or { '' } == 'application/octet-stream'
	assert compressed.response.header.custom_values('X-Fixture') == ['retained']
	http.close_idle_connections()
}

fn assert_http2_tls_redirect_blocked(address string, ca string) {
	_ := get(http2_tls_request('${address}/blocked-redirect'), ca) or {
		assert err.msg().starts_with('Blocked by adblock:'), err.msg()
		return
	}
	assert false, 'redirected tracker reached transport'
}

fn test_https_http1_fallback_and_manual_redirect_filtering_remain_enabled() {
	fixture := start_http2_tls_fixture() or {
		eprintln('SKIP HTTP2 TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	ca := os.join_path(fixture.directory, 'ca.pem')
	for port in [fixture.h1_port, fixture.h2_port] {
		address := 'https://127.0.0.1:${port}'
		response := get(http2_tls_request('${address}/dir/redirect'), ca) or { panic(err) }
		assert response.url == '${address}/binary?allowed=1'
		assert response.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
		assert_http2_tls_redirect_blocked(address, ca)
	}
	http.close_idle_connections()
}

fn test_https_pool_does_not_bypass_ca_or_hostname_validation() {
	fixture := start_http2_tls_fixture() or {
		eprintln('SKIP HTTP2 TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	ca := os.join_path(fixture.directory, 'ca.pem')
	address := 'https://127.0.0.1:${fixture.h2_port}/binary'
	trusted := get(http2_tls_request(address), ca) or { panic(err) }
	assert trusted.response.status_code == 200
	if response := get(http2_tls_request(address), os.join_path(fixture.directory, 'untrusted-ca.pem')) {
		assert false, 'untrusted CA accepted: ${response.url}'
	}
	if response := get(http2_tls_request('https://127.0.0.1:${fixture.wrong_host_port}/binary'), ca) {
		assert false, 'incorrect certificate hostname accepted: ${response.url}'
	}
	http.close_idle_connections()
}

fn http2_tls_stats(fixture HTTP2TLSFixture) HTTP2TLSStats {
	return json2.decode[HTTP2TLSStats](os.read_file(os.join_path(fixture.directory, 'stats.json')) or { panic(err) }) or { panic(err) }
}

fn test_https_http2_timeout_recovers_navigation_and_keeps_redirect_filtering() {
	fixture := start_http2_tls_fixture() or {
		eprintln('SKIP HTTP2 TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	defer { http.close_idle_connections() }
	ca := os.join_path(fixture.directory, 'ca.pem')
	address := 'https://127.0.0.1:${fixture.h2_port}'
	result := get(adblock.Request{url: '${address}/timeout/redirect', source_url: address,
		request_type: 'main_frame'}, ca)!
	assert result.url == '${address}/binary?recovered=1'
	assert result.response.status_code == 200
	assert result.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	if response := get(http2_tls_request('${address}/timeout/blocked-redirect'), ca) {
		assert false, 'redirected tracker reached transport: ${response.url}'
	} else {
		assert err.msg().starts_with('Blocked by adblock:'), err.msg()
	}
	stats := http2_tls_stats(fixture)
	assert stats.requests.map(it.protocol) == ['2.0', '1.1', '2.0', '2.0', '1.1']
	assert stats.requests.map(it.url) == ['/timeout/redirect', '/timeout/redirect',
		'/binary?recovered=1', '/timeout/blocked-redirect', '/timeout/blocked-redirect']
	for request in stats.requests {
		assert request.method == 'GET'
		request_type := if request.url == '/timeout/blocked-redirect' { 'image' } else { 'main_frame' }
		assert request.headers['accept'] == request_accept_header(request_type)
		assert request.headers['accept-encoding'] == 'gzip, deflate, br'
		assert request.headers['user-agent'] == stats.requests[0].headers['user-agent']
	}
}

fn test_https_timeout_retry_discards_abandoned_body_progress_and_preserves_headers() {
	fixture := start_http2_tls_fixture() or {
		eprintln('SKIP HTTP2 TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	defer { http.close_idle_connections() }
	mut progress := &ResponseBodyProgress{}
	response := fetch_with_timeout_recovery(http.FetchConfig{
		url: 'https://127.0.0.1:${fixture.h2_port}/timeout/partial'
		header: http.new_header_from_map({http.CommonHeader.cookie: 'retry=retained'})
		user_agent: 'Vox timeout recovery test'
		enable_http2: true
		allow_redirect: false
		validate: true
		verify: os.join_path(fixture.directory, 'ca.pem')
		read_timeout: 500 * time.millisecond
		write_timeout: time.second
		on_progress_body: fn [mut progress] (_ &http.Request, chunk []u8,
			received u64, expected u64, status int) ! {
			progress.observe(chunk, received, expected, status)
		}
	}, mut progress)!
	assert response.body == 'x'.repeat(64)
	assert progress.previous == 64
	assert progress.incomplete_prefix == 0
	assert progress.prefix.bytestr() == 'x'.repeat(32)
	stats := http2_tls_stats(fixture)
	assert stats.requests.map(it.protocol) == ['2.0', '1.1']
	assert stats.handshakes['h2'] == 2
	for request in stats.requests {
		assert request.url == '/timeout/partial'
		assert request.headers['cookie'] == 'retry=retained'
		assert request.headers['user-agent'] == 'Vox timeout recovery test'
	}
}

fn test_https_timeout_recovery_is_bounded_and_does_not_replay_post_or_http1() {
	fixture := start_http2_tls_fixture() or {
		eprintln('SKIP HTTP2 TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	defer { http.close_idle_connections() }
	base := http.FetchConfig{
		url: 'https://127.0.0.1:${fixture.h2_port}/never-responds'
		enable_http2: true
		allow_redirect: false
		validate: true
		verify: os.join_path(fixture.directory, 'ca.pem')
		read_timeout: 500 * time.millisecond
		write_timeout: time.second
		max_retries: 1
	}
	for config in [base, http.FetchConfig{...base, method: .post, data: 'do not replay'},
		http.FetchConfig{...base, url: 'https://127.0.0.1:${fixture.h1_port}/never-responds'},
		http.FetchConfig{...base, enable_http2: false}] {
		before := http2_tls_stats(fixture).requests.len
		mut progress := ResponseBodyProgress{}
		if response := fetch_with_timeout_recovery(config, mut progress) {
			assert false, 'stalled response returned ${response.status_code}'
		} else {
			assert err.msg().contains('timed out') || err.msg().contains('did not receive any data'), err.msg()
		}
		after := http2_tls_stats(fixture)
		expected := if config.method == .get && config.enable_http2 && config.url == base.url { 2 } else { 1 }
		assert after.requests.len - before == expected
		if expected == 2 {
			assert after.requests[before..].map(it.protocol) == ['2.0', '1.1']
		}
	}
	mut progress := ResponseBodyProgress{}
	response := fetch_with_timeout_recovery(http.FetchConfig{
		...base
		url: 'https://127.0.0.1:${fixture.h2_port}/unavailable'
	}, mut progress)!
	assert response.status_code == 503
	assert response.body == 'unavailable'
	stats := http2_tls_stats(fixture)
	assert stats.requests.filter(it.url == '/unavailable').len == 1
	assert stats.requests.filter(it.method == 'POST').len == 1
}
