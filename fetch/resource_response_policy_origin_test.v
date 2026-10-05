module fetch

import contentsecuritypolicy as csp
import dom
import http

fn test_source_resource_response_policies_use_the_actual_shared_url_origin() {
	cached := dom.dom_url_parse('worker.js', dom.URL{value: 'resource://first-owner:8123/pages/start.html'},
		'UTF-8')?
	mut response := Response.create()
	response.url_list = [cached]
	response.header_list.append(http.Header{'Content-Security-Policy', "script-src 'self'"})
	response.header_list.append(http.Header{'Content-Security-Policy-Report-Only', 'img-src data:'})
	projected := csp_response(response)
	assert voidptr(projected.header_list?) == voidptr(response.header_list)
	assert projected.url?.serialize(false) == cached.serialize()
	policies := csp.parse_a_responses_content_security_policies(projected).policies
	assert policies.len == 2
	first := policies[0].self_origin_value()
	second := policies[1].self_origin_value()
	assert first.serialize() == 'resource://'
	assert !first.is_opaque()
	assert first.is_same_origin(second)
	assert first.is_same_origin(cached.origin().liburl_origin()?)
	assert first.is_same_origin(dom.URL{value: 'resource://second-owner:9443/other.js'}.origin().liburl_origin()?)
	assert policies[0].clone().serialize()!.self_origin.is_same_origin(first)
}
