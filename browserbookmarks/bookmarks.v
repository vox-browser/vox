module browserbookmarks

import browserhistory
import json2
import os
import platform

pub struct Bookmark {
pub:
	url   string
	title string
}

struct SavedBookmarks {
pub:
	visible bool
	items   []Bookmark
	version u64
}

// One profile record is shared by all tabs, outside document arenas.
@[heap]
pub struct Store {
pub mut:
	visible bool
	items   []Bookmark
	version u64
mut:
	path string
}

pub fn default_path() string {
	return os.join_path(os.dir(browserhistory.default_path()), 'bookmarks.json')
}

pub fn open(path string) !&Store {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// json2 retains field metadata after the first encode. Warm both records
	// here so saving inside a scratch arena cannot invalidate either cache.
	$if prealloc {
		_ := json2.encode(SavedBookmarks{ items: [Bookmark{}] })
	}
	mut store := &Store{ path: path.clone() }
	if path != '' && os.exists(path) {
		saved := json2.decode[SavedBookmarks](os.read_file(path)!)!
		store.visible = saved.visible
		store.version = saved.version
		for item in saved.items {
			if eligible_url(item.url) && !store.items.any(it.url == item.url) {
				store.items << item
			}
		}
	}
	return store
}

pub fn eligible_url(address string) bool {
	return browserhistory.eligible_url(address)
		|| address in ['about:blank', 'about:home', 'vox://history']
}

pub fn (mut store Store) add(address string, title string) ! {
	if !eligible_url(address) || store.items.any(it.url == address) { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut items := store.items.clone()
	items << Bookmark{
		url:   address.clone()
		title: if title.trim_space() != '' { title.clone() } else { address.clone() }
	}
	store.persist(store.visible, items)!
}

pub fn (mut store Store) remove(index int) ! {
	if index < 0 || index >= store.items.len { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut items := store.items.clone()
	items.delete(index)
	store.persist(store.visible, items)!
}

pub fn (mut store Store) toggle_visible() ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	store.persist(!store.visible, store.items)!
}

fn (mut store Store) persist(visible bool, items []Bookmark) ! {
	scratch := platform.begin_thread_scratch('bookmark profile update')
	defer { scratch.finish() }
	store.write_profile(visible, items) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	scratch.leave()
	store.visible = visible
	store.items = items
	store.version++
}

fn (store &Store) write_profile(visible bool, items []Bookmark) ! {
	if store.path != '' {
		os.mkdir_all(os.dir(store.path))!
		temporary := '${store.path}.tmp-${os.getpid()}'
		mut file := os.open_file(temporary, 'w', 0o600)!
		file.write_string(json2.encode(SavedBookmarks{ visible: visible, items: items, version: store.version + 1 },
			escape_unicode: true
		)) or {
			file.close()
			os.rm(temporary) or {}
			return err
		}
		file.close()
		os.rename(temporary, store.path) or {
			os.rm(temporary) or {}
			return err
		}
	}
}
