module browsersettings

import json2
import os
import platform
import time

fn replace_profile_settings(path string, contents string) ! {
	// Match another Vox process's atomic Settings Apply, without updating this
	// process's Runtime through save() or initialize().
	temporary := '${path}.other-process'
	os.write_file(temporary, contents)!
	os.rename_dir(temporary, path)!
}

fn test_external_site_proxy_apply_changes_the_next_request_in_an_open_window() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-refresh-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	save(Proxy{enabled: true, port: '1337', sites: '4chan.org, x.com'})!
	assert proxy_override('https://volt.im/s/vlang/compiler-and-vlib-dev')? == ''

	replace_profile_settings(path, json2.encode(Proxy{
		enabled: true
		port: '1337'
		sites: '4chan.org, x.com, volt.im'
	}))!
	assert proxy_override('https://volt.im/s/vlang/compiler-and-vlib-dev')? == 'socks5h://127.0.0.1:1337'
	assert proxy_override('https://cdn.volt.im/app.js')? == 'socks5h://127.0.0.1:1337'
	assert proxy_override('https://notvolt.im/')? == ''
	assert current().sites == '4chan.org, x.com, volt.im'

	replace_profile_settings(path, json2.encode(Proxy{port: '1337', sites: 'volt.im'}))!
	assert proxy_override('https://volt.im/')? == ''
	assert !current().enabled
}

fn test_equal_size_same_timestamp_profile_replacement_refreshes_by_file_identity() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-identity-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	os.mkdir_all(directory)!
	old := Proxy{enabled: true, sites: 'old.test'}
	new := Proxy{enabled: true, sites: 'new.test'}
	os.write_file(path, json2.encode(old))!
	os.utime(path, 1700000000, 1700000000)!
	initialize(path)!
	before := os.stat(path)!

	temporary := '${path}.other-process'
	os.write_file(temporary, json2.encode(new))!
	os.utime(temporary, before.atime, before.mtime)!
	os.rename_dir(temporary, path)!
	after := os.stat(path)!
	assert before.size == after.size
	assert before.mtime == after.mtime
	assert before.inode != after.inode
	// current() must refresh the settings dialog too, without a request first.
	assert current().sites == 'new.test'
	assert proxy_override('https://new.test/')? != ''
	assert proxy_override('https://old.test/')? == ''
}

fn test_first_external_apply_is_observed_and_invalid_replacements_keep_the_last_route() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-first-apply-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert proxy_override('https://volt.im/') == none
	os.mkdir_all(directory)!
	replace_profile_settings(path, json2.encode(Proxy{enabled: true, sites: 'volt.im'}))!
	route := proxy_override('https://volt.im/')?
	assert route == 'socks5h://127.0.0.1:1080'
	for contents in ['{invalid', json2.encode(Proxy{enabled: true, port: 'invalid'})] {
		replace_profile_settings(path, contents)!
		assert proxy_override('https://volt.im/')? == route
		assert current().port == '1080'
	}
	os.rm(path)!
	assert proxy_override('https://volt.im/')? == route
	replace_profile_settings(path, json2.encode(Proxy{enabled: true, port: '9050', sites: 'volt.im'}))!
	assert proxy_override('https://volt.im/')? == 'socks5h://127.0.0.1:9050'
}

fn test_refreshed_settings_outlive_the_request_allocation_arena() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-owner-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	os.mkdir_all(directory)!
	replace_profile_settings(path, json2.encode(Proxy{
		enabled: true
		host: 'proxy.example.test'
		port: '1337'
		sites: 'volt.im'
	}))!
	mut arena := platform.new_arena('request triggering settings refresh')
	entry := arena.enter()
	assert proxy_override('https://volt.im/')? == 'socks5h://proxy.example.test:1337'
	$if prealloc {
		assert !arena.contains(unsafe { runtime.proxy.host.str })
		assert !arena.contains(unsafe { runtime.proxy.port.str })
		assert !arena.contains(unsafe { runtime.proxy.sites.str })
	}
	arena.leave(entry)
	arena.release()
	assert current().host == 'proxy.example.test'
	assert proxy_override('https://volt.im/')? == 'socks5h://proxy.example.test:1337'
}

fn refresh_settings_on_request_worker() {
	assert proxy_override('https://volt.im/') or { panic('missing saved route') } == 'socks5h://proxy.example.test:1337'
}

fn test_refreshed_settings_outlive_the_request_worker() {
	directory := os.join_path(os.temp_dir(), 'vox-settings-worker-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	save(Proxy{})!
	assert current() == Proxy{}
	replace_profile_settings(path, json2.encode(Proxy{
		enabled: true
		host: 'proxy.example.test'
		port: '1337'
		sites: 'volt.im'
	}))!
	worker := spawn refresh_settings_on_request_worker()
	worker.wait()
	assert current().host == 'proxy.example.test'
	assert proxy_override('https://volt.im/')? == 'socks5h://proxy.example.test:1337'
}
