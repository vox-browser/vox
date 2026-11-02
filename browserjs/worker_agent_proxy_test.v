module browserjs

import browsersettings
import os
import time

fn worker_role_proxy_profile(contents string) string {
	directory := os.join_path(os.temp_dir(), 'vox-worker-proxy-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(directory, mode: 0o700) or { panic(err) }
	os.write_file(os.join_path(directory, 'settings.json'), contents) or { panic(err) }
	return directory
}

fn test_private_worker_role_loads_the_saved_destination_proxy_before_opening_its_channel() {
	previous := os.getenv_opt('VOX_PROFILE_DIR')
	directory := worker_role_proxy_profile('{"enabled":true,"host":"127.0.0.1","port":"1337","sites":"worker-policy.test"}')
	defer {
		if value := previous { os.setenv('VOX_PROFILE_DIR', value, true) } else { os.unsetenv('VOX_PROFILE_DIR') }
		browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) }
		os.rmdir_all(directory) or {}
	}
	os.setenv('VOX_PROFILE_DIR', directory, true)
	browsersettings.initialize(os.join_path(directory, 'absent.json'))!
	assert browsersettings.proxy_override('https://worker-policy.test/entry.js') == none
	// This test process has no private worker IPC descriptors. Initialization
	// must still precede the channel validation that rejects the role launch.
	assert run_worker_process_role(['vox', '--vox-script-worker-v1'])? == 1
	assert browsersettings.proxy_override('https://worker-policy.test/entry.js')? == 'socks5h://127.0.0.1:1337'
	assert browsersettings.proxy_override('https://other-policy.test/import.js')? == ''
}

fn test_private_worker_role_preserves_the_saved_explicit_direct_policy() {
	previous := os.getenv_opt('VOX_PROFILE_DIR')
	directory := worker_role_proxy_profile('{"enabled":false,"host":"127.0.0.1","port":"1337"}')
	defer {
		if value := previous { os.setenv('VOX_PROFILE_DIR', value, true) } else { os.unsetenv('VOX_PROFILE_DIR') }
		browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) }
		os.rmdir_all(directory) or {}
	}
	os.setenv('VOX_PROFILE_DIR', directory, true)
	browsersettings.initialize(os.join_path(directory, 'absent.json'))!
	assert run_worker_process_role(['vox', '--vox-script-worker-v1'])? == 1
	assert browsersettings.proxy_override('https://worker-policy.test/entry.js')? == ''
}
