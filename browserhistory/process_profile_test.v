module browserhistory

import os
import time

fn test_stale_tab_processes_merge_history_and_remove_current_visits() {
	folder := os.join_path(os.temp_dir(), 'vox-history-process-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(folder) or {} }
	path := os.join_path(folder, 'history.json')
	mut first := open(path, now())!
	mut second := open(path, now())!
	first.record('https://first.test', 'First', now())!
	second.record('https://second.test', 'Second', now())!
	first.reload()!
	assert first.visits.len == 2
	assert first.visits[0].id != first.visits[1].id
	first.remove([first.visits[0].id])!
	second.reload()!
	assert second.visits.len == 1
	assert second.visits[0].url == 'https://first.test'
	second.clear_since(0)!
	first.reload()!
	assert first.visits.len == 0
}
