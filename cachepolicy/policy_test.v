module cachepolicy

import time

fn cache_test_stamp() i64 {
	stamp := time.parse_rfc2616('Sun, 08 Nov 2026 12:00:00 GMT') or { panic(err) }
	return stamp.unix_milli()
}

fn public_response(control string, extra []Header) Response {
	stamp := cache_test_stamp()
	mut headers := [Header{ name: 'Cache-Control', value: control },
		Header{ name: 'Date', value: 'Sun, 08 Nov 2026 12:00:00 GMT' }]
	headers << extra
	return Response{
		headers: headers
		timing:  Timing{ request_time: stamp, response_time: stamp }
	}
}

fn test_memory_and_disk_share_freshness_and_expiry_boundary() {
	response := public_response('public, max-age=60, immutable', []Header{})
	for storage in [Storage.memory, .disk] {
		options := ReuseOptions{ storage: storage, require_immutable: true }
		fresh := evaluate(Request{}, response, options, cache_test_stamp() + 59_999)
		assert fresh.kind == .fresh
		assert fresh.current_age == 59_999
		assert fresh.freshness_lifetime == 60_000
		assert !evaluate(Request{}, response, options, cache_test_stamp() + 60_000).can_reuse()
		assert !evaluate(Request{}, response, options, cache_test_stamp() + 60_001).can_reuse()
	}
}

fn test_age_counts_network_delay_and_residence_without_adding_apparent_age_twice() {
	response := public_response('public, max-age=60', [Header{ name: 'Age', value: '30' }])
	timed := Response{
		...response
		timing: Timing{ request_time: cache_test_stamp() + 18_000, response_time: cache_test_stamp() + 20_000 }
	}
	for storage in [Storage.memory, .disk] {
		options := ReuseOptions{ storage: storage }
		decision := evaluate(Request{}, timed, options, cache_test_stamp() + 30_000)
		// max(apparent age 20s, Age 30s + response delay 2s) + residence 10s.
		assert decision.current_age == 42_000
		assert decision.can_reuse()
		assert !evaluate(Request{}, timed, options, cache_test_stamp() + 48_000).can_reuse()
	}
}

fn test_no_cache_and_no_store_never_replay_without_a_network_check() {
	for response_control in ['public, max-age=60, no-cache', 'public, max-age=60, no-store',
		'public, max-age=60, private="field,other", No-Store'] {
		response := public_response(response_control, []Header{})
		for mode in [Mode.default, .force_cache, .only_if_cached] {
			for storage in [Storage.memory, .disk] {
				assert !evaluate(Request{ mode: mode }, response, ReuseOptions{ storage: storage }, cache_test_stamp()).can_reuse()
			}
		}
	}
	response := public_response('public, max-age=60', []Header{})
	for control in ['no-cache', 'no-store', 'max-age=0', 'min-fresh=60'] {
		request := Request{ headers: [Header{ name: 'Cache-Control', value: control }] }
		for storage in [Storage.memory, .disk] {
			assert !evaluate(request, response, ReuseOptions{ storage: storage }, cache_test_stamp()).can_reuse()
		}
	}
	assert !evaluate(Request{ headers: [Header{ name: 'Pragma', value: 'no-cache' }] }, response,
		ReuseOptions{}, cache_test_stamp()).can_reuse()
	assert !forbids_storage([Header{ name: 'Cache-Control', value: 'extension="no-store, no-cache", max-age=60' }])
	assert forbids_storage([Header{ name: 'Cache-Control', value: 'extension="a, b"' },
		Header{ name: 'cache-control', value: 'NO-STORE' }])
}

