module browsersettings

import os
import time

fn test_javascript_engine_defaults_persists_and_rejects_unknown_engines() {
	directory := os.join_path(os.temp_dir(), 'vox-engine-settings-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert current().javascript_engine == 'javascriptcore'
	os.mkdir_all(directory)!
	os.write_file(path, '{"enabled":false,"host":"localhost"}')!
	initialize(path)!
	assert current().javascript_engine == 'javascriptcore'
	save(Proxy{ ...current(), javascript_engine: 'libjs' })!
	initialize(path)!
	assert current().javascript_engine == 'libjs'
	assert current().host == 'localhost'
	before := os.read_file(path)!
	if _ := save(Proxy{ ...current(), javascript_engine: 'unknown' }) {
		assert false
	}
	assert os.read_file(path)! == before
	assert current().javascript_engine == 'libjs'
	save(Proxy{ ...current(), javascript_engine: 'javascriptcore' })!
	initialize(path)!
	assert current().javascript_engine == 'javascriptcore'
}
