module cachepolicy

import os
import time

const disk_test_limit = 1024 * 1024

fn test_malformed_or_unmeasured_disk_receipt_cannot_gain_freshness() {
	path := disk_test_path('receipt')
	defer { os.rmdir_all(os.dir(path)) or {} }
	response := disk_test_response('body')
	for encoded in ['{', '{}', '[]', '{"version":"2"}',
		'{"version":"1","request_time":0,"response_time":0,"integrity":"invalid"}',
		'{"version":"1","request_time":"overflow","response_time":"1","integrity":"invalid"}'] {
		assert store_disk_response(path, 'https://cache.example/a', 'body', response, disk_test_limit)
		os.write_file(path + '.timing.json', encoded)!
		assert read_disk_entry(path, disk_test_limit) == none
	}
	assert !store_disk_response(path, 'https://cache.example/a', 'body', Response{ headers: response.headers }, disk_test_limit)
	assert read_disk_entry(path, disk_test_limit) == none
}

fn write_disk_race(path string, worker int) {
	for sequence in 0 .. 12 {
		label := '${worker}-${sequence}'
		_ = store_disk_response(path, 'https://cache.example/${label}', label,
			disk_test_response(label), disk_test_limit)
		if entry := read_disk_entry(path, disk_test_limit) {
			assert entry.final_url == 'https://cache.example/${entry.body}'
			assert entry.response.headers[2].value == entry.body
		}
	}
}

fn test_overlapping_disk_writers_publish_only_consistent_responses() {
	path := disk_test_path('concurrent')
	defer { os.rmdir_all(os.dir(path)) or {} }
	mut workers := []thread{}
	for worker in 0 .. 6 { workers << spawn write_disk_race(path, worker) }
	workers.wait()
	assert store_disk_response(path, 'https://cache.example/final', 'final', disk_test_response('final'), disk_test_limit)
	entry := read_disk_entry(path, disk_test_limit) or { panic('final entry') }
	assert entry.body == 'final'
}

fn test_disk_cache_rejects_legacy_missing_or_mixed_response_parts() {
	path := disk_test_path('mixed')
	defer { os.rmdir_all(os.dir(path)) or {} }
	response := disk_test_response('original')
	assert store_disk_response(path, 'https://cache.example/a', 'original', response, disk_test_limit)
	os.rm(path + '.timing.json')!
	assert read_disk_entry(path, disk_test_limit) == none
	for change in [
		['', 'different body'],
		['.url', 'https://other.example/redirect'],
		['.status', '201'],
		['.headers.json', '[{"name":"Cache-Control","value":"public, max-age=600"}]'],
	] {
		assert store_disk_response(path, 'https://cache.example/a', 'original', response, disk_test_limit)
		os.write_file(path + change[0], change[1])!
		assert read_disk_entry(path, disk_test_limit) == none
	}
}

fn test_no_store_and_failed_replacements_retire_previous_entry() {
	path := disk_test_path('replace')
	defer { os.rmdir_all(os.dir(path)) or {} }
	response := disk_test_response('old')
	assert store_disk_response(path, 'https://cache.example/a', 'old', response, disk_test_limit)
	no_store := Response{ ...response, headers: [Header{ name: 'Cache-Control', value: 'no-store' }] }
	assert !store_disk_response(path, 'https://cache.example/a', 'private', no_store, disk_test_limit)
	assert read_disk_entry(path, disk_test_limit) == none
	assert !os.exists(path)
	assert !os.exists(path + '.timing.json')
	assert store_disk_response(path, 'https://cache.example/a', 'old', response, disk_test_limit)
	assert !store_disk_response(path, 'https://cache.example/a', 'new body that exceeds limit', response, 4)
	assert read_disk_entry(path, disk_test_limit) == none
}

fn disk_test_path(name string) string {
	return os.join_path(os.temp_dir(), 'vox-cache-policy-${name}-${os.getpid()}-${time.sys_mono_now()}', 'entry')
}

fn disk_test_response(label string) Response {
	stamp := time.parse_rfc2616('Sun, 08 Nov 2026 12:00:00 GMT') or { panic(err) }
	return Response{
		headers: [
			Header{ name: 'Cache-Control', value: 'public, max-age=60, immutable' },
			Header{ name: 'Date', value: 'Sun, 08 Nov 2026 12:00:00 GMT' },
			Header{ name: 'X-Response-Identity', value: label },
		]
		timing:  Timing{ request_time: stamp.unix_milli() - 100, response_time: stamp.unix_milli() }
	}
}

fn test_disk_snapshot_preserves_bytes_timing_and_accumulated_age() {
	path := disk_test_path('roundtrip')
	defer { os.rmdir_all(os.dir(path)) or {} }
	body := [u8(0), 0xff, 0x80, 0x0a, 0x41].bytestr()
	response := disk_test_response('binary')
	assert store_disk_response(path, 'https://cache.example/image', body, response, disk_test_limit)
	entry := read_disk_entry(path, disk_test_limit) or { panic('verified entry') }
	assert entry.body.bytes() == body.bytes()
	assert entry.final_url == 'https://cache.example/image'
	assert entry.response.headers == response.headers
	assert entry.response.timing? == response.timing?
	timing := response.timing?
	for elapsed in [i64(0), 20_000, 59_899] {
		read_again := read_disk_entry(path, disk_test_limit) or { panic('repeat read') }
		decision := evaluate(Request{}, read_again.response, ReuseOptions{ storage: .disk }, timing.response_time + elapsed)
		assert decision.current_age == 100 + elapsed
		assert decision.can_reuse()
	}
	assert !evaluate(Request{}, entry.response, ReuseOptions{ storage: .disk }, timing.response_time + 59_900).can_reuse()
}

fn test_disk_receipt_preserves_version_one_json_string_schema() {
	path := disk_test_path('schema')
	defer { os.rmdir_all(os.dir(path)) or {} }
	response := disk_test_response('schema')
	timing := response.timing?
	url := 'https://cache.example/schema'
	for sequence in 0 .. 4 {
		body := 'body-${sequence}'
		assert store_disk_response(path, url, body, response, disk_test_limit)
		encoded_headers := os.read_file(path + '.headers.json')!
		integrity := disk_integrity(url, '200', encoded_headers, body)
		// Existing map receipts sort these keys and encode timestamps as decimal
		// strings. Preserve the complete record, including repeated replacements.
		expected := '{"integrity":"${integrity}","request_time":"${timing.request_time}","response_time":"${timing.response_time}","version":"1"}'
		assert os.read_file(path + '.timing.json')! == expected
		entry := read_disk_entry(path, disk_test_limit) or { panic('version-one receipt') }
		assert entry.body == body
		assert entry.response.timing? == timing
	}
}
