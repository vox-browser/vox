module referrerpolicy

import dom
import fetch
import http
import referrercore

fn test_source_referrer_enum_is_the_actual_document_policy_record_type() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Referrer-Policy', 'no-referrer'})
	response.header_list.append(http.Header{'Referrer-Policy', 'ORIGIN'})
	parsed := parse_a_referrer_policy_from_a_referrer_policy_header(response)
	container := &dom.PolicyContainer{ referrer_policy: parsed }
	mut document := dom.Document.create(dom.URL{value: 'https://shared-referrer-record.test/page'})
	defer { document.finalize() }
	document.set_policy_container(container)
	assert voidptr(document.policy_container()) == voidptr(container)
	assert document.policy_container().referrer_policy == .origin
	assert document.policy_container().serialize().referrer_policy == parsed
	assert document.policy_container().clone().referrer_policy == parsed
}

fn test_source_acyclic_referrer_core_returns_the_same_actual_policy_enum() {
	assert default_referrer_policy == dom.ReferrerPolicy.strict_origin_when_cross_origin
	assert referrercore.default_referrer_policy == dom.ReferrerPolicy.strict_origin_when_cross_origin
	parsed := referrercore.from_string('STRICT-ORIGIN')?
	container := dom.PolicyContainer{ referrer_policy: parsed }
	assert container.referrer_policy == .strict_origin
	assert to_string(container.referrer_policy) == 'strict-origin'
	assert referrercore.to_string(container.referrer_policy) == 'strict-origin'
	assert parse_a_referrer_policy_from_header_tokens(['origin', 'no-referrer']) == dom.ReferrerPolicy.no_referrer
}

fn test_source_header_core_reads_the_live_actual_response_list_without_a_copy() {
	mut response := fetch.Response.create()
	list := response.header_list
	assert referrercore.parse_a_referrer_policy_from_header_list(list) == .empty_string
	response.header_list.append(http.Header{'Referrer-Policy', 'ORIGIN'})
	response.header_list.append(http.Header{'Referrer-Policy', 'no-referrer, strict-origin'})
	response.header_list.append(http.Header{'Referrer-Policy', '\tunsafe-url\t'})
	assert referrercore.parse_a_referrer_policy_from_header_list(list) == .unsafe_url
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .unsafe_url
	response.header_list.append(http.Header{'Referrer-Policy', 'SAME-ORIGIN'})
	assert referrercore.parse_a_referrer_policy_from_header_list(list) == .same_origin
	assert parse_a_referrer_policy_from_a_referrer_policy_header(response) == .same_origin
}
