module referrerpolicy

import fetch
import http

fn test_source_referrer_response_keeps_whole_raw_header_value() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'origin, no-referrer'})
	// Pinned LibHTTP Header extraction retains one raw value for this name.
	assert response.header_list.extract_header_list_values('Referrer-Policy')! == ['origin, no-referrer']
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .empty_string
	mut request := fetch.Request.create()
	request.referrer_policy = 'same-origin'
	set_request_referrer_policy_on_redirect(mut request, response)
	assert request.referrer_policy == 'same-origin'
}

fn test_source_referrer_response_does_not_trim_each_extracted_header() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'ORIGIN'})
	response.header_list.append(http.Header{'X-Other-Policy', 'unsafe-url'})
	response.header_list.append(http.Header{'referrer-policy', '\tno-referrer\t'})
	response.header_list.append(http.Header{'REFERRER-POLICY', ''})
	response.header_list.append(http.Header{'Referrer-Policy', 'invalid'})
	assert response.header_list.extract_header_list_values('referrer-policy')! == [
		'ORIGIN',
		'\tno-referrer\t',
		'',
		'invalid',
	]
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .origin
	mut request := fetch.Request.create()
	request.referrer_policy = 'strict-origin'
	set_request_referrer_policy_on_redirect(mut request, response)
	assert request.referrer_policy == 'origin'
}

fn test_source_referrer_response_last_valid_separate_header_wins_and_missing_keeps_request() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'no-referrer'})
	response.header_list.append(http.Header{'REFERRER-POLICY', 'STRICT-ORIGIN'})
	response.header_list.append(http.Header{'Referrer-Policy', ''})
	response.header_list.append(http.Header{'Referrer-Policy', 'invalid'})
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .strict_origin
	mut request := fetch.Request.create()
	request.referrer_policy = 'origin'
	set_request_referrer_policy_on_redirect(mut request, response)
	assert request.referrer_policy == 'strict-origin'
	missing := fetch.Response.create()
	assert parse_a_referrer_policy_from_a_referrer_policy_header(missing) == .empty_string
	set_request_referrer_policy_on_redirect(mut request, missing)
	assert request.referrer_policy == 'strict-origin'
}
