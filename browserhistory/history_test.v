module browserhistory

import os
import platform

fn test_visits_persist_search_and_remove_without_losing_other_visits() {
	directory := os.join_path(os.temp_dir(), 'vox-history-${os.getpid()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'history.json')
	mut store := open(path, 10000000)!
	store.record('https://example.com/docs', 'V documentation — café "中文"', 10000000)!
	store.record('https://other.example/', 'Other page', 10000090)!
	store.record('https://example.com/docs', 'Updated documentation', 10000100)!
	assert store.visits.len == 3
	assert store.search('DOCUMENTATION example').len == 2
	assert store.search('other documentation').len == 0
	first := store.visits[0].id
	mut reloaded := open(path, 10000101)!
	assert reloaded.visits == store.visits
	reloaded.remove([first, i64(-123)])!
	assert reloaded.visits.len == 2
	assert reloaded.visits[0].title == 'Other page'
	assert open(path, 10000102)!.visits == reloaded.visits
	assert (os.stat(path)!.mode & 0o777) == 0o600
}

fn test_refresh_coalescing_retention_and_internal_pages() {
	mut store := open('', 10000000)!
	store.record('https://example.com/', 'Cached title', 10000000)!
	store.record('https://example.com/', 'Final title', 10000001)!
	assert store.visits.len == 1
	assert store.visits[0].title == 'Final title'
	for address in ['about:blank', 'about:home', 'vox://history', 'chrome://history',
		'data:text/html,private'] {
		store.record(address, 'Internal', 10000002)!
	}
	assert store.visits.len == 1
	store.record('file:///tmp/test.html', 'Local', 10000001 + retention_seconds)!
	assert store.visits.len == 1
	assert store.visits[0].url == 'file:///tmp/test.html'
}

fn test_clear_time_range_and_failed_write_preserve_live_history() {
	mut store := open('', 10000000)!
	for index in 0 .. 3 {
		store.record('https://example.com/${index}', 'Page ${index}', 10000000 + index * 100)!
	}
	store.clear_since(10000100)!
	assert store.visits.len == 1
	assert store.visits[0].visited_at == 10000000
	store.path = '/dev/null/history.json'
	store.clear_since(0) or {
		assert store.visits.len == 1
		store.path = ''
		store.clear_since(0)!
		assert store.visits.len == 0
		return
	}
	assert false, 'Writing through a regular file must fail'
}

fn test_record_owns_temporary_navigation_strings() {
	mut store := open('', 10000000)!
	for index in 0 .. 5 {
		scratch := platform.begin_thread_scratch('history test navigation')
		address := 'https://example.com/${index}'
		title := 'Page ${index}'
		store.record(address, title, 10000000 + index * 100)!
		scratch.finish()
	}
	assert store.visits.len == 5
	assert store.visits[0].url == 'https://example.com/4'
	assert store.visits[4].title == 'Page 0'
	store.remove([store.visits[2].id])!
	assert store.visits.len == 4
	assert store.visits[2].url == 'https://example.com/1'
}
