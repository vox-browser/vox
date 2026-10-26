module browserhistory

import processlock
import json2
import os
import platform
import time

pub const retention_seconds = i64(90 * 24 * 60 * 60)
pub const stylesheet = $embed_file('history.css').to_string()
const maximum_visits = 50000

pub struct Visit {
pub:
	id          i64
	url         string
	title       string
	favicon_url string
	visited_at  i64
}

// Shared by all tabs. The browser owns this record outside document arenas.
@[heap]
pub struct Store {
pub mut:
	visits  []Visit
	version u64
mut:
	profile_hash [32]u8
	path         string
	next_id      i64 = 1
	updated_at   i64
}

pub fn open(path string, now i64) !&Store {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// json2 retains per-type field metadata after its first encode. Initialize
	// it here so a later save cannot leave that cache in a temporary arena.
	$if prealloc {
		_ := json2.encode(Visit{})
	}
	mut store := &Store{ path: path.clone(), updated_at: now }
	if path != '' && os.exists(path) {
		contents := os.read_file(path)!
		store.visits = json2.decode[[]Visit](contents)!
		store.profile_hash = processlock.fingerprint(contents)
	}
	mut retained := []Visit{}
	for visit in store.visits {
		if visit.id >= store.next_id { store.next_id = visit.id + 1 }
		if eligible_url(visit.url) && visit.visited_at > now - retention_seconds {
			retained << visit
		}
	}
	retained.sort(a.visited_at > b.visited_at)
	if retained.len > maximum_visits { retained = retained[..maximum_visits].clone() }
	store.visits = retained
	return store
}

pub fn eligible_url(address string) bool {
	return address.starts_with('https://') || address.starts_with('http://')
		|| address.starts_with('file://')
}

pub fn (mut store Store) record(address string, title string, now i64) ! {
	store.record_with_favicon(address, title, '', now)!
}

pub fn (mut store Store) record_with_favicon(address string, title string, favicon_url string, now i64) ! {
	if !eligible_url(address) { return }
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload_at(now)!
	store.updated_at = now
	// Only the new strings and the reusable visit array outlive this operation.
	persistent := platform.enter_persistent()
	owned_address := address.clone()
	owned_title := title.clone()
	owned_favicon := favicon_url.clone()
	platform.leave_persistent(persistent)
	scratch := platform.begin_thread_scratch('browser history update')
	defer { scratch.finish() }
	mut visits := store.visits.filter(it.visited_at > now - retention_seconds)
	// A cached document followed by its network refresh is one visit.
	if visits.len > 0 && visits[0].url == address && now >= visits[0].visited_at
		&& now - visits[0].visited_at < 60 {
		visits[0] = Visit{ ...visits[0], title: owned_title, favicon_url: owned_favicon, visited_at: now }
	} else {
		visits.insert(0, Visit{ id: store.next_id, url: owned_address, title: owned_title, favicon_url: owned_favicon, visited_at: now })
		store.next_id++
	}
	if visits.len > maximum_visits { visits = visits[..maximum_visits].clone() }
	store.persist(visits) or {
		scratch.leave()
		return error(err.msg().clone())
	}
}

pub fn (store &Store) search(query string) []Visit {
	terms := query.to_lower().fields()
	return store.visits.filter(matches(it, terms))
}

fn matches(visit Visit, terms []string) bool {
	if terms.len == 0 { return true }
	text := '${visit.title}\n${visit.url}'.to_lower()
	for term in terms {
		if !text.contains(term) { return false }
	}
	return true
}

pub fn (mut store Store) remove(ids []i64) ! {
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload_at(store.updated_at)!
	scratch := platform.begin_thread_scratch('browser history update')
	defer { scratch.finish() }
	mut selected := map[i64]bool{}
	for id in ids { selected[id] = true }
	store.persist(store.visits.filter(!selected[it.id])) or {
		scratch.leave()
		return error(err.msg().clone())
	}
}

// A zero cutoff means all history; time ranges include their starting instant.
pub fn (mut store Store) clear_since(cutoff i64) ! {
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload_at(store.updated_at)!
	scratch := platform.begin_thread_scratch('browser history update')
	defer { scratch.finish() }
	store.persist(store.visits.filter(cutoff != 0 && it.visited_at < cutoff)) or {
		scratch.leave()
		return error(err.msg().clone())
	}
}

fn (mut store Store) persist(visits []Visit) ! {
	if store.path != '' {
		os.mkdir_all(os.dir(store.path))!
		temporary := '${store.path}.tmp-${os.getpid()}'
		mut file := os.open_file(temporary, 'w', 0o600)!
		encoded := json2.encode(visits, escape_unicode: true, time_as_unix: true)
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
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	store.visits.clear()
	store.visits << visits
	store.version++
}

pub fn default_path() string {
	if directory := os.getenv_opt('VOX_PROFILE_DIR') {
		if directory != '' { return os.join_path(directory, 'history.json') }
	}
	$if macos {
		return os.join_path(os.home_dir(), 'Library', 'Application Support', 'Vox', 'history.json')
	} $else {
		return os.join_path(os.user_config_dir() or { os.join_path(os.home_dir(), '.config') }, 'vox', 'history.json')
	}
}

pub fn now() i64 { return time.now().unix() }

// Renamed profile files are complete snapshots. Avoid persistent allocations
// while an unchanged profile is polled by a background tab.
pub fn (mut store Store) reload() ! {
	store.reload_at(now())!
}

fn (mut store Store) reload_at(timestamp i64) ! {
	if store.path == '' || !os.exists(store.path) { return }
	scratch := platform.begin_thread_scratch('history profile refresh')
	defer { scratch.finish() }
	contents := os.read_file(store.path) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	hash := processlock.fingerprint(contents)
	if hash == store.profile_hash { return }
	fresh := open(store.path, timestamp) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	store.visits = fresh.visits
	store.next_id = fresh.next_id
	store.profile_hash = fresh.profile_hash
	store.updated_at = timestamp
	store.version++
}
