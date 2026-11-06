module browserbookmarks

import optimizedsites
import os
import time

fn test_forum_news_defaults_add_once_preserve_user_items_and_survive_stale_tabs() {
	directory := os.join_path(os.temp_dir(), 'vox-forum-bookmarks-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'bookmarks.json')
	mut first := open(path)!
	first.seed_optimized_sites()!
	first.add('https://www.engadget.com/', 'My Engadget')!
	first.add('https://private.example/', 'Private')!
	first.toggle_visible()!
	mut stale := open(path)!
	first.seed_forum_news_sites()!
	stale.seed_forum_news_sites()!
	assert stale.items == first.items
	assert !stale.visible
	assert stale.forum_news_defaults_added
	assert stale.items.len == optimizedsites.bookmarked_sites.len + 1
	assert stale.items.filter(it.url == 'https://www.engadget.com/')[0].title == 'My Engadget'
	assert stale.items.last().url == 'https://private.example/'
	version := stale.version
	stale.seed_forum_news_sites()!
	assert stale.version == version
	mut remove := -1
	for index, item in stale.items {
		if item.url == 'https://www.wired.com/' { remove = index }
	}
	assert remove >= 0
	stale.remove(remove)!
	first.seed_forum_news_sites()!
	assert !first.items.any(it.url == 'https://www.wired.com/')
	assert first.version == version + 1
	first.add('https://another.example/', 'Another')!
	mut reopened := open(path)!
	assert reopened.forum_news_defaults_added
	assert !reopened.items.any(it.url == 'https://www.wired.com/')
	assert reopened.items.last().title == 'Another'
}

fn test_fresh_forum_news_defaults_keep_the_original_bookmark_order() {
	mut store := open('')!
	store.seed_optimized_sites()!
	store.seed_forum_news_sites()!
	assert store.visible
	assert store.items.map(it.url) == optimizedsites.bookmarked_sites.map(it.address)
	assert store.items.filter(it.url == 'https://news.ycombinator.com/').len == 1
	assert store.items.any(it.url == 'https://old.reddit.com/r/programming/')
	assert store.items.any(it.url == 'https://chatgpt.com/')
}

fn test_failed_forum_news_default_save_rolls_back_the_migration_flag_and_items() {
	mut store := open('')!
	store.add('https://private.example/', 'Private')!
	before := store.items.clone()
	version := store.version
	store.path = '/dev/null/bookmarks.json'
	store.seed_forum_news_sites() or {
		assert !store.forum_news_defaults_added
		assert store.items == before && store.version == version && !store.visible
		return
	}
	assert false, 'Failed migration must preserve the existing bookmarks'
}
