// Native browser session cookies, shared by navigation, Fetch and Document.
// Storage/matching follows LibWebView/CookieJar.cpp. Persistent cookies use
// the browser profile; session cookies remain local to the browser process.
module browsercookies

import httpcookie
import platform
import sync
import time
import url

struct StoredCookie {
	name string
	value string
	domain string
	path string
	host_only bool
	secure bool
	http_only bool
	same_site httpcookie.SameSite
	expires ?i64
mut:
	order u64
}

@[heap]
struct Jar {
mut:
	lock sync.Mutex
	cookies []StoredCookie
	next_order u64
	path string
	file_version ?CookieFileVersion
}

const session_jar = &Jar{}

// HTTP callers supply the initiator's schemeful site. Document access does
// not apply the HTTP SameSite retrieval filter and still excludes HttpOnly.
pub struct Context {
pub:
	same_site bool = true
	top_level bool
	safe_method bool = true
}

pub fn request_context(record &url.URL, source_url string, top_level bool, method string) Context {
	source := url.parse(source_url) or { return Context{same_site: false, top_level: top_level, safe_method: method in ['GET', 'HEAD', 'OPTIONS', 'TRACE']} }
	return Context{
		same_site: record.origin().is_same_site(source.origin())
		top_level: top_level
		safe_method: method in ['GET', 'HEAD', 'OPTIONS', 'TRACE']
	}
}

pub fn cookie_string(record &url.URL, source httpcookie.Source, context Context) string {
	mut jar := unsafe { &Jar(session_jar) }
	return jar.cookie_string_at(record, source, context, time.now().unix())
}

pub fn set_cookie(record &url.URL, cookie httpcookie.ParsedCookie, source httpcookie.Source, context Context) {
	mut jar := unsafe { &Jar(session_jar) }
	jar.set_cookie_at(record, cookie, source, context, time.now().unix())
}

pub fn store_response_cookies(resource_url string, source_url string, top_level bool, method string, values []string) {
	record := url.parse(resource_url) or { return }
	context := request_context(&record, source_url, top_level, method)
	for value in values {
		cookie := httpcookie.parse_cookie(&record, value) or { continue }
		set_cookie(&record, cookie, .http, context)
	}
}

// The Cookie header for an HTTP request: session cookies first, then the
// same-site cookies imported from another browser.
pub fn request_header(resource_url string, source_url string, top_level bool, method string) string {
	record := url.parse(resource_url) or { return '' }
	now := time.now().unix()
	mut jar := unsafe { &Jar(session_jar) }
	stored := jar.cookie_string_at(&record, .http, request_context(&record, source_url, top_level,
		method), now)
	imported := imported_request_header(resource_url, source_url, now)
	if stored == '' { return imported }
	if imported == '' { return stored }
	return stored + '; ' + imported
}

fn domain_matches(host string, domain string) bool {
	if host == domain { return true }
	if domain == '' || !host.ends_with('.' + domain) { return false }
	parsed := url.parse_host(host, false) or { return false }
	return parsed.is_domain()
}

fn path_matches(path string, cookie_path string) bool {
	return path == cookie_path || (path.starts_with(cookie_path)
		&& (cookie_path.ends_with('/') || (path.len > cookie_path.len && path[cookie_path.len] == `/`)))
}

fn (mut jar Jar) purge_expired(now i64) {
	mut index := jar.cookies.len
	for index > 0 {
		index--
		if (jar.cookies[index].expires or { max_i64 }) <= now { jar.cookies.delete(index) }
	}
}

