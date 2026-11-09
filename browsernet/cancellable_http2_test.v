module browsernet

import json2
import net.http
import os
import time

struct ScopedTLSFixture {
	directory       string
	h2_port         int
	h1_port         int
	wrong_host_port int
	http_port       int
	proxy_port      int
	process         &os.Process = unsafe { nil }
}

struct ScopedTLSReady {
	h2_port         int
	h1_port         int
	wrong_host_port int
	http_port       int
	proxy_port      int
	node_version    string
}

struct ScopedTLSStats {
	handshakes     map[string]int
	maximum_active int
	requests       []ScopedTLSRequest
}

struct ScopedTLSRequest {
	url      string
	method   string
	protocol string
	headers  map[string]string
}

fn start_scoped_tls_fixture() ?ScopedTLSFixture {
	node := os.find_abs_path_of_executable('node') or { return none }
	openssl := os.find_abs_path_of_executable('openssl') or { return none }
	directory := os.join_path(os.temp_dir(), 'vox-scoped-tls-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	mut process := os.new_process(node)
	process.set_args([os.join_path(os.dir(@FILE), 'fixtures/http2_server.mjs'), directory, openssl])
	process.set_redirect_stdio()
	process.run()
	ready := os.join_path(directory, 'ready.json')
	for _ in 0 .. 1000 {
		if os.exists(ready) {
			ports := json2.decode[ScopedTLSReady](os.read_file(ready) or { panic(err) }) or { panic(err) }
			return ScopedTLSFixture{ directory: directory, h2_port: ports.h2_port, h1_port: ports.h1_port, wrong_host_port: ports.wrong_host_port, http_port: ports.http_port, proxy_port: ports.proxy_port, process: process }
		}
		if !process.is_alive() { panic('TLS fixture exited: ${process.stderr_slurp()}') }
		time.sleep(10 * time.millisecond)
	}
	process.signal_kill()
	panic('Timed out starting local TLS fixture')
}

fn (fixture ScopedTLSFixture) close() {
	mut process := fixture.process
	process.signal_kill()
	process.wait()
	process.close()
	os.rmdir_all(fixture.directory) or {}
}

fn scoped_tls_config(fixture ScopedTLSFixture, address string) http.FetchConfig {
	return http.FetchConfig{
		url:            address
		verify:         os.join_path(fixture.directory, 'ca.pem')
		enable_http2:   true
		validate:       true
		allow_redirect: false
		user_agent:     'Vox scoped resource test'
		header:         http.new_header_from_map({
			http.CommonHeader.cookie: 'scope=retained'
		})
		read_timeout:   10 * time.second
	}
}

fn scoped_tls_stats(fixture ScopedTLSFixture) ScopedTLSStats {
	return json2.decode[ScopedTLSStats](os.read_file(os.join_path(fixture.directory, 'stats.json')) or { panic(err) }) or { panic(err) }
}

fn test_scoped_https_preserves_binary_decoding_protocol_selection_proxy_and_tls_validation() {
	fixture := start_scoped_tls_fixture() or {
		eprintln('SKIP scoped TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	scope := new_request_scope()
	defer { scope.release() }
	mut progress := ResponseBodyProgress{}
	address := 'https://127.0.0.1:${fixture.h2_port}'
	config := scoped_tls_config(fixture, '${address}/gzip')
	h2 := fetch_cancellable(config, scope, mut progress)!
	assert h2.response.http_version == '2'
	assert h2.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	assert h2.response.header.custom_values('X-Fixture') == ['retained']
	assert h2.response_time > 0
	h1 := fetch_cancellable(http.FetchConfig{ ...config, enable_http2: false }, scope, mut progress)!
	assert h1.response.http_version == '1.1'
	assert h1.response.body == h2.response.body
	if response := fetch_cancellable(http.FetchConfig{
		...config
		verify: os.join_path(fixture.directory, 'untrusted-ca.pem')
	}, scope, mut progress) {
		assert false, 'Untrusted CA accepted: ${response.response.status_code}'
	}
	if response := fetch_cancellable(scoped_tls_config(fixture,
		'https://127.0.0.1:${fixture.wrong_host_port}/binary'), scope, mut progress) {
		assert false, 'Incorrect certificate hostname accepted: ${response.response.status_code}'
	}
	proxy := http.new_http_proxy('socks5://127.0.0.1:${fixture.proxy_port}')!
	proxied := fetch_cancellable(http.FetchConfig{
		...config
		url:   'http://remote-dns.invalid:${fixture.http_port}/binary'
		proxy: proxy
	}, scope, mut progress)!
	assert proxied.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	stats := scoped_tls_stats(fixture)
	assert stats.requests.map(it.protocol) == ['2.0', '1.1', '1.1']
}

fn test_scoped_https_http2_timeout_recovers_once_and_discards_abandoned_progress() {
	fixture := start_scoped_tls_fixture() or {
		eprintln('SKIP scoped TLS fixture: Node and OpenSSL required')
		return
	}
	defer { fixture.close() }
	scope := new_request_scope()
	defer { scope.release() }
	mut progress := ResponseBodyProgress{}
	address := 'https://127.0.0.1:${fixture.h2_port}'
	response := fetch_cancellable(scoped_tls_config(fixture, '${address}/timeout/partial'),
		scope, mut progress)!
	assert response.response.http_version == '1.1'
	assert response.response.body == 'x'.repeat(64)
	assert response.response_time - response.request_time < 2000
	assert progress.previous == 64
	assert progress.incomplete_prefix == 0
	assert progress.prefix.bytestr() == 'x'.repeat(32)
	redirect := fetch_cancellable(scoped_tls_config(fixture, '${address}/timeout/redirect'),
		scope, mut progress)!
	assert redirect.response.status_code == 302
	assert redirect.response.header.get(.location) or { '' } == '../binary?recovered=1'
	// Redirect handling remains outside the transport, where each hop is filtered.
	stats := scoped_tls_stats(fixture)
	assert stats.requests.map(it.protocol) == ['2.0', '1.1', '2.0', '1.1']
	for request in stats.requests {
		assert request.method == 'GET'
		assert request.headers['cookie'] == 'scope=retained'
		assert request.headers['user-agent'] == 'Vox scoped resource test'
	}
}
