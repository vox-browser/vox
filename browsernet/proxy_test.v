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

struct ScopedProxyStats {
	proxy_hosts []string
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
	// A scoped proxy applies to request destinations, including subresources and
	// each redirect hop, rather than inheriting the source page's route.
	browsersettings.save(browsersettings.Proxy{ enabled: true, port: ports.proxy_port.str(), sites: 'remote-dns.invalid' })!
	assert get(adblock.Request{ url: '${address}/binary', source_url: target, request_type: 'image' }, ca)!.response.status_code == 200
	assert get(adblock.Request{ url: target, source_url: address, request_type: 'image' }, ca)!.response.status_code == 200
	before_redirects := json2.decode[ScopedProxyStats](os.read_file(os.join_path(directory, 'stats.json'))!)!.proxy_hosts.len
	for redirect in ['${address}/proxy-to-direct',
		'http://127.0.0.1:${ports.http_port}/direct-to-proxy'] {
		// Proxied requests share pooled tunnels; start each redirect chain
		// without one so every proxied hop is observed as its own tunnel.
		http.close_idle_connections()
		assert get(adblock.Request{ url: redirect, source_url: redirect, request_type: 'main_frame' }, ca)!.response.status_code == 200
	}
	after_redirects := json2.decode[ScopedProxyStats](os.read_file(os.join_path(directory, 'stats.json'))!)!.proxy_hosts
	assert after_redirects[before_redirects..] == ['remote-dns.invalid', 'remote-dns.invalid']
	// Unlisted hosts still connect directly if the selected proxy is offline;
	// listed hosts fail rather than silently escaping the configured proxy.
	browsersettings.save(browsersettings.Proxy{ enabled: true, port: '1', sites: 'remote-dns.invalid' })!
	assert get(adblock.Request{ url: target, source_url: address, request_type: 'image' }, ca)!.response.status_code == 200
	if response := get(adblock.Request{ url: '${address}/binary', source_url: target, request_type: 'image' }, ca) {
		assert false, 'scoped proxy was bypassed: ${response.url}'
	}
	// A Settings Apply in another window must repair this process's stale
	// route before the next navigation, without restarting or reinitializing.
	profile := os.join_path(directory, 'settings.json')
	external_save := '${profile}.other-window'
	os.write_file(external_save, json2.encode(browsersettings.Proxy{
		enabled: true
		port: ports.proxy_port.str()
		sites: 'remote-dns.invalid'
	}))!
	os.rename_dir(external_save, profile)!
	assert get(adblock.Request{url: '${address}/binary', source_url: address, request_type: 'main_frame'}, ca)!.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42]
	http.close_idle_connections()
}

struct PooledProxyFixturePorts {
	proxy_port int
	h2_port    int
	h1_port    int
}

struct PooledProxyStats {
	handshakes     map[string]int
	maximum_active int
	proxy_hosts    []string
}

fn pooled_proxy_stats(directory string) PooledProxyStats {
	return json2.decode[PooledProxyStats](os.read_file(os.join_path(directory, 'stats.json')) or {
		panic(err)
	}) or { panic(err) }
}

fn pooled_proxy_get(address string, ca string, replies chan string) {
	response := get(adblock.Request{ url: address, source_url: address, request_type: 'image' },
		ca) or {
		replies <- err.msg()
		return
	}
	replies <- if response.response.body.bytes() == [u8(0), 1, 127, 128, 255, 0, 42] { '' } else { 'body' }
}

// Pages with hundreds of subresources must not pay a SOCKS tunnel and TLS
// handshake per request: proxied requests share pooled HTTP/2 and keep-alive
// HTTP/1 connections inside one tunnel per origin, like direct requests.
fn test_socks_proxy_reuses_pooled_tunnels_per_origin_and_proxy() {
	node := os.find_abs_path_of_executable('node') or { return }
	openssl := os.find_abs_path_of_executable('openssl') or { return }
	directory := os.join_path(os.temp_dir(), 'vox-pooled-proxy-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	mut process := os.new_process(node)
	process.set_args([os.join_path(os.dir(@FILE), 'fixtures/http2_server.mjs'), directory, openssl])
	process.set_redirect_stdio()
	process.run()
	defer {
		http.close_idle_connections()
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
	ports := json2.decode[PooledProxyFixturePorts](os.read_file(ready)!)!
	mut previous := map[string]string{}
	for key in ['VOX_PROXY', 'NO_PROXY', 'no_proxy'] {
		if value := os.getenv_opt(key) { previous[key] = value }
	}
	defer {
		for key in ['VOX_PROXY', 'NO_PROXY', 'no_proxy'] {
			if key in previous { os.setenv(key, previous[key], true) } else { os.unsetenv(key) }
		}
	}
	os.setenv('VOX_PROXY', 'socks5h://127.0.0.1:${ports.proxy_port}', true)
	os.setenv('NO_PROXY', '', true)
	os.setenv('no_proxy', '', true)
	http.close_idle_connections()
	ca := os.join_path(directory, 'ca.pem')
	h2 := 'https://127.0.0.1:${ports.h2_port}'
	replies := chan string{cap: 6}
	for index in 0 .. 6 { spawn pooled_proxy_get('${h2}/pooled/${index}', ca, replies) }
	for _ in 0 .. 6 {
		reply := <-replies
		assert reply == ''
	}
	assert pooled_proxy_get_sequentially('${h2}/binary', ca, 3)
	multiplexed := pooled_proxy_stats(directory)
	assert multiplexed.handshakes['h2'] == 1
	assert multiplexed.maximum_active > 1
	assert multiplexed.proxy_hosts == ['127.0.0.1']
	// An HTTP/1-only origin keeps its keep-alive connection in the tunnel.
	h1 := 'https://127.0.0.1:${ports.h1_port}'
	assert pooled_proxy_get_sequentially('${h1}/binary', ca, 4)
	sequential := pooled_proxy_stats(directory)
	assert sequential.handshakes['h1'] <= 2
	assert sequential.proxy_hosts.len == multiplexed.proxy_hosts.len + sequential.handshakes['h1']
	// A pooled tunnel belongs to its proxy: switching to an unreachable proxy
	// must fail instead of reusing the connection or reaching the origin directly.
	os.setenv('VOX_PROXY', 'socks5://127.0.0.1:1', true)
	if response := get(adblock.Request{ url: '${h2}/binary', source_url: h2, request_type: 'image' },
		ca)
	{
		assert false, 'pooled tunnel outlived its proxy: ${response.url}'
	}
	os.setenv('VOX_PROXY', '', true)
	if response := get(adblock.Request{ url: '${h2}/binary', source_url: h2, request_type: 'image' },
		ca)
	{
		assert response.response.status_code == 200
	}
	direct := pooled_proxy_stats(directory)
	assert direct.handshakes['h2'] == 2
	assert direct.proxy_hosts == sequential.proxy_hosts
}

fn pooled_proxy_get_sequentially(address string, ca string, count int) bool {
	for _ in 0 .. count {
		response := get(adblock.Request{ url: address, source_url: address, request_type: 'image' },
			ca) or { return false }
		if response.response.body.bytes() != [u8(0), 1, 127, 128, 255, 0, 42] { return false }
	}
	return true
}
