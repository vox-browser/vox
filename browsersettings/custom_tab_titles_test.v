module browsersettings

import os
import time

fn test_custom_tab_titles_are_opt_in_persist_and_leave_other_settings_intact() {
	directory := os.join_path(os.temp_dir(), 'vox-custom-titles-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert !current().enable_custom_tab_titles
	os.mkdir_all(directory)!
	os.write_file(path, '{"enable_tab_coloring":true,"enabled":true,"host":"localhost","port":"9050"}')!
	initialize(path)!
	assert !current().enable_custom_tab_titles
	save(Proxy{ ...current(), enable_custom_tab_titles: true })!
	initialize(path)!
	assert current().enable_custom_tab_titles && current().enable_tab_coloring
	assert current().enabled && current().host == 'localhost' && current().port == '9050'
	save(Proxy{ ...current(), enable_custom_tab_titles: false })!
	initialize(path)!
	assert !current().enable_custom_tab_titles && current().enable_tab_coloring
	assert current().port == '9050'
}
