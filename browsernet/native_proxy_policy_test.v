module browsernet

import browsersettings
import os
import time

fn test_native_loaders_retain_proxy_policy_across_bypasses_and_redirects() {
	directory := os.join_path(os.temp_dir(), 'vox-native-proxy-policy-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	keys := ['VOX_PROXY', 'http_proxy', 'HTTP_PROXY', 'https_proxy', 'HTTPS_PROXY', 'all_proxy',
		'ALL_PROXY', 'no_proxy', 'NO_PROXY']
	mut previous := map[string]string{}
	for key in keys {
		if value := os.getenv_opt(key) { previous[key] = value }
		os.unsetenv(key)
	}
	defer {
		for key in keys {
			if value := previous[key] {
				os.setenv(key, value, true)
			} else {
				os.unsetenv(key)
			}
		}
		browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) }
	}
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	assert !has_proxy_policy()
	os.setenv('HTTPS_PROXY', 'http://127.0.0.1:8888', true)
	os.setenv('NO_PROXY', 'localhost', true)
	assert request_proxy('http://localhost/')! == ''
	assert has_proxy_policy(), 'A bypassed URL can redirect into HTTPS proxy policy'
	os.setenv('NO_PROXY', '*', true)
	assert !has_proxy_policy()
	os.setenv('VOX_PROXY', 'socks5h://127.0.0.1:1337', true)
	assert !has_proxy_policy(), 'A universal bypass also covers later redirects'
	os.setenv('NO_PROXY', 'localhost', true)
	assert has_proxy_policy()
	os.setenv('VOX_PROXY', '', true)
	assert !has_proxy_policy()
	browsersettings.save(browsersettings.Proxy{
		enabled: true
		sites:   'proxied.invalid'
	})!
	assert request_proxy('http://localhost/')! == ''
	assert has_proxy_policy(), 'Scoped saved policy also applies after a redirect'
	browsersettings.save(browsersettings.Proxy{})!
	assert !has_proxy_policy(), 'Explicit direct settings override ambient proxies'
}
