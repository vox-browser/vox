module fetch

import contentsecuritypolicy as csp
import dom
import http

fn source_self_response_policy(address dom.URL) &csp.Policy {
	mut response := Response.create()
	response.url_list = [address]
	response.header_list.append(http.Header{'Content-Security-Policy', "connect-src 'self'"})
	policies := csp.parse_a_responses_content_security_policies(csp_response(response)).policies
	assert policies.len == 1
	return policies[0]
}

fn test_source_self_consumes_actual_cached_resource_url_origins() {
	protected := dom.dom_url_parse('page.html', dom.URL{value: 'resource://protected-owner:8123/pages/'},
		'UTF-8')?
	target := dom.dom_url_parse('worker.js', dom.URL{value: 'resource://different-owner:9443/workers/'},
		'UTF-8')?
	policy := source_self_response_policy(protected)
	origin := policy.self_origin?
	assert !origin.is_opaque()
	assert origin.serialize() == 'resource://'
	assert csp.does_url_match_expression_in_origin_with_redirect_count(target.parsed()?, "'self'",
		origin, 0) == .matches
	assert csp.does_url_match_expression_in_origin_with_redirect_count(target.parsed()?, "'SELF'",
		policy.clone().self_origin?, 1) == .matches
}

fn test_source_self_uses_actual_blob_url_origin_instead_of_an_outer_scheme_tuple() {
	policy := source_self_response_policy(dom.URL{value: 'https://protected-blob.test:8443/page'})
	target := dom.URL{value: 'blob:https://protected-blob.test:8443/actual-url-id'}
	assert csp.does_url_match_expression_in_origin_with_redirect_count(target.parsed()?, "'self'",
		policy.self_origin?, 0) == .matches
	other := dom.URL{value: 'blob:https://other-blob.test:8443/actual-url-id'}
	assert csp.does_url_match_expression_in_origin_with_redirect_count(other.parsed()?, "'self'",
		policy.self_origin?, 0) == .does_not_match
}

fn test_source_self_preserves_genuine_opaque_policy_owners_and_default_file_controls() {
	for address in ['data:text/html,actual-opaque-owner', 'file:///tmp/actual-opaque-owner.html'] {
		actual := dom.URL{value: address}
		policy := source_self_response_policy(actual)
		origin := policy.self_origin?
		assert origin.is_opaque()
		assert origin.is_opaque_file_origin() == address.starts_with('file:')
		assert policy.clone().self_origin?.is_same_origin(origin)
		assert csp.does_url_match_expression_in_origin_with_redirect_count(actual.parsed()?, "'self'",
			origin, 0) == .does_not_match
	}
}

fn test_source_self_retains_ordinary_https_host_and_port_gates() {
	policy := source_self_response_policy(dom.URL{value: 'https://ordinary-self.test:8443/page'})
	for case in [
		['https://ordinary-self.test:8443/target', 'match'],
		['https://ordinary-self.test:9443/target', 'miss'],
		['https://different-self.test:8443/target', 'miss'],
	] {
		actual := csp.does_url_match_expression_in_origin_with_redirect_count(dom.URL{value: case[0]}.parsed()?,
			"'self'", policy.self_origin?, 0)
		assert actual == if case[1] == 'match' {
			csp.MatchResult.matches
		} else {
			csp.MatchResult.does_not_match
		}
	}
}
