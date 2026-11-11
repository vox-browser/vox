@[has_globals]
module fetch

import dom
import http
import time

__global (
	preflight_options_requests int
	preflight_actual_requests  int
)

struct PreflightCacheTestClient {
	origin dom.Origin
	url    dom.URL
}

fn (client &PreflightCacheTestClient) fetch_request_client_api_base_url() dom.URL {
	return client.url
}

fn (_ &PreflightCacheTestClient) fetch_request_client_policy_container() RequestPolicyContainer {
	return RequestPolicyContainer{}
}

fn (_ &PreflightCacheTestClient) fetch_request_client_is_window() bool {
	return false
}

fn (_ &PreflightCacheTestClient) fetch_request_client_is_top_level_window() bool {
	return false
}

fn (client &PreflightCacheTestClient) fetch_request_client_origin() dom.Origin {
	return client.origin
}

fn (_ &PreflightCacheTestClient) fetch_request_client_document_url() ?dom.URL {
	return none
}

fn (client &PreflightCacheTestClient) fetch_request_client_creation_url() dom.URL {
	return client.url
}

fn (_ &PreflightCacheTestClient) fetch_request_client_embedder_policy_credentialless() bool {
	return false
}

fn (client &PreflightCacheTestClient) fetch_request_client_top_level_origin() ?dom.Origin {
	return client.origin
}

fn (client &PreflightCacheTestClient) fetch_request_client_top_level_creation_url() ?dom.URL {
	return client.url
}

fn (_ &PreflightCacheTestClient) fetch_request_client_cross_origin_isolated_capability() bool {
	return false
}

fn preflight_test_request() &Request {
	client := &PreflightCacheTestClient{
		origin: dom.Origin{ value: 'https://client.test' }
		url: dom.URL{value: 'https://client.test/page'}
	}
	mut request := Request.create()
	request.set_client(client)
	request.set_url(dom.URL{value: 'https://api.test/resource'})
	request.origin = RequestOrigin{
		is_client: false
		origin: client.origin
	}
	request.method = 'PATCH'
	request.cache_mode = .no_store
	request.header_list.append(http.Header{ name: 'X-Custom', value: 'value' })
	return request
}

fn preflight_cache_test_host(request &Request) !&Response {
	mut response := Response.create()
	response.status = 204
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Origin'
		value: 'https://client.test'
	})
	if request.method == 'OPTIONS' {
		preflight_options_requests++
		response.header_list.append(http.Header{
			name: 'Access-Control-Allow-Methods'
			value: 'PATCH'
		})
		response.header_list.append(http.Header{
			name: 'Access-Control-Allow-Headers'
			value: 'X-Custom'
		})
		response.header_list.append(http.Header{
			name: 'Access-Control-Max-Age'
			value: '600'
		})
	} else {
		preflight_actual_requests++
	}
	return response
}

fn malformed_preflight_cache_test_host(_ &Request) !&Response {
	mut response := Response.create()
	response.status = 204
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Origin'
		value: 'https://client.test'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Methods'
		value: 'not a method token'
	})
	return response
}

fn wildcard_preflight_cache_test_host(_ &Request) !&Response {
	mut response := Response.create()
	response.status = 204
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Origin'
		value: 'https://client.test'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Methods'
		value: 'PATCH'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Headers'
		value: '*'
	})
	return response
}

fn capped_preflight_cache_test_host(_ &Request) !&Response {
	mut response := Response.create()
	response.status = 204
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Origin'
		value: 'https://client.test'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Methods'
		value: 'PATCH'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Allow-Headers'
		value: 'X-Custom'
	})
	response.header_list.append(http.Header{
		name: 'Access-Control-Max-Age'
		value: '99999'
	})
	return response
}

fn failing_actual_preflight_cache_test_host(request &Request) !&Response {
	if request.method != 'OPTIONS' {
		return error('actual request failed')
	}
	return preflight_cache_test_host(request)
}

