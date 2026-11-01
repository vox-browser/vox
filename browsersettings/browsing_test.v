module browsersettings

import os
import time

fn test_any_site_access_defaults_off_and_survives_apply_and_restart() {
	directory := os.join_path(os.temp_dir(), 'vox-browsing-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert !current().allow_any_site
	os.mkdir_all(directory)!
	os.write_file(path, '{"enabled":true,"host":"localhost","port":"9050"}')!
	initialize(path)!
	assert !current().allow_any_site
	save(Proxy{...current(), allow_any_site: true})!
	initialize(path)!
	assert current().allow_any_site
	assert current().enabled && current().host == 'localhost' && current().port == '9050'
	save(Proxy{...current(), allow_any_site: false})!
	initialize(path)!
	assert !current().allow_any_site
	assert current().port == '9050'
}
