// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// The PageClient cookie boundary used by CookieStore.cpp, represented as a
// deterministic in-memory embedding contract for the V translation.
module cookiestore

import time
import url

pub enum CookieSameSite {
	strict
	lax
	none
}

// HTTP::Cookie::Cookie fields consumed by the upstream CookieStore algorithms.
@[heap]
pub struct Cookie {
pub mut:
	name           string
	value          string
	domain         string
	path           string = '/'
	expires        ?f64
	http_only      bool
	secure         bool
	same_site      CookieSameSite = .strict
	partitioned    bool
	host_only      bool = true
	creation_index u64
}

pub struct CookieMutation {
pub:
	cookie  Cookie
	deleted bool
}

@[heap]
pub struct CookieStoreBackend {
mut:
	cookies_      []Cookie
	mutations_    []CookieMutation
	next_creation u64 = 1
	now_override_ ?f64
}

pub fn CookieStoreBackend.create() &CookieStoreBackend {
	return &CookieStoreBackend{}
}

pub fn (backend &CookieStoreBackend) now_ms() f64 {
	if value := backend.now_override_ {
		return value
	}
	return f64(time.now().unix_milli())
}

// A deterministic clock hook for conformance tests and embedders with their
// own cookie clock. Passing none restores the system clock.
pub fn (mut backend CookieStoreBackend) set_now_override(value ?f64) {
	backend.now_override_ = value
}

pub fn (backend &CookieStoreBackend) cookies() []Cookie {
	return backend.cookies_.clone()
}

pub fn (backend &CookieStoreBackend) mutations() []CookieMutation {
	return backend.mutations_.clone()
}

pub fn (mut backend CookieStoreBackend) clear_mutations() {
	backend.mutations_.clear()
}

// Adds a cookie as if it already existed in the browser cookie jar. This is
// the PageClient read-side seam, not part of the CookieStore Web IDL API.
pub fn (mut backend CookieStoreBackend) seed(cookie Cookie) {
	mut stored := cookie
	if stored.creation_index == 0 {
		stored.creation_index = backend.next_creation
		backend.next_creation++
	}
	backend.cookies_ << stored
}

fn url_host_string(record &url.URL) string {
	if host := record.host {
		return host.serialize().trim('[]').to_lower()
	}
	return ''
}

fn domain_matches(host string, cookie_domain string, host_only bool) bool {
	if host_only {
		return host == cookie_domain
	}
	return host == cookie_domain || host.ends_with('.' + cookie_domain)
}

fn path_matches(request_path string, cookie_path string) bool {
	if request_path == cookie_path {
		return true
	}
	if !request_path.starts_with(cookie_path) {
		return false
	}
	return cookie_path.ends_with('/')
		|| (request_path.len > cookie_path.len && request_path[cookie_path.len] == `/`)
}

fn same_expiry(first ?f64, second ?f64) bool {
	if first_value := first {
		if second_value := second { return first_value == second_value }
		return false
	}
	return second == none
}

// PageClient::page_did_request_all_cookies_cookiestore. The UI process does
// this filtering in Ladybird; keeping it behind this type preserves that
// renderer/embedder boundary.
pub fn (backend &CookieStoreBackend) query(record &url.URL) []Cookie {
	host := url_host_string(record)
	mut request_path := record.serialize_path()
	if request_path.len == 0 {
		request_path = '/'
	}
	now := backend.now_ms()
	mut matches := []Cookie{}
	for cookie in backend.cookies_ {
		if cookie.http_only {
			continue
		}
		if expiry := cookie.expires {
			if expiry <= now {
				continue
			}
		}
		if cookie.secure && record.scheme != 'https' && record.scheme != 'wss' {
			continue
		}
		if !domain_matches(host, cookie.domain.to_lower(), cookie.host_only)
			|| !path_matches(request_path, cookie.path) {
			continue
		}
		matches << cookie
	}
	// Cookies retrieval orders longer paths first, then older cookies.
	matches.sort_with_compare(fn (a &Cookie, b &Cookie) int {
		if a.path.len != b.path.len {
			return b.path.len - a.path.len
		}
		if a.creation_index < b.creation_index {
			return -1
		}
		if a.creation_index > b.creation_index {
			return 1
		}
		return 0
	})
	return matches
}

// PageClient::page_did_set_cookie. Replacement and expiry removal are kept
// here because they belong to the browser cookie jar, not the renderer API.
fn (mut backend CookieStoreBackend) store(record &url.URL, cookie Cookie) {
	mut stored := cookie
	if stored.domain.len == 0 {
		stored.domain = url_host_string(record)
		stored.host_only = true
	}
	mut existing_index := -1
	for index, existing in backend.cookies_ {
		if existing.name == stored.name && existing.domain == stored.domain
			&& existing.host_only == stored.host_only && existing.path == stored.path
			&& existing.partitioned == stored.partitioned {
			existing_index = index
			break
		}
	}
	if expiry := stored.expires {
		if expiry <= backend.now_ms() {
			if existing_index >= 0 {
				backend.cookies_.delete(existing_index)
			}
			backend.mutations_ << CookieMutation{
				cookie:  stored
				deleted: true
			}
			return
		}
	}
	mut cookie_changed := true
	if existing_index >= 0 {
		existing := backend.cookies_[existing_index]
		cookie_changed = existing.value != stored.value || existing.same_site != stored.same_site
			|| !same_expiry(existing.expires, stored.expires) || existing.secure != stored.secure
			|| existing.http_only != stored.http_only
		stored.creation_index = existing.creation_index
		backend.cookies_[existing_index] = stored
	} else {
		stored.creation_index = backend.next_creation
		backend.next_creation++
		backend.cookies_ << stored
	}
	// Replacing a cookie with the same value and attributes is not a change.
	if !cookie_changed { return }
	backend.mutations_ << CookieMutation{
		cookie: stored
	}
}
