module browsersettings

import json2
import net.urllib
import os
import platform
import sync
import url

pub struct Proxy {
pub:
	// settings.json also owns the temporary optimized-sites browsing mode.
	allow_any_site bool
	enable_tab_coloring bool
	enabled bool
	host    string = '127.0.0.1'
	port    string = '1080'
	// Empty selects every destination; otherwise comma-separated hostnames.
	sites string
}

@[heap]
struct Runtime {
mut:
	lock       sync.Mutex
	path       string
	proxy      Proxy
	configured bool
	file_version ?SettingsFileVersion
}

struct SettingsFileVersion {
	device   u64
	inode    u64
	size     u64
	modified i64
	changed  i64
}

fn settings_file_version(path string) !SettingsFileVersion {
	info := os.stat(path)!
	return SettingsFileVersion{info.dev, info.inode, info.size, info.mtime, info.ctime}
}

const runtime = &Runtime{}

pub fn default_path() string {
	if directory := os.getenv_opt('VOX_PROFILE_DIR') {
		if directory != '' { return os.join_path(directory, 'settings.json') }
	}
	$if macos {
		return os.join_path(os.home_dir(), 'Library', 'Application Support', 'Vox', 'settings.json')
	} $else {
		return os.join_path(os.user_config_dir() or { os.join_path(os.home_dir(), '.config') }, 'vox', 'settings.json')
	}
}

pub fn (proxy Proxy) normalized() !Proxy {
	host := proxy.host.trim_space()
	port := proxy.port.trim_space()
	sites := proxy.sites.trim_space()
	if !proxy.enabled { return Proxy{ ...proxy, host: host, port: port, sites: sites } }
	if host == '' || host.bytes().any(it <= 32 || it == 127)
		|| host.contains_any('/\\?#@') {
		return error('Enter a proxy hostname or IP address, without a URL scheme.')
	}
	if port == '' || !port.bytes().all(it >= `0` && it <= `9`)
		|| port.len > 5 || port.int() < 1 || port.int() > 65535 {
		return error('Enter a port between 1 and 65535.')
	}
	// Parse brackets separately, then validate IPv6 numerically so an embedded
	// hostname:port cannot be mistaken for an IPv6 literal.
	authority := if host.contains(':') && !host.starts_with('[') { '[${host}]' } else { host }
	parsed := urllib.parse('socks5h://${authority}:${port}') or {
		return error('Enter a valid proxy hostname or IP address.')
	}
	if parsed.hostname() == '' || parsed.port() != port
		|| (host.contains_any(':[]') && !parsed.hostname().contains(':')) {
		return error('Enter a valid proxy hostname or IP address.')
	}
	if parsed.hostname().contains(':') && !valid_ipv6_host(parsed.hostname()) {
		return error('Enter a valid proxy hostname or IP address.')
	}
	return Proxy{ ...proxy, host: parsed.hostname(), port: port.int().str(), sites: normalize_proxy_sites(sites)! }
}

fn normalize_proxy_sites(input string) !string {
	if input == '' { return '' }
	mut sites := []string{}
	for entry in input.split_any(', \t\r\n') {
		if entry == '' { continue }
		// Accept hostnames and IP literals, never URL/path/port/wildcard rules.
		authority := if entry.contains(':') && !entry.starts_with('[') {
			'[${entry}]'
		} else {
			entry
		}
		host := url.parse_host(authority, false) or {
			return error('Enter site hostnames without schemes, paths, ports or wildcards.')
		}
		site := host.serialize().trim_string_right('.')
		if site == '' || entry.contains_any('*%') || (host.is_domain()
			&& site.split('.').any(it == '' || !it.bytes().all((it >= `a` && it <= `z`) || (it >= `0` && it <= `9`) || it == `-` || it == `_`))) {
			return error('Enter site hostnames without schemes, paths, ports or wildcards.')
		}
		if site !in sites { sites << site }
	}
	// A list containing only separators must not accidentally enable all sites.
	if sites.len == 0 {
		return error('Enter at least one site, or leave the field empty for all sites.')
	}
	return sites.join(', ')
}

