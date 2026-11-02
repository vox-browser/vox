// Apply the browser's one-time catalog migration to an existing profile.
// Run from the canonical checkout; the browser uses this same Store method.
module main

import browserbookmarks
import os

fn main() {
	if os.args.len > 2 { panic('usage: add_forum_news_bookmarks [bookmarks.json]') }
	path := if os.args.len == 2 { os.args[1] } else { browserbookmarks.default_path() }
	mut store := browserbookmarks.open(path) or { panic(err) }
	before := store.items.len
	store.seed_forum_news_sites() or { panic(err) }
	println('Added ${store.items.len - before} forum/news bookmarks; ${store.items.len} total.')
}
