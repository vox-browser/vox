module browsersettings

import json2
import net.urllib
import os
import platform
import sync
import url

pub struct Proxy {
pub:
	enabled bool
	host    string = '127.0.0.1'
	port    string = '1080'
	// Empty selects every destination; otherwise comma-separated hostnames.
	sites string
	// Off by default; known-site paint comparison preserves normal navigation.
	experimental_fast_page_switch bool
}

@[heap]
struct Runtime {
mut:
	lock       sync.Mutex
	path       string
	proxy      Proxy
	configured bool
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
}

pub fn current() Proxy {
	mut state := unsafe { runtime }
	state.lock.lock()
	defer { state.lock.unlock() }
	return Proxy{ ...state.proxy, host: state.proxy.host.clone(), port: state.proxy.port.clone(), sites: state.proxy.sites.clone() }
}

// None preserves ambient proxies; an empty string explicitly selects direct
// connections. Readers snapshot under the lock while requests run on workers.
pub fn proxy_override(resource_url string) ?string {
	mut state := unsafe { runtime }
	state.lock.lock()
	defer { state.lock.unlock() }
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
}
