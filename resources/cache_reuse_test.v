module main

import adblock
import dom
import fetch
import http
import os
import time

struct ResourceCacheReuseCase {
	name           string
	control        string = 'public, max-age=60, immutable'
	age            string
	date_age_ms    i64
	receipt_age_ms i64
	extra          []adblock.ResponseHeader
	reusable       bool
}

fn resource_cache_reuse_headers(control string, date_millis i64) []adblock.ResponseHeader {
	return [
		adblock.ResponseHeader{ name: 'Content-Type', value: 'text/javascript' },
		adblock.ResponseHeader{ name: 'Cache-Control', value: control },
		adblock.ResponseHeader{ name: 'Date', value: time.unix_milli(date_millis).http_header_string() },
	]
}

fn test_compact_and_fetch_disk_caches_apply_the_same_freshness_decisions() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-cache-reuse-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	for test in [
		ResourceCacheReuseCase{ name: 'fresh', age: '5', date_age_ms: 1000, receipt_age_ms: 1000, reusable: true },
		// Date and Age describe the same prior residence. Adding both would
		// incorrectly reject this fresh response in the script/Fetch adapter.
		ResourceCacheReuseCase{ name: 'age-not-double-counted', age: '50', date_age_ms: 50000, reusable: true },
		ResourceCacheReuseCase{ name: 'expired-date', date_age_ms: 120000 },
		ResourceCacheReuseCase{ name: 'expired-residence', receipt_age_ms: 120000 },
		ResourceCacheReuseCase{ name: 'expired-age', age: '60' },
		ResourceCacheReuseCase{ name: 'negative-age', age: '-1' },
		ResourceCacheReuseCase{ name: 'invalid-age', age: 'invalid' },
		ResourceCacheReuseCase{ name: 'no-cache', control: 'public, max-age=60, immutable, no-cache' },
		ResourceCacheReuseCase{ name: 'no-store', control: 'public, max-age=60, immutable, no-store' },
		ResourceCacheReuseCase{ name: 'zero-lifetime', control: 'public, max-age=0, immutable' },
		ResourceCacheReuseCase{ name: 'private', control: 'private, max-age=60, immutable' },
		ResourceCacheReuseCase{ name: 'cookie-response', extra: [adblock.ResponseHeader{ name: 'Set-Cookie', value: 'session=value' }] },
	] {
		address := 'https://resource-policy.example/${test.name}.js'
		now := time.now().unix_milli()
		mut headers := resource_cache_reuse_headers(test.control, now - test.date_age_ms)
		if test.age != '' { headers << adblock.ResponseHeader{ name: 'Age', value: test.age } }
		headers << test.extra
		received := now - test.receipt_age_ms
		cache_resource_response_headers_with_timing(address, address, 'cached response', headers,
			200, received, received)
		// The previous document's in-memory resources are candidates for a new
		// navigation, so they must pass the same gate as a disk cache entry.
		retained := PreloadedResource{
			url:              address
			final_url:        address
			source_url:       address
			request_type:     'script'
			body:             'cached response'
			response_headers: headers
			status_code:      200
			request_time:     received
			response_time:    received
		}
		assert reusable_browser_resource(retained, 'image') == test.reusable, test.name
		assert reusable_browser_resource(retained, 'script') == test.reusable, test.name
		mut request := fetch.Request.create()
		request.set_url(dom.URL{ value: address })
		request.credentials_mode = .omit
		// A normal Fetch request and an initial image load share the unvaried
		// response identity. Script requests use the same freshness calculation.
		assert (disk_cached_browser_resource(address, address, 'image') != none) == test.reusable, test.name
		assert (browser_cached_script_response(request) != none) == test.reusable, test.name
		request.destination = .script
		assert (disk_cached_browser_resource(address, address, 'script') != none) == test.reusable, test.name
		assert (browser_cached_script_response(request) != none) == test.reusable, test.name
		if test.reusable {
			assert disk_cached_browser_resource(address, address, 'script')?.body == 'cached response'
			assert browser_cached_script_response(request)?.body?.bytes().bytestr() == 'cached response'
		}
		request.destination = .font
		assert (browser_cached_font_response(request) != none) == test.reusable, test.name
	}
}

