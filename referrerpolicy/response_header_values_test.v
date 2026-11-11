module referrerpolicy

import fetch
import http

fn test_source_referrer_response_splits_comma_separated_policy_tokens() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'origin, no-referrer'})
	// The last recognized token applies, including tokens in one header field.
	assert response.header_list.extract_header_list_values('Referrer-Policy')! == ['origin', 'no-referrer']
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .no_referrer
	mut request := fetch.Request.create()
	request.referrer_policy = 'same-origin'
	set_request_referrer_policy_on_redirect(mut request, response)
	assert request.referrer_policy == 'no-referrer'
}

fn test_source_referrer_response_trims_tokens_and_ignores_unknown_policies() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'ORIGIN'})
	response.header_list.append(http.Header{'X-Other-Policy', 'unsafe-url'})
	response.header_list.append(http.Header{'referrer-policy', '\tno-referrer\t'})
	response.header_list.append(http.Header{'Referrer-Policy', 'invalid'})
	assert response.header_list.extract_header_list_values('referrer-policy')! == [
		'ORIGIN',
		'no-referrer',
		'invalid',
	]
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .no_referrer
	mut request := fetch.Request.create()
	request.referrer_policy = 'strict-origin'
	set_request_referrer_policy_on_redirect(mut request, response)
	assert request.referrer_policy == 'no-referrer'
}

fn test_source_referrer_response_last_valid_separate_header_wins_and_missing_keeps_request() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'no-referrer'})
	response.header_list.append(http.Header{'REFERRER-POLICY', 'STRICT-ORIGIN'})
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

fn test_source_referrer_response_rejects_empty_or_malformed_token_fields() {
	for value in ['', ', \t,', 'no-referrer; origin', 'origin, bad token'] {
		mut response := fetch.Response.create()
		response.header_list.append(http.Header{'Referrer-Policy', 'no-referrer'})
		response.header_list.append(http.Header{'Referrer-Policy', value})
		if _ := response.header_list.extract_header_list_values('Referrer-Policy') {
			assert false, 'Expected invalid Referrer-Policy field to fail: ${value}'
		} else {
			assert err.msg() == 'Failed to parse Referrer-Policy header values'
		}
		assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .empty_string
		mut request := fetch.Request.create()
		request.referrer_policy = 'same-origin'
		set_request_referrer_policy_on_redirect(mut request, response)
		assert request.referrer_policy == 'same-origin'
	}
}
