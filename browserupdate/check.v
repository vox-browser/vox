module browserupdate

import net.http
import os
import semver
import time

pub const version_url = 'https://vox-browser.org/version'
pub const download_url = 'https://vox-browser.org'

// Embed the shared version source so installed copies never read the
// checkout, and every platform compares the same release version.
// Bump packaging/version.txt for releases and keep the macOS bundle
// version in packaging/Info.plist in sync with it.
pub fn current_version() string {
	return $embed_file('../packaging/version.txt').to_string().trim_space()
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

// A machine opts out of update checks with this file. It stays outside the
// profile: development machines launch Vox constantly with temporary profiles
// (VOX_PROFILE_DIR), and none of those launches should query /version.
pub fn opt_out_path() string {
	$if macos {
		return os.join_path(os.home_dir(), 'Library', 'Application Support', 'Vox', 'no-update-check')
	} $else {
		return os.join_path(os.user_config_dir() or { os.join_path(os.home_dir(), '.config') }, 'vox', 'no-update-check')
	}
}

pub fn disabled_on_this_machine() bool {
	return os.exists(opt_out_path())
}

// A buffered result lets the worker finish even if the browser closes first.
// Only the GUI thread consumes this result and creates UI2 controls.
pub fn check(results chan string) {
	if disabled_on_this_machine() {
		results <- ''
		return
	}
	results <- fetch_version(version_url, current_version())
}

// Opening must succeed before the old browser exits. Keeping this boundary
// injectable lets tests verify ordering without opening the user's browser.
pub fn open_download_and_quit(open fn (string) !, quit fn ()) ! {
	open(download_url)!
	quit()
}
