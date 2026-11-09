module main

import adblock
import crypto.sha256
import os
import time

fn test_query_responses_reject_legacy_transport_cache_and_reuse_new_entries() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-query-cache-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://fonts.example/css2?family=Fixture:wght@400;500&family=Mono:wght@400;500'
	legacy := os.join_path(cache, 'resources', sha256.hexhash(address))
	os.mkdir_all(os.dir(legacy))!
	os.write_file(legacy, 'regular weights only')!
	os.write_file(legacy + '.url', address)!
	os.write_file(legacy + '.headers.json', '[]')!
	_ := cached_browser_resource_response(address, address, 'https://owner.example/', 'stylesheet') or {
		assert err.code() == browser_cache_miss_code
		PreloadedResource{}
	}
	assert read_cached_resource(address) == none
	cache_resource_response_headers_with_status(address, address, 'all requested weights', [
		adblock.ResponseHeader{ name: 'Cache-Control', value: 'public, max-age=60' },
		adblock.ResponseHeader{ name: 'Date', value: time.utc().http_header_string() },
	], 200)
	loaded := cached_browser_resource_response(address, address, 'https://owner.example/', 'stylesheet')!
	assert loaded.body == 'all requested weights'
	assert os.read_file(legacy)! == 'regular weights only'

	plain := 'https://fonts.example/regular.woff2'
	old_plain := os.join_path(cache, 'resources', sha256.hexhash(plain))
	os.write_file(old_plain, 'query-free font')!
	assert read_cached_resource(plain)? == 'query-free font'
}
