module browserbookmarks

import os
import time

fn test_optimized_bookmarks_migrate_once_and_preserve_existing_items() {
	directory := os.join_path(os.temp_dir(), 'vox-default-bookmarks-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	mut store := open(path)!
	store.add('https://private.example/', 'My bookmark')!
	store.add('https://www.wikipedia.org/', 'My Wikipedia title')!
	mut other_process := open(path)!
	store.seed_optimized_sites()!
	other_process.seed_optimized_sites()!
	assert other_process.items.len == 4
	assert other_process.items[0].title == 'My Wikipedia title'
	assert other_process.items[3].title == 'My bookmark'
	assert other_process.visible
	other_process.remove(0)!
	other_process.toggle_visible()!
	mut reopened := open(path)!
	reopened.seed_optimized_sites()!
	assert reopened.items.len == 3
	assert !reopened.visible
	assert reopened.optimized_defaults_added
	assert !reopened.items.any(it.url == 'https://www.wikipedia.org/')
}

fn test_fresh_defaults_and_failed_migration_preserve_unsaved_state() {
	mut store := open('')!
	store.seed_optimized_sites()!
	assert store.visible && store.items.len == 3
	assert store.items[1].url == 'https://old.reddit.com/'
	mut broken := open('')!
	broken.path = '/dev/null/bookmarks.json'
	broken.seed_optimized_sites() or {
		assert !broken.optimized_defaults_added
		assert broken.items.len == 0 && !broken.visible
		return
	}
	assert false, 'Migration through a regular file must fail'
}