fn test_explicit_cache_modes_and_mandatory_revalidation() {
	fresh := public_response('public, max-age=60', []Header{})
	for mode in [Mode.no_store, .reload, .no_cache] {
		assert !evaluate(Request{ mode: mode }, fresh, ReuseOptions{}, cache_test_stamp()).can_reuse()
	}
	for mode in [Mode.force_cache, .only_if_cached] {
		assert evaluate(Request{ mode: mode }, fresh, ReuseOptions{}, cache_test_stamp() + 60_000).kind == .stale
		// The persistent adapter cannot implement these modes independently
		// of the translated cache's request pipeline.
		assert !evaluate(Request{ mode: mode }, fresh, ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
		must_validate := public_response('public, max-age=60, must-revalidate', []Header{})
		assert !evaluate(Request{ mode: mode }, must_validate, ReuseOptions{}, cache_test_stamp() + 60_000).can_reuse()
	}
	request := Request{ headers: [Header{ name: 'Cache-Control', value: 'max-stale=10' }] }
	assert evaluate(request, fresh, ReuseOptions{}, cache_test_stamp() + 70_000).kind == .stale
	assert !evaluate(request, fresh, ReuseOptions{}, cache_test_stamp() + 70_001).can_reuse()
}

fn test_malformed_duplicated_and_overflowing_metadata_is_a_miss() {
	for control in ['public, max-age=-1', 'public, max-age=+60', 'public, max-age=NaN',
		'public, max-age=60, max-age=60', 'public, max-age=9223372036854775807', 'public, max-age="60',
		'public, max-age'] {
		response := public_response(control, []Header{})
		for storage in [Storage.memory, .disk] {
			assert !evaluate(Request{}, response, ReuseOptions{ storage: storage }, cache_test_stamp()).can_reuse()
		}
	}
	for age in ['-1', '+1', 'NaN', '9223372036854775807', '1, 1', '"1"'] {
		response := public_response('public, max-age=60', [Header{ name: 'Age', value: age }])
		assert !evaluate(Request{}, response, ReuseOptions{}, cache_test_stamp()).can_reuse()
	}
	quoted := public_response('public, max-age="60"', []Header{})
	assert evaluate(Request{}, quoted, ReuseOptions{}, cache_test_stamp()).can_reuse()
	untimed := Response{ headers: quoted.headers }
	assert !evaluate(Request{}, untimed, ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
	for timing in [
		Timing{ request_time: cache_test_stamp() + 1, response_time: cache_test_stamp() },
		Timing{ request_time: cache_test_stamp(), response_time: cache_test_stamp() + 1 },
	] {
		assert !evaluate(Request{}, Response{ ...quoted, timing: timing }, ReuseOptions{}, cache_test_stamp()).can_reuse()
	}
}

fn test_disk_identity_profile_keeps_credential_and_variant_limits() {
	fresh := public_response('public, max-age=60, immutable', []Header{})
	for name in ['Cookie', 'Authorization', 'Range'] {
		request := Request{ headers: [Header{ name: name, value: 'present' }] }
		assert !evaluate(request, fresh, ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
	}
	for extra in [Header{ name: 'Set-Cookie', value: 'session=1' }, Header{ name: 'Vary', value: '*' },
		Header{ name: 'Vary', value: 'Origin' }, Header{ name: 'Vary', value: 'Cookie' }] {
		response := public_response('public, max-age=60, immutable', [extra])
		assert !evaluate(Request{}, response, ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
	}
	for control in ['max-age=60', 'private, max-age=60', 'public, private, max-age=60'] {
		assert !evaluate(Request{}, public_response(control, []Header{}), ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
	}
	assert !evaluate(Request{}, public_response('public, max-age=60', []Header{}),
		ReuseOptions{ storage: .disk, require_immutable: true }, cache_test_stamp()).can_reuse()
	assert evaluate(Request{}, public_response('public, max-age=60', [Header{ name: 'Vary', value: 'Accept, Accept-Encoding' }]),
		ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
	assert !evaluate(Request{}, Response{ ...fresh, status: 404 }, ReuseOptions{ storage: .disk }, cache_test_stamp()).can_reuse()
}

fn test_expires_and_receipt_time_do_not_gain_lifetime_when_read_again() {
	response := public_response('public', [Header{ name: 'Expires', value: 'Sun, 08 Nov 2026 12:01:00 GMT' }])
	for storage in [Storage.memory, .disk] {
		assert evaluate(Request{}, response, ReuseOptions{ storage: storage }, cache_test_stamp() + 59_000).can_reuse()
		assert !evaluate(Request{}, response, ReuseOptions{ storage: storage }, cache_test_stamp() + 60_000).can_reuse()
	}
	without_date := Response{
		headers: [Header{ name: 'Cache-Control', value: 'public, max-age=60' },
			Header{ name: 'Age', value: '40' }]
		timing:  Timing{ request_time: cache_test_stamp(), response_time: cache_test_stamp() }
	}
	assert evaluate(Request{}, without_date, ReuseOptions{ storage: .disk }, cache_test_stamp() + 19_999).can_reuse()
	assert !evaluate(Request{}, without_date, ReuseOptions{ storage: .disk }, cache_test_stamp() + 20_000).can_reuse()
}

fn test_cache_hit_age_survives_promotion_to_another_cache() {
	stamp := cache_test_stamp()
	original := Response{
		headers: [Header{ name: 'Cache-Control', value: 'public, max-age=60' },
			Header{ name: 'Age', value: '40' }]
		timing:  Timing{ request_time: stamp, response_time: stamp }
	}
	decision := evaluate(Request{}, original, ReuseOptions{ storage: .disk }, stamp + 19_001)
	assert decision.can_reuse()
	assert decision.current_age == 59_001
	assert decision.age_header_value() == '60'
	promoted := Response{
		headers: [Header{ name: 'Cache-Control', value: 'public, max-age=60' },
			Header{ name: 'Age', value: decision.age_header_value() }]
		timing:  Timing{ request_time: stamp + 19_001, response_time: stamp + 19_001 }
	}
	assert !evaluate(Request{}, promoted, ReuseOptions{}, stamp + 20_000).can_reuse()
}
