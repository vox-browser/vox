module main

import os
import time
import x.json2

fn adblock_filter_reuse_phases(log_path string) map[string]int {
	mut phases := map[string]int{}
	for line in os.read_lines(log_path) or { []string{} } {
		record := json2.decode[map[string]json2.Any](line) or { continue }
		phase := (record['phase'] or { json2.Any('request') }).str()
		phases[phase] = phases[phase] + 1
	}
	return phases
}

// A retained response without a redirect has the request's own URL as its
// final URL. Filtering it checks that request once, not once more as the
// final URL, and reading its bytes does not repeat the request check either.
fn test_retained_resources_without_redirects_check_their_request_once() {
	stamp := '${os.getpid()}-${time.sys_mono_now()}'
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	previous_log := os.getenv('VOX_ADBLOCK_LOG')
	cache := os.join_path(os.temp_dir(), 'vox-filter-reuse-${stamp}')
	log_path := os.join_path(os.temp_dir(), 'vox-filter-reuse-${stamp}.jsonl')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.setenv('VOX_ADBLOCK_LOG', previous_log, true)
		os.rmdir_all(cache) or {}
		os.rm(log_path) or {}
	}
	resource_url := 'https://filter-reuse.example.test/i/thumb.png'
	source_url := 'https://filter-reuse.example.test/catalog'
	cache_resource(resource_url, 'thumbnail bytes')
	os.setenv('VOX_ADBLOCK_LOG', log_path, true)
	cached := disk_cached_browser_resource(resource_url, source_url, 'image') or {
		panic('missing disk-cached resource')
	}
	assert cached.body == 'thumbnail bytes'
	assert adblock_filter_reuse_phases(log_path) == {
		'request':  1
		'response': 1
	}
	mut app := BrowserApp{
		address:        source_url
		resource_cache: {
			resource_url: cached
		}
	}
	assert app.background_image_bytes(resource_url)!.bytestr() == 'thumbnail bytes'
	assert adblock_filter_reuse_phases(log_path) == {
		'request':  2
		'response': 2
	}
}
