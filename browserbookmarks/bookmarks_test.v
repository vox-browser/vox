module browserbookmarks

import os
import platform

fn test_bookmarks_and_visibility_persist_without_duplicates() {
	directory := os.join_path(os.temp_dir(), 'vox-bookmarks-${os.getpid()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	mut store := open(path)!
	store.add('https://example.com/page#part', 'V documentation — café "中文"')!
	store.add('https://example.com/page#part', 'Duplicate')!
	store.add('file:///tmp/local.html', '')!
	store.toggle_visible()!
	assert store.items.len == 2
	assert store.items[1].title == 'file:///tmp/local.html'
	mut reloaded := open(path)!
	assert reloaded.items == store.items
	assert reloaded.visible
	assert reloaded.version == store.version
	reloaded.remove(0)!
	assert reloaded.items.len == 1
	assert open(path)!.items == reloaded.items
	reloaded.toggle_visible()!
	assert !open(path)!.visible
	assert (os.stat(path)!.mode & 0o777) == 0o600
}

fn test_failed_save_preserves_bookmarks_and_visibility() {
	mut store := open('')!
	store.add('https://example.com/', 'Saved')!
	store.path = '/dev/null/bookmarks.json'
	version := store.version
	store.remove(0) or {
		assert store.items.len == 1
		assert store.version == version
		store.toggle_visible() or {
			assert !store.visible
			return
		}
	}
	assert false, 'Writing through a regular file must fail'
}

fn test_bookmarks_own_strings_after_document_allocations_are_released() {
	mut store := open('')!
	for index in 0 .. 4 {
		scratch := platform.begin_thread_scratch('bookmark test document')
		store.add('https://example.com/${index}', 'Title ${index}')!
		scratch.finish()
	}
	assert store.items[0].title == 'Title 0'
	assert store.items[3].url == 'https://example.com/3'
	for address in ['', 'javascript:alert(1)', 'data:text/html,private'] { store.add(address, '')! }
	assert store.items.len == 4
}

fn test_corrupt_profile_is_not_replaced() {
	path := os.join_path(os.temp_dir(), 'vox-bookmarks-corrupt-${os.getpid()}.json')
	defer { os.rm(path) or {} }
	os.write_file(path, '{broken')!
	open(path) or {
		assert os.read_file(path)! == '{broken'
		return
	}
	assert false, 'Invalid JSON must be reported'
}
