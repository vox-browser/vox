module browserbookmarks

import os
import time

fn test_optimized_bookmarks_migrate_once_and_preserve_existing_items() {
	directory := os.join_path(os.temp_dir(), 'vox-default-bookmarks-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	mut store := open(path)!
	store.add('https://private.example/', 'My bookmark')!
	store.add('https://en.wikipedia.org/wiki/Main_Page', 'My Wikipedia title')!
	mut other_process := open(path)!
	store.seed_optimized_sites()!
	other_process.seed_optimized_sites()!
	assert other_process.items.len == 5
	assert other_process.items[0].title == 'My Wikipedia title'
	assert other_process.items[4].title == 'My bookmark'
	assert other_process.visible
	other_process.remove(0)!
	other_process.toggle_visible()!
	mut reopened := open(path)!
	reopened.seed_optimized_sites()!
	assert reopened.items.len == 4
	assert !reopened.visible
	assert reopened.optimized_defaults_added
	assert !reopened.items.any(it.url == 'https://en.wikipedia.org/wiki/Main_Page')
}

fn test_fresh_defaults_and_failed_migration_preserve_unsaved_state() {
	mut store := open('')!
	store.seed_optimized_sites()!
	assert store.visible && store.items.len == 4
	assert store.items[0].url == 'https://en.wikipedia.org/wiki/Main_Page'
	assert store.items[1].url == 'https://old.reddit.com/r/programming/'
	assert store.items[3].url == 'https://news.ycombinator.com/'
	mut broken := open('')!
	broken.path = '/dev/null/bookmarks.json'
	broken.seed_optimized_sites() or {
		assert !broken.optimized_defaults_added
		assert broken.items.len == 0 && !broken.visible
		return
	}
	assert false, 'Migration through a regular file must fail'
}

fn test_existing_seeded_reddit_is_updated_without_resetting_visibility_or_custom_items() {
	directory := os.join_path(os.temp_dir(), 'vox-reddit-migration-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	os.write_file(path, '{"optimized_defaults_added":true,"visible":false,"items":[{"url":"https://old.reddit.com/","title":"Old Reddit"},{"url":"https://custom.test/","title":"Custom"}]}')!
	mut store := open(path)!
	store.seed_optimized_sites()!
	assert store.items.len == 3 && !store.visible
	assert store.items[0].url == 'https://old.reddit.com/r/programming/'
	assert store.items[1].title == 'Hacker News'
	assert store.items[2].title == 'Custom'
	version := store.version
	store.seed_optimized_sites()!
	assert store.version == version
	assert open(path)!.items == store.items
	// A separately named user bookmark is not the previously seeded default.
	os.write_file(path, '{"optimized_defaults_added":true,"visible":true,"items":[{"url":"https://old.reddit.com/","title":"My Reddit"}]}')!
	store = open(path)!
	store.seed_optimized_sites()!
	assert store.items[1].url == 'https://old.reddit.com/' && store.items[1].title == 'My Reddit'
	// An already saved programming bookmark wins over the old generated one.
	os.write_file(path, '{"optimized_defaults_added":true,"visible":false,"items":[{"url":"https://old.reddit.com/","title":"Old Reddit"},{"url":"https://old.reddit.com/r/programming/","title":"My programming"}]}')!
	store = open(path)!
	store.seed_optimized_sites()!
	assert store.items.len == 2 && store.items[0].title == 'My programming'
}

fn test_existing_wikipedia_default_moves_to_main_page_and_preserves_user_bookmarks() {
	directory := os.join_path(os.temp_dir(), 'vox-wikipedia-migration-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	os.write_file(path, '{"optimized_defaults_added":true,"visible":false,"version":8,"items":[{"url":"https://www.wikipedia.org/","title":"Wikipedia"},{"url":"https://old.reddit.com/","title":"Old Reddit"},{"url":"https://custom.test/","title":"Custom"}]}')!
	mut store := open(path)!
	store.seed_optimized_sites()!
	assert store.items.len == 4 && !store.visible
	assert store.items[0].url == 'https://en.wikipedia.org/wiki/Main_Page'
	assert store.items[1].url == 'https://old.reddit.com/r/programming/'
	assert store.items[2].title == 'Hacker News'
	assert store.items[3].title == 'Custom'
	assert store.version == 9
	assert open(path)!.items == store.items
	store.seed_optimized_sites()!
	assert store.version == 9
	// Keep a separately named portal bookmark unchanged.
	os.write_file(path, '{"optimized_defaults_added":true,"items":[{"url":"https://www.wikipedia.org/","title":"My portal"}]}')!
	store = open(path)!
	store.seed_optimized_sites()!
	assert store.items[1].url == 'https://www.wikipedia.org/' && store.items[1].title == 'My portal'
	// Prefer an existing Main Page bookmark, preserving its custom title.
	os.write_file(path, '{"optimized_defaults_added":true,"items":[{"url":"https://www.wikipedia.org/","title":"Wikipedia"},{"url":"https://en.wikipedia.org/wiki/Main_Page","title":"My Main Page"}]}')!
	store = open(path)!
	store.seed_optimized_sites()!
	assert store.items.len == 2 && store.items[0].title == 'My Main Page'
}

fn test_hacker_news_is_added_once_to_old_profiles_and_stays_removed() {
	directory := os.join_path(os.temp_dir(), 'vox-hn-migration-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	os.write_file(path, '{"optimized_defaults_added":true,"visible":false,"version":12,"items":[{"url":"https://vlang.io/","title":"vlang.io"},{"url":"about:blank","title":"New Tab"},{"url":"https://custom.test/","title":"Custom"}]}')!
	mut first := open(path)!
	mut second := open(path)!
	first.seed_optimized_sites()!
	second.seed_optimized_sites()!
	assert second.items == first.items
	assert second.version == 13 && !second.visible
	assert second.hacker_news_default_added
	assert second.items.map(it.title) == ['vlang.io', 'Hacker News', 'New Tab', 'Custom']
	assert second.items[1].url == 'https://news.ycombinator.com/'
	second.remove(1)!
	first.seed_optimized_sites()!
	assert first.items.len == 3
	assert first.version == 14
	mut reopened := open(path)!
	reopened.seed_optimized_sites()!
	assert reopened.items == first.items && reopened.version == 14
}

fn test_hacker_news_migration_keeps_existing_title_and_rolls_back_failed_save() {
	mut store := open('')!
	store.optimized_defaults_added = true
	store.add('https://news.ycombinator.com/', 'My HN')!
	store.seed_optimized_sites()!
	assert store.items.len == 1 && store.items[0].title == 'My HN'
	assert store.hacker_news_default_added
	mut broken := open('')!
	broken.optimized_defaults_added = true
	broken.path = '/dev/null/bookmarks.json'
	broken.seed_optimized_sites() or {
		assert !broken.hacker_news_default_added
		assert broken.items.len == 0 && broken.version == 0 && !broken.visible
		return
	}
	assert false, 'Failed Hacker News migration must preserve the previous profile'
}
