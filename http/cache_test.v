module http

fn cache_headers(values []Header) &HeaderList {
	mut headers := HeaderList.create()
	for header in values {
		headers.append(header)
	}
	return headers
}

fn test_cache_control_directives_and_cacheability_match_libhttp() {
	value := 'private="field,other", max-age=60, stale-while-revalidate=30'
	assert extract_cache_control_directive(value, 'private')? == '"field,other"'
	assert extract_cache_control_duration_directive(value, 'max-age', none)? == 60_000
	assert extract_cache_control_duration_directive('max-stale', 'max-stale', 123)? == 123

	request_headers := cache_headers([]Header{})
	assert is_cacheable_request('GET', request_headers)
	assert !is_cacheable_request('POST', request_headers)
	assert !is_cacheable_request('GET', cache_headers([
		Header{ name: 'Cache-Control', value: 'no-store' },
	]))
	assert is_cacheable_response(200, cache_headers([]Header{}))
	assert !is_cacheable_response(206, cache_headers([]Header{}))
	assert !is_cacheable_response(200, cache_headers([
		Header{ name: 'Vary', value: '*' },
	]))
}

fn test_vary_key_and_cache_lifetime_match_libhttp() {
	response_headers := cache_headers([
		Header{ name: 'Vary', value: 'Accept-Language' },
		Header{ name: 'Cache-Control', value: 'max-age=60' },
	])
	first := cache_headers([
		Header{ name: 'Accept-Language', value: 'EN, fr' },
	])
	second := cache_headers([
		Header{ name: 'Accept-Language', value: 'fr,en' },
	])
	third := cache_headers([
		Header{ name: 'Accept-Language', value: 'de' },
	])
	assert create_vary_key(first, response_headers)? == create_vary_key(second, response_headers)?
	assert create_vary_key(first, response_headers)? != create_vary_key(third, response_headers)?
	assert calculate_freshness_lifetime(200, response_headers) == 60_000
	assert cache_lifetime_status(first, response_headers, 60_000, 1_000) == .fresh

	revalidation_headers := cache_headers([
		Header{ name: 'Cache-Control', value: 'no-cache' },
		Header{ name: 'ETag', value: '"version"' },
	])
	assert cache_lifetime_status(first, revalidation_headers, 60_000, 1_000) == .must_revalidate
}

fn test_vary_keys_distinguish_missing_empty_and_quoted_values() {
	response := cache_headers([Header{ name: 'Vary', value: 'Accept, X-Variant' }])
	reordered := cache_headers([Header{ name: 'Vary', value: 'x-variant, ACCEPT, accept' }])
	missing := cache_headers([Header{ name: 'Accept', value: 'text/html;profile="CaseSensitive"' }])
	present := cache_headers([
		Header{ name: 'Accept', value: 'text/html;profile="CaseSensitive"' },
		Header{ name: 'X-Variant', value: '' },
	])
	lowercase := cache_headers([Header{ name: 'Accept', value: 'text/html;profile="casesensitive"' }])
	assert create_vary_key(missing, response)? == create_vary_key(missing, reordered)?
	assert create_vary_key(missing, response)? != create_vary_key(present, response)?
	assert create_vary_key(missing, response)? != create_vary_key(lowercase, response)?
}

fn test_vary_keys_reject_unsupported_and_excessive_selectors() {
	request := cache_headers([]Header{})
	mut names := []string{}
	for index in 0 .. 32 { names << 'X-Variant-${index}' }
	assert create_vary_key(request, cache_headers([Header{ name: 'Vary', value: names.join(',') }])) != none
	names << 'X-Variant-32'
	for value in ['*', 'Cookie', names.join(',')] {
		response := cache_headers([Header{ name: 'Vary', value: value }])
		assert create_vary_key(request, response) == none
		assert !is_cacheable_response(200, response)
	}
}
