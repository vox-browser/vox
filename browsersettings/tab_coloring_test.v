module browsersettings

import os
import time

fn test_tab_coloring_is_opt_in_and_survives_restart_without_changing_other_settings() {
	directory := os.join_path(os.temp_dir(), 'vox-tab-coloring-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert !current().enable_tab_coloring
	os.mkdir_all(directory)!
	os.write_file(path, '{"allow_any_site":true,"enabled":true,"host":"localhost","port":"9050"}')!
	initialize(path)!
	assert !current().enable_tab_coloring
	save(Proxy{ ...current(), enable_tab_coloring: true })!
	initialize(path)!
	assert current().enable_tab_coloring
	assert current().allow_any_site && current().enabled
	assert current().host == 'localhost' && current().port == '9050'
	save(Proxy{ ...current(), enable_tab_coloring: false })!
	initialize(path)!
	assert !current().enable_tab_coloring
	assert current().allow_any_site && current().port == '9050'
}
