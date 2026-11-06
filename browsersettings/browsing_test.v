module browsersettings

import os
import time

fn test_profiles_saved_with_the_retired_any_site_setting_still_load() {
	directory := os.join_path(os.temp_dir(), 'vox-browsing-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	os.mkdir_all(directory)!
	os.write_file(path, '{"allow_any_site":false,"enabled":true,"host":"localhost","port":"9050"}')!
	initialize(path)!
	assert current().enabled && current().host == 'localhost' && current().port == '9050'
	save(Proxy{ ...current(), enable_tab_coloring: true })!
	assert !os.read_file(path)!.contains('allow_any_site')
	initialize(path)!
	assert current().enable_tab_coloring && current().port == '9050'
}
