module browsercookies

import json2
import os
import platform
import processlock
import time

struct CookieFileVersion {
	device u64
	inode u64
	size u64
	modified i64
	changed i64
}

fn cookie_file_version(path string) !CookieFileVersion {
	info := os.stat(path)!
	return CookieFileVersion{info.dev, info.inode, info.size, info.mtime, info.ctime}
}

// An empty path keeps standalone engine callers and tests in memory. Browser
// startup supplies its profile path before any navigation or script executes.
pub fn initialize(path string) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	$if prealloc { _ = json2.encode(StoredCookie{}) }
	mut jar := unsafe { &Jar(session_jar) }
	jar.lock.@lock()
	defer { jar.lock.unlock() }
	guard := processlock.acquire(path)!
	defer { guard.release() }
	jar.path = path.clone()
	jar.file_version = none
	jar.cookies.clear()
	jar.next_order = 0
	jar.reload_profile(time.now().unix())!
}

fn (jar &Jar) profile_lock() !processlock.Lock {
	return processlock.acquire(jar.path)
}

// Hold both the jar mutex and the stable profile lock while refreshing and
// writing. Two tab processes can update different cookies without losing either
// update, and deletions/replacements reach an already running sibling process.
fn (mut jar Jar) reload_profile(now i64) ! {
	if jar.path == '' { return }
	if !os.exists(jar.path) {
		if jar.file_version == none { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		jar.cookies = jar.cookies.filter((it.expires or { max_i64 }) == max_i64)
		jar.file_version = none
		return
	}
	version := cookie_file_version(jar.path)!
	if previous := jar.file_version {
		if previous == version { return }
	}
	if version.size > 16 * 1024 * 1024 { return error('Cookie profile is too large') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	loaded := json2.decode[[]StoredCookie](os.read_file(jar.path)!)!
	mut merged := jar.cookies.filter((it.expires or { max_i64 }) == max_i64)
	for cookie in loaded {
		expires := cookie.expires or { continue }
		if expires <= now || expires == max_i64 { continue }
		if merged.any(it.name == cookie.name && it.domain == cookie.domain
			&& it.path == cookie.path && it.host_only == cookie.host_only) { continue }
		if merged.len >= 3000 { break }
		merged << cookie
	}
	jar.cookies = merged
	for cookie in jar.cookies {
		if cookie.order >= jar.next_order { jar.next_order = cookie.order + 1 }
	}
	jar.file_version = version
}

fn (mut jar Jar) save_profile() ! {
	if jar.path == '' { return }
	temporary := '${jar.path}.tmp-${os.getpid()}'
	defer { os.rm(temporary) or {} }
	// Session cookies have no expiry. Never turn them into persistent logins.
	retained := jar.cookies.filter((it.expires or { max_i64 }) != max_i64)
	mut file := os.open_file(temporary, 'w', 0o600)!
	file.write_string(json2.encode(retained, escape_unicode: true)) or {
		file.close()
		return err
	}
	file.close()
	platform.atomic_replace_file(temporary, jar.path)!
	jar.file_version = cookie_file_version(jar.path)!
}
