module browsersettings

import processlock
import json2
import os
import platform
import url

struct SavedZoomLevels {
	levels map[string]f64
}

// Shared by tabs and retained outside document allocation scopes.
@[heap]
pub struct ZoomLevels {
mut:
	profile_hash [32]u8
	path         string
	levels       map[string]f64
}

pub fn zoom_levels_path() string {
	return os.join_path(os.dir(default_path()), 'zoom.json')
}

// Schemes, ports, paths and credentials do not partition a hostname's zoom.
// Internal pages and local files have no domain preference.
pub fn zoom_domain(address string) string {
	parsed := url.parse(address) or { return '' }
	if parsed.scheme !in ['http', 'https'] { return '' }
	host := parsed.host or { return '' }
	return host.serialize().trim_string_right('.')
}

pub fn open_zoom_levels(path string) !&ZoomLevels {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	$if prealloc {
		_ = json2.encode(SavedZoomLevels{})
	}
	mut store := &ZoomLevels{ path: path.clone() }
	if path != '' && os.exists(path) {
		contents := os.read_file(path)!
		store.profile_hash = processlock.fingerprint(contents)
		saved := json2.decode[SavedZoomLevels](contents)!
		for domain, level in saved.levels {
			if domain != '' && zoom_domain('https://${domain}') == domain
				&& level >= 0.25 && level <= 5 && level != 1 {
				store.levels[domain] = level
			}
		}
	}
	return store
}

pub fn (store &ZoomLevels) for_url(address string) f64 {
	return store.levels[zoom_domain(address)] or { 1.0 }
}

pub fn (mut store ZoomLevels) set_for_url(address string, level f64) ! {
	if !(level >= 0.25 && level <= 5) { return error('Invalid page zoom level.') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	guard := processlock.acquire(store.path)!
	defer { guard.release() }
	store.reload()!
	domain := zoom_domain(address)
	if domain == '' || store.for_url(address) == level { return }
	mut levels := store.levels.clone()
	if level == 1 {
		levels.delete(domain)
	} else {
		levels[domain] = level
	}
	mut scratch := platform.begin_thread_scratch('zoom profile update')
	defer { scratch.finish() }
	store.write_zoom_levels(levels) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	scratch.leave()
	store.levels = levels
}

fn (mut store ZoomLevels) write_zoom_levels(levels map[string]f64) ! {
	if store.path == '' { return }
	os.mkdir_all(os.dir(store.path))!
	temporary := '${store.path}.tmp-${os.getpid()}'
	mut file := os.open_file(temporary, 'w', 0o600)!
	defer { os.rm(temporary) or {} }
	encoded := json2.encode(SavedZoomLevels{ levels: levels })
	file.write_string(encoded) or {
		file.close()
		return err
	}
	file.close()
	platform.atomic_replace_file(temporary, store.path)!
	store.profile_hash = processlock.fingerprint(encoded)
}

pub fn (mut store ZoomLevels) reload() ! {
	if store.path == '' || !os.exists(store.path) { return }
	scratch := platform.begin_thread_scratch('zoom profile refresh')
	defer { scratch.finish() }
	contents := os.read_file(store.path) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	hash := processlock.fingerprint(contents)
	if hash == store.profile_hash { return }
	fresh := open_zoom_levels(store.path) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	store.levels = fresh.levels
	store.profile_hash = fresh.profile_hash
}