pub fn (proxy Proxy) url() string {
	if !proxy.enabled { return '' }
	host := if proxy.host.contains(':') { '[${proxy.host}]' } else { proxy.host }
	// Both browser transports resolve destination names at the SOCKS server.
	return 'socks5h://${host}:${proxy.port}'
}

pub fn (proxy Proxy) url_for(resource_url string) string {
	if !proxy.enabled { return '' }
	if proxy.sites == '' { return proxy.url() }
	address := url.parse(resource_url) or { return '' }
	host := address.host or { return '' }
	destination := host.serialize().trim_string_right('.')
	for site in proxy.sites.split(', ') {
		if destination == site { return proxy.url() }
		// IP literals match exactly. Domain rules include subdomains at a label
		// boundary, so example.com never matches notexample.com.
		if host.is_domain() && destination.ends_with('.' + site) {
			return proxy.url()
		}
	}
	return ''
}

// Called before the first navigation. An absent profile leaves the existing
// command-line/environment proxy configuration available until the user saves.
pub fn initialize(path string) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut proxy := Proxy{}
	configured := os.exists(path)
	// Snapshot before reading: a concurrent atomic replacement will be picked
	// up on the next read even if it happens during initialization.
	version := settings_file_version(path) or { SettingsFileVersion{} }
	if configured { proxy = json2.decode[Proxy](os.read_file(path)!)!.normalized()! }
	$if prealloc {
		_ = json2.encode(proxy)
	}
	mut state := unsafe { runtime }
	state.lock.lock()
	defer { state.lock.unlock() }
	state.path = path.clone()
	state.proxy = proxy
	state.configured = configured
	state.file_version = none
	if configured { state.file_version = version }
}

// Windows and detached tabs have independent processes. Settings Apply uses
// atomic replacement, so the inode also detects equal-size saves in the same
// second. Unchanged requests need only stat the file, without parsing JSON.
// Keep the last valid route if a replacement cannot yet be read or validated.
fn (mut state Runtime) refresh() {
	if state.path == '' { return }
	version := settings_file_version(state.path) or { return }
	if previous := state.file_version {
		if previous == version { return }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	proxy := json2.decode[Proxy](os.read_file(state.path) or { return }) or { return }
	normalized := proxy.normalized() or { return }
	state.proxy = normalized
	state.configured = true
	state.file_version = version
}

pub fn current() Proxy {
	mut state := unsafe { runtime }
	state.lock.lock()
	defer { state.lock.unlock() }
	state.refresh()
	return Proxy{ ...state.proxy, host: state.proxy.host.clone(), port: state.proxy.port.clone(), sites: state.proxy.sites.clone() }
}

// None preserves ambient proxies; an empty string explicitly selects direct
// connections. Readers snapshot under the lock while requests run on workers.
pub fn proxy_override(resource_url string) ?string {
	mut state := unsafe { runtime }
	state.lock.lock()
	defer { state.lock.unlock() }
	state.refresh()
	if !state.configured { return none }
	return state.proxy.url_for(resource_url)
}

pub fn save(input Proxy) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	proxy := input.normalized()!
	mut state := unsafe { runtime }
	state.lock.lock()
	defer { state.lock.unlock() }
	if state.path == '' { return error('Settings have not been initialized.') }
	os.mkdir_all(os.dir(state.path))!
	temporary := '${state.path}.tmp-${os.getpid()}'
	mut file := os.open_file(temporary, 'w', 0o600)!
	defer { os.rm(temporary) or {} }
	file.write_string(json2.encode(proxy)) or {
		file.close()
		return err
	}
	file.close()
	// Use the direct rename operation: os.rename treats a directory as a
	// destination container instead of failing to replace the settings file.
	os.rename_dir(temporary, state.path)!
	// Publish only after persistence succeeds. Failed Apply keeps the old route.
	state.proxy = Proxy{ ...proxy, host: proxy.host.clone(), port: proxy.port.clone(), sites: proxy.sites.clone() }
	state.configured = true
	// Read the persisted identity on the next access rather than caching a stat
	// that could belong to another process's save immediately after our rename.
	state.file_version = none
}
