module browsernet

import adblock
import browsersettings
import json2
import net.http
import os
import time

fn test_proxy_configuration_overrides_ambient_settings_and_preserves_remote_dns() {
	environment := {
		'VOX_PROXY': 'socks5h://127.0.0.1:1337'
		'https_proxy': 'http://127.0.0.1:8888'
	}
	assert configured_proxy('https://old.reddit.com/', environment)! == 'socks5://127.0.0.1:1337'
	assert configured_proxy('http://old.reddit.com/', environment)! == 'socks5://127.0.0.1:1337'
	assert configured_proxy('https://old.reddit.com/', {'VOX_PROXY': '', 'ALL_PROXY': 'socks5://127.0.0.1:1337'})! == ''
	assert configured_proxy('https://example.com/', {'https_proxy': 'http://localhost:80', 'HTTPS_PROXY': 'http://localhost:81'})! == 'http://localhost:80'
	assert configured_proxy('https://example.com/', {'ALL_PROXY': 'socks5://localhost:1337'})! == 'socks5://localhost:1337'
}

fn test_proxy_bypass_matches_host_boundaries_and_optional_ports() {
	for address in ['http://localhost/', 'http://127.0.0.1:9000/', 'https://[::1]/',
		'https://reddit.com/', 'https://old.reddit.com/'] {
		assert configured_proxy(address, {'VOX_PROXY': 'socks5://localhost:1337',
			'NO_PROXY': 'localhost,127.0.0.1,[::1],.reddit.com:443'})! == ''
	}
	for address in ['https://notreddit.com/', 'https://reddit.com.evil.test/', 'http://reddit.com/'] {
		assert configured_proxy(address, {'VOX_PROXY': 'socks5://localhost:1337',
			'NO_PROXY': '.reddit.com:443'})! == 'socks5://localhost:1337'
	}
	assert configured_proxy('https://example.com/', {'VOX_PROXY': 'invalid', 'no_proxy': '*'})! == ''
}

fn test_invalid_proxy_does_not_silently_connect_directly_or_expose_credentials() {
	for value in ['socks5://localhost', 'file:///tmp/proxy', 'https://localhost:443',
		'http://', 'http://localhost:80/path', 'socks5://secret:password@localhost'] {
		if proxy := configured_proxy('https://example.com/', {'VOX_PROXY': value}) {
			assert false, 'invalid proxy accepted: ${proxy}'
		} else {
			assert err.msg().starts_with('Invalid browser proxy configuration')
			assert !err.msg().contains('secret') && !err.msg().contains('password')
		}
	}
}

struct ProxyFixturePorts {
	proxy_port int
	http_port int
	h1_port int
	wrong_host_port int
}

fn test_socks_proxy_carries_navigation_redirects_binary_data_and_verified_tls() {
	node := os.find_abs_path_of_executable('node') or { panic(err) }
	openssl := os.find_abs_path_of_executable('openssl') or { panic(err) }
	directory := os.join_path(os.temp_dir(), 'vox-proxy-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	mut process := os.new_process(node)
	process.set_args([os.join_path(os.dir(@FILE), 'fixtures/http2_server.mjs'), directory, openssl])
	process.set_redirect_stdio()
	process.run()
	defer {
		process.signal_kill()
		process.wait()
		process.close()
		os.rmdir_all(directory) or {}
	}
	ready := os.join_path(directory, 'ready.json')
	for _ in 0 .. 1000 {
		if os.exists(ready) { break }
		if !process.is_alive() { panic(process.stderr_slurp()) }
		time.sleep(10 * time.millisecond)
	}
	ports := json2.decode[ProxyFixturePorts](os.read_file(ready)!)!
	mut previous := map[string]string{}
	for key in ['VOX_PROXY', 'NO_PROXY', 'no_proxy'] {
		if value := os.getenv_opt(key) { previous[key] = value }
	}
	defer {
		for key in ['VOX_PROXY', 'NO_PROXY', 'no_proxy'] {
			if key in previous { os.setenv(key, previous[key], true) }
			else { os.unsetenv(key) }
		}
	}
	os.setenv('VOX_PROXY', 'socks5h://127.0.0.1:${ports.proxy_port}', true)
	os.setenv('NO_PROXY', '', true)
	os.setenv('no_proxy', '', true)
	ca := os.join_path(directory, 'ca.pem')
	// This hostname has no DNS record: only the SOCKS fixture resolves it.
	address := 'http://remote-dns.invalid:${ports.http_port}'
	result := get(adblock.Request{url: '${address}/dir/redirect', source_url: address, request_type: 'main_frame'}, ca)!
	assert result.url == '${address}/binary?allowed=1'
	assert result.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	for port in [ports.h1_port, ports.wrong_host_port] {
		target := 'https://127.0.0.1:${port}/binary'
		input := adblock.Request{url: target, source_url: target, request_type: 'image'}
		if port == ports.h1_port {
			assert get(input, ca)!.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
			if response := get(input, os.join_path(directory, 'untrusted-ca.pem')) {
				assert false, 'proxy accepted untrusted certificate: ${response.url}'
			}
		} else if response := get(input, ca) {
			assert false, 'proxy accepted wrong hostname: ${response.url}'
		}
	}
	// Refusing a proxy must not turn a valid local origin into a direct fetch.
	os.setenv('VOX_PROXY', 'socks5://127.0.0.1:1', true)
	target := 'http://127.0.0.1:${ports.http_port}/binary'
	if response := get(adblock.Request{url: target, source_url: target, request_type: 'main_frame'}, ca) {
		assert false, 'failed proxy was bypassed: ${response.url}'
	}
	// Applying saved settings switches the very next request, overriding both
	// a broken environment proxy and an ambient bypass list.
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	defer { browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) } }
	os.setenv('NO_PROXY', '*', true)
	browsersettings.save(browsersettings.Proxy{ enabled: true, port: ports.proxy_port.str() })!
	assert get(adblock.Request{url: '${address}/binary', source_url: address, request_type: 'main_frame'}, ca)!.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	browsersettings.save(browsersettings.Proxy{ enabled: true, port: '1' })!
	if response := get(adblock.Request{url: target, source_url: target, request_type: 'main_frame'}, ca) {
		assert false, 'saved proxy was bypassed: ${response.url}'
	}
	browsersettings.save(browsersettings.Proxy{})!
	assert get(adblock.Request{url: target, source_url: target, request_type: 'main_frame'}, ca)!.response.status_code == 200
	http.close_idle_connections()
}
