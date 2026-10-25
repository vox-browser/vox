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
	assert proxy_override() == none
	assert current() == Proxy{}
	save(Proxy{ enabled: true, host: 'proxy.example', port: '9050' })!
	assert proxy_override() or { panic('missing override') } == 'socks5h://proxy.example:9050'
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
	assert proxy_override() or { panic('direct mode must be explicit') } == ''
	assert current().host == 'proxy.example'
	assert os.ls(directory)!.len == 1
	// A write failure must preserve the active proxy too.
	os.rm(path)!
	os.mkdir(path)!
	if _ := save(Proxy{ enabled: true }) {
		assert false
	}
	assert proxy_override() or { panic('lost override') } == ''
}
