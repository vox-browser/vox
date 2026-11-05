module browsersettings

import os
import time

fn test_gpu_canvas_is_on_by_default_and_turning_it_off_survives_restart() {
	directory := os.join_path(os.temp_dir(), 'vox-gpu-canvas-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	initialize(path)!
	assert !current().disable_gpu_canvas
	// A profile written before the setting existed keeps GPU scrolling on.
	os.mkdir_all(directory)!
	os.write_file(path, '{"enable_tab_coloring":true,"enabled":true,"host":"localhost","port":"9050"}')!
	initialize(path)!
	assert !current().disable_gpu_canvas
	save(Proxy{ ...current(), disable_gpu_canvas: true })!
	initialize(path)!
	assert current().disable_gpu_canvas
	assert current().enable_tab_coloring && current().enabled
	assert current().host == 'localhost' && current().port == '9050'
	save(Proxy{ ...current(), disable_gpu_canvas: false })!
	initialize(path)!
	assert !current().disable_gpu_canvas
	assert current().enable_tab_coloring && current().port == '9050'
}
