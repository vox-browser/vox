module browserbookmarks

import os
import time

fn test_stale_tab_processes_merge_bookmarks_and_preserve_visibility() {
	folder := os.join_path(os.temp_dir(), 'vox-bookmark-process-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(folder) or {} }
	path := os.join_path(folder, 'bookmarks.json')
	mut first := open(path)!
	mut second := open(path)!
	first.add('https://first.test', 'First')!
	second.add('https://second.test', 'Second')!
	first.toggle_visible()!
	second.reload()!
	assert second.items.len == 2
	assert second.visible
	second.remove(0)!
	first.reload()!
	assert first.items.len == 1
	assert first.items[0].url == 'https://second.test'
	assert first.visible
}
