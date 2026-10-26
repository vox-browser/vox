module browsersettings

import os
import time

fn test_proxy_settings_validate_host_port_and_remote_dns_url() {
	for host in ['localhost', '127.0.0.1', '::1', '[::1]'] {
		proxy := Proxy{ enabled: true, host: ' ${host} ', port: ' 01080 ' }.normalized()!
		assert proxy.port == '1080'
		assert proxy.url() == if host.contains(':') {
			'socks5h://[::1]:1080'
		} else {
			'socks5h://${host}:1080'
		}
	}
	for host in ['', 'http://localhost', 'localhost:1080', 'user@localhost', 'localhost/path',
		'local host', '[::1', '[localhost]', 'abcd::xyz'] {
		if _ := (Proxy{ enabled: true, host: host }).normalized() {
			assert false, host
		}
	}
	for port in ['', '0', '-1', '65536', '99999999999999999999', '1.5', '80oops'] {
		if _ := (Proxy{ enabled: true, port: port }).normalized() {
			assert false, port
		}
	}
	assert (Proxy{ enabled: true, port: '65535' }).normalized()!.port == '65535'
	assert (Proxy{ host: '', port: '' }).normalized()!.url() == ''
}

fn test_saved_proxy_is_atomic_restored_and_can_disable_ambient_proxies() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert proxy_override('https://example.com/') == none
	assert current() == Proxy{}
	save(Proxy{ enabled: true, host: 'proxy.example', port: '9050' })!
	assert proxy_override('https://example.com/') or { panic('missing override') } == 'socks5h://proxy.example:9050'
	initialize(path)!
	assert current().enabled
	assert current().host == 'proxy.example'
	before := os.read_file(path)!
	if _ := save(Proxy{ enabled: true, port: 'invalid' }) {
		assert false
	}
	assert os.read_file(path)! == before
	assert current().host == 'proxy.example'
	save(Proxy{ enabled: false, host: 'proxy.example', port: '9050' })!
	initialize(path)!
	assert proxy_override('https://example.com/') or { panic('direct mode must be explicit') } == ''
	assert current().host == 'proxy.example'
	assert os.ls(directory)!.len == 1
	// A write failure must preserve the active proxy too.
	os.rm(path)!
	os.mkdir(path)!
	if _ := save(Proxy{ enabled: true }) {
		assert false
	}
	assert proxy_override('https://example.com/') or { panic('lost override') } == ''
}

fn test_proxy_sites_normalize_and_match_destinations_at_domain_boundaries() {
	proxy := Proxy{ enabled: true, sites: ' Example.COM.,\tother.test\nexample.com, 127.0.0.1, [2001:0db8::1], bücher.de ' }.normalized()!
	assert proxy.sites == 'example.com, other.test, 127.0.0.1, [2001:db8::1], xn--bcher-kva.de'
	for address in ['https://example.com/', 'http://EXAMPLE.COM.:8080/path',
		'https://cdn.sub.example.com/file', 'https://other.test/', 'http://127.0.0.1:8080/',
		'http://0x7f.1/', 'https://[2001:db8:0:0:0:0:0:1]/', 'https://bücher.de/',
		'https://cdn.xn--bcher-kva.de/'] {
		assert proxy.url_for(address) == proxy.url(), address
	}
	for address in ['https://notexample.com/', 'https://example.com.evil.test/',
		'https://example.com@unlisted.test/', 'https://unlisted.test/example.com', 'http://127.0.0.2/',
		'https://[2001:db8::2]/', 'data:text/plain,example.com', 'invalid'] {
		assert proxy.url_for(address) == '', address
	}
	assert (Proxy{ enabled: true }).url_for('https://any.test/') != ''
	assert (Proxy{ sites: 'example.com' }).url_for('https://example.com/') == ''
	for sites in [', ,', '*', '*.example.com', 'https://example.com', 'example.com:443',
		'example.com/path', 'user@example.com', 'example.com?x', 'example.com#x', 'bad..example.com',
		'example.com..', '[not-ipv6]', '2001::xyz', '%65xample.com', 'example.com, *'] {
		if _ := (Proxy{ enabled: true, sites: sites }).normalized() {
			assert false, sites
		}
	}
}

fn test_saved_site_scope_survives_restart_and_invalid_apply_preserves_route() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-sites-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	// Older profiles without a site list retain their all-sites behavior.
	os.write_file(path, '{"enabled":true,"host":"127.0.0.1","port":"1080"}')!
	initialize(path)!
	assert current().sites == ''
	assert proxy_override('https://any.test/') or { panic('missing override') } != ''
	save(Proxy{ enabled: true, sites: 'Example.com, other.test' })!
	initialize(path)!
	assert current().sites == 'example.com, other.test'
	assert proxy_override('https://cdn.example.com/') or { panic('missing override') } != ''
	assert proxy_override('https://unlisted.test/') or { panic('missing direct override') } == ''
	before := os.read_file(path)!
	if _ := save(Proxy{ enabled: true, sites: '*.test' }) {
		assert false
	}
	assert os.read_file(path)! == before
	assert current().sites == 'example.com, other.test'
	save(Proxy{ ...current(), enabled: false })!
	initialize(path)!
	assert current().sites == 'example.com, other.test'
	assert proxy_override('https://example.com/') or { panic('missing direct override') } == ''
	save(Proxy{ ...current(), enabled: true, sites: '' })!
	assert proxy_override('https://unlisted.test/') or { panic('missing override') } != ''
}

fn test_experimental_page_switch_is_opt_in_and_persisted_independently_of_proxy() {
	directory := os.join_path(os.temp_dir(), 'vox-page-switch-settings-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert !current().experimental_fast_page_switch
	save(Proxy{experimental_fast_page_switch: true})!
	initialize(path)!
	assert current().experimental_fast_page_switch
	assert !current().enabled
	save(Proxy{...current(), enabled: true})!
	assert current().experimental_fast_page_switch
	save(Proxy{...current(), experimental_fast_page_switch: false})!
	initialize(path)!
	assert !current().experimental_fast_page_switch
	assert current().enabled
}
