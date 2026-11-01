module browserbookmarks

import browserhistory
import processlock
import json2
import os
import platform
import optimizedsites

pub struct Bookmark {
pub:
	url   string
	title string
}

struct SavedBookmarks {
pub:
	optimized_defaults_added bool
	visible bool
	items   []Bookmark
	version u64
}

// One profile record is shared by all tabs, outside document arenas.
@[heap]
pub struct Store {
pub mut:
	optimized_defaults_added bool
	visible bool
	items   []Bookmark
	version u64
mut:
	profile_hash [32]u8
	path         string
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
		contents := os.read_file(path)!
		store.profile_hash = processlock.fingerprint(contents)
		saved := json2.decode[SavedBookmarks](contents)!
		store.optimized_defaults_added = saved.optimized_defaults_added
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

// Migrate once, preserving user bookmarks and subsequent edits/removals.
pub fn (mut store Store) seed_optimized_sites() ! {
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload()!
	if store.optimized_defaults_added {
		store.update_optimized_reddit()!
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut items := []Bookmark{}
	for site in optimizedsites.sites {
		existing := store.items.filter(it.url == site.address)
		items << if existing.len > 0 { existing[0] } else {
			Bookmark{url: site.address, title: site.title}
		}
	}
	for item in store.items {
		if !items.any(it.url == item.url) { items << item }
	}
	store.optimized_defaults_added = true
	store.persist(true, items) or {
		store.optimized_defaults_added = false
		return err
	}
}

fn (mut store Store) update_optimized_reddit() ! {
	if !store.items.any(it.url == 'https://old.reddit.com/' && it.title == 'Old Reddit') { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	already_present := store.items.any(it.url == optimizedsites.reddit_address)
	mut items := []Bookmark{cap: store.items.len}
	for item in store.items {
		if item.url == 'https://old.reddit.com/' && item.title == 'Old Reddit' {
			if !already_present { items << Bookmark{...item, url: optimizedsites.reddit_address} }
		} else {
			items << item
		}
	}
	store.persist(store.visible, items)!
}

pub fn eligible_url(address string) bool {
	return browserhistory.eligible_url(address)
		|| address in ['about:blank', 'about:home', 'vox://history']
}

pub fn (mut store Store) add(address string, title string) ! {
	if !eligible_url(address) { return }
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload()!
	if store.items.any(it.url == address) { return }
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
	address := store.items[index].url
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload()!
	mut items := store.items.filter(it.url != address)
	store.persist(store.visible, items)!
}

pub fn (mut store Store) toggle_visible() ! {
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload()!
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

fn (mut store Store) write_profile(visible bool, items []Bookmark) ! {
	if store.path != '' {
		os.mkdir_all(os.dir(store.path))!
		temporary := '${store.path}.tmp-${os.getpid()}'
		mut file := os.open_file(temporary, 'w', 0o600)!
		encoded := json2.encode(SavedBookmarks{ visible: visible, items: items, version: store.version + 1, optimized_defaults_added: store.optimized_defaults_added },
			escape_unicode: true
		)
		file.write_string(encoded) or {
			file.close()
			os.rm(temporary) or {}
			return err
		}
		file.close()
		os.rename(temporary, store.path) or {
			os.rm(temporary) or {}
			return err
		}
		store.profile_hash = processlock.fingerprint(encoded)
	}
}

pub fn (mut store Store) reload() ! {
	if store.path == '' || !os.exists(store.path) { return }
	scratch := platform.begin_thread_scratch('bookmark profile refresh')
	defer { scratch.finish() }
	contents := os.read_file(store.path) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	hash := processlock.fingerprint(contents)
	if hash == store.profile_hash { return }
	fresh := open(store.path) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	store.items = fresh.items
	store.visible = fresh.visible
	store.version = fresh.version
	store.optimized_defaults_added = fresh.optimized_defaults_added
	store.profile_hash = fresh.profile_hash
}
