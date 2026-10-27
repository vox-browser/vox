module fetch

import dom
import http

struct RequestServerActionLog {
mut:
	releases      int
	resumes       int
	resumed_up_to []uint
	stops         int
}

fn test_response_defaults() {
	response := Response.create()
	assert response.response_type == .default
	assert response.status == u16(200)
	assert response.status_message == ''
	assert response.request_includes_credentials == true
	assert response.redirect_taint == .same_origin
	assert response.aborted == false
	assert response.is_network_error() == false
	assert response.is_aborted_network_error() == false
}

fn test_network_error() {
	response := Response.network_error('boom')
	assert response.response_type == .error
	assert response.status == u16(0)
	assert response.network_error_message? == 'boom'
	assert response.is_network_error() == true
	assert response.is_aborted_network_error() == false
}

fn test_aborted_network_error() {
	response := Response.aborted_network_error()
	assert response.aborted == true
	assert response.is_aborted_network_error() == true
	// An aborted network error is still a network error.
	assert response.is_network_error() == true
}

fn test_is_network_error_requires_all_conditions() {
	// A default 200 response is not a network error.
	assert Response.create().is_network_error() == false
	// An error response with a non-empty status message is not a network error.
	mut r := Response.network_error('x')
	r.status_message = 'Not Found'
	assert r.is_network_error() == false
	// An error response with a body is not a network error.
	mut r2 := Response.network_error('x')
	r2.set_body_bytes('data'.bytes())
	assert r2.is_network_error() == false
}

fn test_response_url() {
	mut response := Response.create()
	assert response.url() == none
	response.url_list << dom.URL{
		value: 'https://a/1'
	}
	response.url_list << dom.URL{
		value: 'https://a/2'
	}
	// A response's URL is the last URL in its URL list.
	assert response.url()?.value == 'https://a/2'
}

fn test_response_location_url_clone_and_cors_classification() {
	mut response := Response.create()
	response.status = 302
	response.url_list = [dom.URL{value: 'https://example.test/base'}]
	response.header_list.append(http.Header{ name: 'Location', value: '/next' })
	response.redirect_taint = .cross_site
	response.set_javascript_bytecode_cache([u8(1), 2, 3])
	response.set_javascript_bytecode_cache_vary_key(u64(41))
	mut request_headers := http.HeaderList.create()
	request_headers.append(http.Header{ name: 'Accept', value: 'text/javascript' })
	response.set_javascript_bytecode_cache_memory_cache_request_headers(request_headers)
	response.method = 'POST'
	response.network_error_message = 'outer-only metadata'
	assert response.location_url('frag')!.url?.serialize() == 'https://example.test/next#frag'
	clone := response.clone()
	assert clone != response
	assert clone.header_list.get('Location')? == '/next'
	assert clone.redirect_taint == .cross_site
	assert clone.javascript_bytecode_cache()? == [u8(1), 2, 3]
	assert clone.javascript_bytecode_cache_vary_key()? == u64(41)
	assert clone.javascript_bytecode_cache_memory_cache_request_headers()?.get('Accept')? == 'text/javascript'
	assert clone.method == ''
	assert clone.network_error_message == none
	assert response.is_cors_same_origin()
	assert !response.is_cors_cross_origin()
}

fn test_filtered_responses_hide_headers_and_unsafe_response() {
	mut internal := Response.create()
	internal.header_list.append(http.Header{ name: 'Content-Type', value: 'text/plain' })
	internal.header_list.append(http.Header{ name: 'Set-Cookie', value: 'a=1' })
	internal.header_list.append(http.Header{ name: 'X-Visible', value: 'yes' })
	internal.cors_exposed_header_name_list = ['x-visible']
	internal.redirect_taint = .cross_site
	internal.method = 'POST'
	internal.network_error_message = 'internal-only metadata'
	basic := filtered_response(internal, .basic)
	assert basic.header_list.contains('Content-Type')
	assert !basic.header_list.contains('Set-Cookie')
	assert basic.fetch_response_redirect_taint() == .cross_site
	mut basic_mut := basic
	basic_mut.set_redirect_taint(.same_site)
	assert internal.redirect_taint == .same_site
	assert basic.fetch_response_method() == ''
	assert basic.fetch_response_network_error_message() == none
	cors_response := filtered_response(internal, .cors)
	assert cors_response.header_list.contains('X-Visible')
	opaque := filtered_response(internal, .opaque)
	assert opaque.status == 0 && opaque.body == none
	assert opaque.unsafe_response() == internal
	assert opaque.is_cors_cross_origin()
}

fn test_response_transfer_lease_actions_delegate_through_filtered_responses() {
	mut log := &RequestServerActionLog{}
	mut response := Response.create()
	response.set_request_server_request(RequestServerRequest{
		client_id: 4
		request_id: 99
		release_transfer_lease: fn [mut log] () {
			log.releases++
		}
		resume_body_delivery: fn [mut log] () {
			log.resumes++
		}
		resume_body_delivery_up_to: fn [mut log] (byte_count uint) {
			log.resumed_up_to << byte_count
		}
		stop: fn [mut log] () {
			log.stops++
		}
	})
	filtered := filtered_response(response, .basic)
	assert filtered.request_server_request()?.client_id == 4
	filtered.resume_body_delivery()
	filtered.resume_body_delivery_up_to(128)
	filtered.release_request_transfer_lease()
	filtered.stop_request_server_request()
	assert log.releases == 2
	assert log.resumes == 1
	assert log.resumed_up_to == [uint(128)]
	assert log.stops == 1
	assert response.clone().request_server_request()?.request_id == 99
}

fn test_navigation_timing_allow_values_clone_and_delegate_through_filtered_responses() {
	mut response := Response.create()
	response.set_navigation_timing_allow_values_list([['*'], ['https://destination.test']])
	filtered := filtered_response(response, .basic)
	assert filtered.navigation_timing_allow_values_list() == [['*'], [
		'https://destination.test',
	]]
	mut filtered_mut := filtered
	filtered_mut.set_navigation_timing_allow_values_list([['https://updated.test']])
	assert response.navigation_timing_allow_values_list() == [
		['https://updated.test'],
	]
	assert response.clone().navigation_timing_allow_values_list() == [
		['https://updated.test'],
	]
}
