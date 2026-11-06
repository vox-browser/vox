module browserupdate

import net.http
import semver
import time

pub const version_url = 'https://vox-browser.org/version'
pub const download_url = 'https://vox-browser.org'

// Embed the packaging source so installed copies never read the checkout, and
// macOS and Linux compare the same release version. Bump this plist for releases.
pub fn current_version() string {
	info := $embed_file('../packaging/Info.plist').to_string()
	return info.all_after('<key>CFBundleShortVersionString</key>').all_after('<string>').all_before('</string>').trim_space()
}

fn parse_version(raw string) !semver.Version {
	value := raw.trim_space().trim_string_left('v')
	if value.len == 0 || value.len > 128 { return error('Invalid release version') }
	core := value.all_before('+').all_before('-')
	parts := core.split('.')
	if parts.len < 1 || parts.len > 3 { return error('Invalid release version') }
	for part in parts {
		if part.len == 0 || part.len > 9 || !part.bytes().all(it >= `0` && it <= `9`) {
			return error('Invalid release version')
		}
	}
	mut normalized := core
	for _ in parts.len .. 3 { normalized += '.0' }
	return semver.from(normalized + value[core.len..])
}

pub fn is_newer(current string, latest string) bool {
	installed := parse_version(current) or { return false }
	available := parse_version(latest) or { return false }
	return installed < available
}

fn fetch_version(endpoint string, current string) string {
	response := http.fetch(
		url:                      endpoint
		header:                   http.new_header_from_map({
			.accept:        'text/plain'
			.cache_control: 'no-cache'
		})
		user_agent:               'Vox/${current}'
		validate:                 true
		allow_redirect:           false
		// V counts attempts here, so one means a single request with no retry.
		max_retries:              1
		disable_connection_reuse: true
		read_timeout:             5 * time.second
		write_timeout:            5 * time.second
		stop_copying_limit:       1024
		stop_receiving_limit:     4096
	) or { return '' }
	if response.status_code != 200 || response.body.len > 128 { return '' }
	latest := response.body.trim_space()
	return if is_newer(current, latest) { latest } else { '' }
}

// A buffered result lets the worker finish even if the browser closes first.
// Only the GUI thread consumes this result and creates UI2 controls.
pub fn check(results chan string) {
	results <- fetch_version(version_url, current_version())
}

// Opening must succeed before the old browser exits. Keeping this boundary
// injectable lets tests verify ordering without opening the user's browser.
pub fn open_download_and_quit(open fn (string) !, quit fn ()) ! {
	open(download_url)!
	quit()
}