fn (mut jar Jar) set_cookie_at(record &url.URL, parsed httpcookie.ParsedCookie, source httpcookie.Source, context Context, now i64) {
	if record.scheme !in ['http', 'https'] || (parsed.name == '' && parsed.value == '')
		|| parsed.name.len + parsed.value.len > 4096
		|| httpcookie.cookie_contains_invalid_control_character(parsed.name)
		|| httpcookie.cookie_contains_invalid_control_character(parsed.value) { return }
	host := httpcookie.canonicalize_domain(record) or { return }
	mut domain := parsed.domain or { '' }
	if domain.bytes().any(it > 127) { return }
	if domain.len > 1024 { domain = '' }
	if domain != '' {
		// The PSL's prevailing star rule also makes an unknown TLD a suffix.
		suffix := url.get_public_suffix(domain) or { domain.all_after_last('.') }
		if suffix == domain {
			if domain != host { return }
			domain = ''
		}
	}
	host_only := domain == ''
	if !host_only && !domain_matches(host, domain) { return }
	if host_only { domain = host }
	path := parsed.path or { httpcookie.default_path(record) }
	if path.len > 1024 || !path.starts_with('/') { return }
	secure := parsed.secure_attribute_present
	if secure && record.scheme != 'https' { return }
	if source == .non_http && parsed.http_only_attribute_present { return }
	if parsed.same_site_attribute == .none && !secure { return }
	if source == .http && parsed.same_site_attribute != .none && !context.same_site && !context.top_level { return }
	lower_name := parsed.name.to_lower()
	if lower_name.starts_with('__secure-') && !secure { return }
	if lower_name.starts_with('__host-') && (!secure || !host_only || (parsed.path or { '' }) != '/') { return }
	if parsed.name == '' && (parsed.value.to_lower().starts_with('__secure-') || parsed.value.to_lower().starts_with('__host-')) { return }
	// Both strings and the array can outlive a document's scratch arena or a
	// background resource thread. Own all retained fields in persistent storage.
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	jar.lock.@lock()
	defer { jar.lock.unlock() }
	guard := jar.profile_lock() or { return }
	defer { guard.release() }
	jar.reload_profile(now) or { return }
	jar.purge_expired(now)
	mut replacement := -1
	mut order := jar.next_order
	for index, old in jar.cookies {
		if old.name != parsed.name { continue }
		if record.scheme != 'https' && old.secure
			&& (domain_matches(old.domain, domain) || domain_matches(domain, old.domain))
			&& path_matches(path, old.path) { return }
		if old.domain == domain && old.path == path && old.host_only == host_only {
			if source == .non_http && old.http_only { return }
			replacement = index
			order = old.order
		}
	}
	expires := parsed.expiry_time_from_max_age_attribute or { parsed.expiry_time_from_expires_attribute or { max_i64 } }
	if expires <= now {
		if replacement >= 0 { jar.cookies.delete(replacement) }
		jar.save_profile() or { return }
		return
	}
	cookie := StoredCookie{
		name: parsed.name.clone(), value: parsed.value.clone(), domain: domain.clone(), path: path.clone()
		host_only: host_only, secure: secure, http_only: parsed.http_only_attribute_present
		same_site: parsed.same_site_attribute, expires: expires, order: order
	}
	if replacement >= 0 { jar.cookies[replacement] = cookie }
	else {
		jar.next_order++
		// A bounded session store cannot grow without limit on long-lived pages.
		if jar.cookies.len >= 3000 { jar.cookies.delete(0) }
		jar.cookies << cookie
	}
	jar.save_profile() or { return }
}

fn (mut jar Jar) cookie_string_at(record &url.URL, source httpcookie.Source, context Context, now i64) string {
	if record.scheme !in ['http', 'https'] { return '' }
	host := httpcookie.canonicalize_domain(record) or { return '' }
	path := record.serialize_path()
	jar.lock.@lock()
	defer { jar.lock.unlock() }
	guard := jar.profile_lock() or { return '' }
	defer { guard.release() }
	jar.reload_profile(now) or { return '' }
	jar.purge_expired(now)
	mut matches := []StoredCookie{}
	for cookie in jar.cookies {
		if (cookie.host_only && host != cookie.domain) || (!cookie.host_only && !domain_matches(host, cookie.domain)) { continue }
		if !path_matches(path, cookie.path) || (cookie.secure && record.scheme != 'https')
			|| (source == .non_http && cookie.http_only) { continue }
		if source == .http && !context.same_site && cookie.same_site != .none {
			if cookie.same_site == .strict || !context.top_level || !context.safe_method { continue }
		}
		matches << cookie
	}
	matches.sort_with_compare(fn (a &StoredCookie, b &StoredCookie) int {
		if a.path.len != b.path.len { return b.path.len - a.path.len }
		if a.order < b.order { return -1 }
		return if a.order == b.order { 0 } else { 1 }
	})
	return matches.map(if it.name == '' { it.value } else { it.name + '=' + it.value }).join('; ')
}