fn test_preflight_cache_matches_method_header_partition_origin_url_and_credentials() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	request := preflight_test_request()
	cache.cache_method(request, 'PATCH', 60 * time.second)
	cache.cache_header_name(request, 'X-Custom', 60 * time.second)
	assert cache.is_a_method_cache_entry_match(request, 'patch')
	assert cache.is_a_header_name_cache_entry_match(request, 'x-custom')

	mut different_url := request.clone()
	different_url.set_url(dom.URL{value: 'https://api.test/other'})
	assert !cache.is_a_method_cache_entry_match(different_url, 'PATCH')

	cache.cache_method(request, '*', 60 * time.second)
	cache.cache_header_name(request, '*', 60 * time.second)
	assert cache.is_a_method_cache_entry_match(request, 'DELETE')
	assert cache.is_a_header_name_cache_entry_match(request, 'X-Other')
	assert !cache.is_a_header_name_cache_entry_match(request, 'Authorization')

	mut credentialed := request.clone()
	credentialed.credentials_mode = .include
	assert !cache.is_a_method_cache_entry_match(credentialed, 'PATCH')
	assert !cache.is_a_header_name_cache_entry_match(credentialed, 'X-Custom')
	cache.clear_cache_entries(request)
	assert cache.entries.len == 0
}

// Ladybird 1846f0b2342946948551e9115f11d0957fb404cd: a cached wildcard
// has the same credentials restriction as a live preflight response.
fn test_cached_method_wildcard_does_not_authorize_credentialed_methods() {
	for mode in [CredentialsMode.omit, .same_origin, .include] {
		mut request := preflight_test_request()
		request.credentials_mode = mode
		mut cache := PreflightCache{}
		cache.cache_method(request, 'PUT', 60 * time.second)
		cache.cache_method(request, '*', 60 * time.second)
		assert cache.is_a_method_cache_entry_match(request, 'PUT')
		assert cache.is_a_method_cache_entry_match(request, 'DELETE') == (mode != .include)
		assert cache.is_a_method_cache_entry_match(request, '*')
	}
}

fn test_preflight_cache_rejects_expired_entries_and_refreshes_matches() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	request := preflight_test_request()
	cache.cache_method(request, 'PATCH', 0)
	assert cache.entries.len == 0
	cache.cache_method(request, 'PATCH', time.nanosecond)
	cache.evict_expired_entries()
	assert cache.entries.len == 0
	cache.cache_method(request, 'PATCH', time.second)
	assert cache.entries.len == 1
	old_stored_at := cache.entries[0].stored_at
	cache.cache_method(request, 'PATCH', 2 * time.second)
	assert cache.entries.len == 1
	assert cache.entries[0].max_age == 2 * time.second
	assert cache.entries[0].stored_at >= old_stored_at
}

fn test_http_fetch_reuses_successful_preflight_cache_entries() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	preflight_options_requests = 0
	preflight_actual_requests = 0
	request := preflight_test_request()
	host := FetchHost{ perform: preflight_cache_test_host }
	first := http_fetch(FetchParams.create(request, FetchTimingInfo.create()), host, true).response()?
	assert !first.is_network_error()
	second := http_fetch(FetchParams.create(request, FetchTimingInfo.create()), host, true).response()?
	assert !second.is_network_error()
	assert preflight_options_requests == 1
	assert preflight_actual_requests == 2
}

fn test_main_fetch_clears_preflight_cache_after_network_error() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	mut request := preflight_test_request()
	request.unsafe_request = true
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: failing_actual_preflight_cache_test_host
	}).response()?
	assert response.is_network_error()
	assert cache.entries.len == 0
}

fn test_cors_preflight_rejects_malformed_allow_lists_and_authorization_wildcard() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	mut request := preflight_test_request()
	malformed := cors_preflight_fetch(mut request, FetchHost{
		perform: malformed_preflight_cache_test_host
	}).response()?
	assert malformed.is_network_error()
	assert malformed.network_error_message?.contains('syntactically invalid')

	request.header_list = http.HeaderList.create()
	request.header_list.append(http.Header{ name: 'Authorization', value: 'secret' })
	wildcard := cors_preflight_fetch(mut request, FetchHost{
		perform: wildcard_preflight_cache_test_host
	}).response()?
	assert wildcard.is_network_error()
	assert wildcard.network_error_message?.contains('Authorization')
}

fn test_cors_preflight_caps_cache_max_age() {
	mut cache := PreflightCache.the()
	cache.entries.clear()
	mut request := preflight_test_request()
	response := cors_preflight_fetch(mut request, FetchHost{
		perform: capped_preflight_cache_test_host
	}).response()?
	assert !response.is_network_error()
	assert cache.entries.len == 2
	for entry in cache.entries {
		assert entry.max_age == preflight_cache_max_age_limit
	}
}
