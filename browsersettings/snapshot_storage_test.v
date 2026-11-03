module browsersettings

import os
import platform
import time

fn snapshot_storage_settings_path() string {
	return os.join_path(os.temp_dir(), 'vox-settings-snapshot-${os.getpid()}-${time.sys_mono_now()}', 'settings.json')
}

fn test_settings_snapshot_survives_its_caller_and_later_profile_replacement() {
	path := snapshot_storage_settings_path()
	defer { os.rmdir_all(os.dir(path)) or {} }
	initialize(path)!
	save(Proxy{enabled: true, host: 'first.proxy.test', port: '1337', sites: 'old.example'})!
	mut caller := platform.new_arena('settings snapshot caller')
	entry := caller.enter()
	mut entered := true
	defer {
		if entered { caller.leave(entry) }
		caller.release()
	}
	before := current()
	$if prealloc {
		assert !caller.contains(before.host.str)
		assert !caller.contains(before.port.str)
		assert !caller.contains(before.sites.str)
	}
	caller.leave(entry)
	entered = false
	caller.reset()
	save(Proxy{enabled: true, host: 'second.proxy.test', port: '9050', sites: 'new.example'})!
	assert current().host == 'second.proxy.test'
	assert before.host == 'first.proxy.test' && before.port == '1337' && before.sites == 'old.example'
	initialize(path)!
	assert current().sites == 'new.example'
	assert before.sites == 'old.example'
	// External Apply is discovered during current(), while its raw read
	// workspace is active. The refreshed strings must survive that workspace.
	temporary := path + '.replacement'
	os.write_file(temporary, '{"enabled":true,"host":"third.proxy.test","port":"1081","sites":"third.example"}')!
	os.rename_dir(temporary, path)!
	after := current()
	assert after.host == 'third.proxy.test' && after.port == '1081' && after.sites == 'third.example'
	assert current() == after
	assert before.host == 'first.proxy.test' && before.sites == 'old.example'
}

fn test_unchanged_settings_reads_do_not_accumulate_stat_records_or_string_copies() {
	path := snapshot_storage_settings_path()
	defer { os.rmdir_all(os.dir(path)) or {} }
	initialize(path)!
	for configured in [false, true] {
		if configured {
			save(Proxy{enabled: true, host: 'proxy.example', port: '1337', sites: 'old.reddit.com'})!
		}
		expected := current()
		before := platform.thread_arena_usage().used
		for _ in 0 .. 1024 { assert current() == expected }
		growth := platform.thread_arena_usage().used - before
		eprintln('SETTINGS_SNAPSHOT configured=${configured} retained_bytes=${growth}')
		$if prealloc { assert growth < 1024 }
	}
}
