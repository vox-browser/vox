module referrerpolicy

import dom
import fetch
import http

const all_named_policies = [dom.ReferrerPolicy.no_referrer, .no_referrer_when_downgrade, .same_origin,
	.origin, .strict_origin, .origin_when_cross_origin, .strict_origin_when_cross_origin, .unsafe_url]

fn test_to_string() {
	assert to_string(.empty_string) == ''
	assert to_string(.no_referrer) == 'no-referrer'
	assert to_string(.no_referrer_when_downgrade) == 'no-referrer-when-downgrade'
	assert to_string(.same_origin) == 'same-origin'
	assert to_string(.origin) == 'origin'
	assert to_string(.strict_origin) == 'strict-origin'
	assert to_string(.origin_when_cross_origin) == 'origin-when-cross-origin'
	assert to_string(.strict_origin_when_cross_origin) == 'strict-origin-when-cross-origin'
	assert to_string(.unsafe_url) == 'unsafe-url'
}

fn test_from_string_exact() {
	assert from_string('no-referrer')? == ReferrerPolicy.no_referrer
	assert from_string('strict-origin-when-cross-origin')? == ReferrerPolicy.strict_origin_when_cross_origin
	assert from_string('unsafe-url')? == ReferrerPolicy.unsafe_url
}

fn test_from_string_empty_is_empty_string_policy() {
	assert from_string('')? == ReferrerPolicy.empty_string
}

fn test_from_string_is_ascii_case_insensitive() {
	assert from_string('No-Referrer')? == ReferrerPolicy.no_referrer
	assert from_string('UNSAFE-URL')? == ReferrerPolicy.unsafe_url
	assert from_string('Same-Origin')? == ReferrerPolicy.same_origin
}

fn test_from_string_unknown_is_none() {
	assert from_string('bogus') == none
	assert from_string('no_referrer') == none // underscore, not hyphen
	assert from_string('origin ') == none // trailing space is not trimmed here
}

fn test_default_policy() {
	assert default_referrer_policy == ReferrerPolicy.strict_origin_when_cross_origin
}

fn test_round_trip_named_policies() {
	for policy in all_named_policies {
		assert from_string(to_string(policy))? == policy
	}
}

fn test_parse_from_header_tokens_last_valid_wins() {
	// The last valid, non-empty token wins.
	assert parse_a_referrer_policy_from_header_tokens(['no-referrer', 'origin']) == ReferrerPolicy.origin
	assert parse_a_referrer_policy_from_header_tokens(['origin', 'strict-origin']) == ReferrerPolicy.strict_origin
}

fn test_parse_from_header_tokens_skips_invalid_and_empty() {
	// Unknown tokens are ignored; an empty-string token does not override the running policy.
	assert parse_a_referrer_policy_from_header_tokens(['origin', 'bogus']) == ReferrerPolicy.origin
	assert parse_a_referrer_policy_from_header_tokens(['no-referrer', '']) == ReferrerPolicy.no_referrer
}

fn test_parse_from_header_tokens_defaults_to_empty_string() {
	// No tokens, or only invalid ones, yields the empty-string policy.
	assert parse_a_referrer_policy_from_header_tokens([]) == ReferrerPolicy.empty_string
	assert parse_a_referrer_policy_from_header_tokens(['bogus', 'also-bogus']) == ReferrerPolicy.empty_string
}

fn test_parse_header_and_redirect_update() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{ name: 'Referrer-Policy', value: 'origin' })
	response.header_list.append(http.Header{ name: 'Referrer-Policy', value: 'no-referrer' })
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .no_referrer
	mut request := fetch.Request.create()
	set_request_referrer_policy_on_redirect(mut request, response)
	assert request.referrer_policy == 'no-referrer'
}

fn referrer_request(policy string, destination string) &fetch.Request {
	mut request := fetch.Request.create()
	request.referrer_policy = policy
	request.referrer.url = dom.URL{value: 'https://user:secret@example.test/path?q=1#fragment'}
	request.url_list = [dom.URL{value: destination}]
	return request
}

fn test_strip_url_removes_credentials_fragment_and_origin_data() {
	full :=
		strip_url_for_use_as_referrer(dom.URL{value: 'https://user:secret@example.test/path?q=1#x'}, .no)?
	assert full.serialize() == 'https://example.test/path?q=1'
	origin :=
		strip_url_for_use_as_referrer(dom.URL{value: 'https://user:secret@example.test/path?q=1#x'}, .yes)?
	assert origin.serialize() == 'https://example.test/'
	assert strip_url_for_use_as_referrer(dom.URL{value: 'data:text/plain,x'}, .no) == none
}

fn test_determine_referrer_policy_matrix() {
	assert determine_requests_referrer(referrer_request('no-referrer', 'https://example.test/')) == none
	assert determine_requests_referrer(referrer_request('origin', 'https://other.test/'))?.serialize() == 'https://example.test/'
	assert determine_requests_referrer(referrer_request('same-origin', 'https://other.test/')) == none
	assert determine_requests_referrer(referrer_request('same-origin', 'https://example.test/next'))?.serialize() == 'https://example.test/path?q=1'
	assert determine_requests_referrer(referrer_request('origin-when-cross-origin',
		'https://other.test/'))?.serialize() == 'https://example.test/'
	assert determine_requests_referrer(referrer_request('strict-origin', 'http://other.test/')) == none
	assert determine_requests_referrer(referrer_request('no-referrer-when-downgrade',
		'http://other.test/')) == none
}

fn test_client_referrer_uses_window_document_or_worker_creation_url() {
	mut window_request := fetch.Request.create()
	window_request.referrer_policy = 'unsafe-url'
	window_request.client_is_window = true
	window_request.client_document_url = dom.URL{value: 'https://example.test/document#x'}
	window_request.url_list = [dom.URL{value: 'https://example.test/next'}]
	assert determine_requests_referrer(window_request)?.serialize() == 'https://example.test/document'
	mut opaque := fetch.Request.create()
	opaque.referrer_policy = 'unsafe-url'
	opaque.client_origin_opaque = true
	opaque.url_list = [dom.URL{value: 'https://example.test/'}]
	assert determine_requests_referrer(opaque) == none
}