fn test_both_disk_consumers_reject_missing_or_invalid_receipt_and_status_provenance() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-cache-provenance-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	address := 'https://resource-policy.example/legacy.js'
	headers := resource_cache_reuse_headers('public, max-age=60, immutable', time.now().unix_milli())
	path := browser_cache_entry_path(cache, 'resources', address)
	mut request := fetch.Request.create()
	request.set_url(dom.URL{ value: address })
	request.destination = .script
	cache_resource_response_headers_with_status(address, address, 'legacy response', headers, 200)
	assert disk_cached_browser_resource(address, address, 'script') != none
	assert browser_cached_script_response(request) != none
	os.rm(path + '.timing.json')!
	assert disk_cached_browser_resource(address, address, 'script') == none
	assert browser_cached_script_response(request) == none
	assert try_write_browser_cache_metadata(path + '.timing.json', '{}')
	assert disk_cached_browser_resource(address, address, 'script') == none
	assert browser_cached_script_response(request) == none
	cache_resource_response_headers_with_status(address, address, 'unproven response', headers, 0)
	assert disk_cached_browser_resource(address, address, 'script') == none
	assert browser_cached_script_response(request) == none
	// Concurrent writers can expose a body or header sidecar from a different
	// response. A reader must reject the combination even when it looks fresh.
	cache_resource_response_headers_with_status(address, address, 'original response', headers, 200)
	assert try_write_browser_cache_entry(path, 'another response')
	assert disk_cached_browser_resource(address, address, 'script') == none
	assert browser_cached_script_response(request) == none
	cache_resource_response_headers_with_status(address, address, 'original response', headers, 200)
	encoded := os.read_file(path + '.headers.json')!
	assert try_write_browser_cache_metadata(path + '.headers.json', encoded.replace('text/javascript', 'application/javascript'))
	assert disk_cached_browser_resource(address, address, 'script') == none
	assert browser_cached_script_response(request) == none
}

fn test_disk_consumers_reuse_only_the_vary_fields_recorded_in_the_cache_identity() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-cache-vary-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	address := 'https://resource-policy.example/negotiated.js'
	key := resource_accept_cache_key(address, 'script')
	mut headers := resource_cache_reuse_headers('public, max-age=60, immutable', time.now().unix_milli())
	headers << adblock.ResponseHeader{ name: 'Vary', value: 'Origin, Accept' }
	mut request := fetch.Request.create()
	request.set_url(dom.URL{ value: address })
	request.destination = .script
	// Even an Accept-specific key has no record of the selecting Origin.
	for stored_key in [key, address] {
		cache_resource_response_headers_with_status(stored_key, address, 'wrong origin', headers, 200)
	}
	assert disk_cached_browser_resource(address, address, 'script') == none
	assert browser_cached_script_response(request) == none
	headers[headers.len - 1] = adblock.ResponseHeader{ name: 'Vary', value: 'Accept' }
	cache_resource_response_headers_with_status(key, address, 'correct accept', headers, 200)
	assert disk_cached_browser_resource(address, address, 'script')?.body == 'correct accept'
	assert browser_cached_script_response(request)?.body?.bytes().bytestr() == 'correct accept'
	// Native script/font callers can select another Accept value. Their keys
	// must describe that actual header, rather than a destination's default.
	request.header_list.append(http.Header{ name: 'Accept', value: 'application/octet-stream' })
	assert browser_cached_script_response(request) == none
	request.destination = .font
	assert browser_cached_font_response(request) == none
	selected := resource_accept_cache_key_for_header(address, 'application/octet-stream')
	cache_resource_response_headers_with_status(selected, address, 'selected accept', headers, 200)
	assert browser_cached_font_response(request)?.body?.bytes().bytestr() == 'selected accept'
	request.destination = .script
	assert browser_cached_script_response(request)?.body?.bytes().bytestr() == 'selected accept'
}
