module browsersettings

import os
import time

fn test_stale_tab_processes_merge_per_domain_zoom_preferences() {
	folder := os.join_path(os.temp_dir(), 'vox-zoom-process-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(folder) or {} }
	path := os.join_path(folder, 'zoom.json')
	mut first := open_zoom_levels(path)!
	mut second := open_zoom_levels(path)!
	first.set_for_url('https://first.test', 1.25)!
	second.set_for_url('https://second.test', 1.5)!
	first.reload()!
	assert first.for_url('https://first.test') == 1.25
	assert first.for_url('https://second.test') == 1.5
	second.set_for_url('https://first.test', 1)!
	first.reload()!
	assert first.for_url('https://first.test') == 1
	assert first.for_url('https://second.test') == 1.5
}
