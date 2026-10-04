module fetch

import contentsecuritypolicy as csp
import dom
import http
import url

fn source_csp_header_response(target string, headers []http.Header) &Response {
	mut response := Response.create()
	response.url_list = [dom.URL{target}]
	for header in headers {
		response.header_list.append(header)
	}
	return response
}

fn test_source_csp_response_projection_retains_its_actual_header_list() {
	mut response := source_csp_header_response('https://response-owner.test:8443/page', [
		http.Header{'Content-Security-Policy', "script-src 'self'"},
	])
	mut projected := csp_response(response)
	assert projected.header_list != none
	list := projected.header_list or { return }
	assert voidptr(list) == voidptr(response.header_list)
	projected.headers['Content-Security-Policy'] = ["default-src 'none'"]
	response.header_list.append(http.Header{'content-security-policy', 'img-src data:'})
	policies := csp.parse_a_responses_content_security_policies(projected).policies
	assert policies.len == 2
	assert policies[0].directives()[0].name() == csp.script_src
	assert policies[1].directives()[0].name() == csp.img_src
	assert policies[0].self_origin_value().serialize() == 'https://response-owner.test:8443'
}

fn test_source_csp_response_extracts_enforce_before_report_and_keeps_raw_values() {
	response := source_csp_header_response('https://response-order.test/page', [
		http.Header{'Content-Security-Policy-Report-Only', 'img-src report:'},
		http.Header{'Content-Security-Policy', " SCRIPT-SRC\t'self'\rhttps://cdn.test; script-src 'none'"},
		http.Header{'content-security-policy', "img-src data:, script-src 'none'"},
		http.Header{'Content-Security-Policy', ' ;\t;\r\f'},
		http.Header{'CONTENT-SECURITY-POLICY-REPORT-ONLY', 'style-src https:'},
	])
	policies := csp.parse_a_responses_content_security_policies(csp_response(response)).policies
	assert policies.len == 4
	assert policies[0].disposition() == .enforce
	assert policies[1].disposition() == .enforce
	assert policies[2].disposition() == .report
	assert policies[3].disposition() == .report
	assert policies[0].directives()[0].value() == ["'self'", 'https://cdn.test']
	assert policies[1].directives().len == 1
	assert policies[1].directives()[0].value() == ['data:,', 'script-src', "'none'"]
	assert policies[2].directives()[0].value() == ['report:']
	assert policies[3].directives()[0].value() == ['https:']
	for policy in policies {
		assert policy.source() == .header
	}
}

fn test_source_csp_response_headers_use_the_byte_parser_branch() {
	mut raw := 'unknown '.bytes()
	raw << u8(0xe9)
	raw << "; default-src 'self'".bytes()
	response := source_csp_header_response('https://response-byte.test/page', [
		http.Header{'Content-Security-Policy', raw.bytestr()},
	])
	policies := csp.parse_a_responses_content_security_policies(csp_response(response)).policies
	assert policies.len == 1
	assert policies[0].pre_parsed_policy_string() == "unknown \u00e9; default-src 'self'"
	assert policies[0].directives().len == 1
	assert policies[0].directives()[0].name() == csp.default_src
}

fn test_source_csp_response_uses_the_actual_url_origin_for_each_policy() {
	for target in ['blob:https://response-origin.test:8443/id', 'file:///tmp/response-csp.html',
		'data:text/html,hello'] {
		response := source_csp_header_response(target, [
			http.Header{'Content-Security-Policy', "default-src 'self'"},
			http.Header{'Content-Security-Policy', 'img-src data:'},
		])
		policies := csp.parse_a_responses_content_security_policies(csp_response(response)).policies
		assert policies.len == 2
		first := policies[0].self_origin_value()
		second := policies[1].self_origin_value()
		if target.starts_with('blob:') {
			assert first.serialize() == 'https://response-origin.test:8443'
			assert first.is_same_origin(second)
		} else {
			assert first.is_opaque()
			assert second.is_opaque()
			assert first.is_opaque_file_origin() == target.starts_with('file:')
			assert !first.is_same_origin(second)
			assert first.opaque_data()?.nonce != [16]u8{}
			assert second.opaque_data()?.nonce != [16]u8{}
		}
	}
}

fn test_source_csp_standalone_header_map_is_an_explicit_fallback() {
	projected := csp.Response{
		url:     url.parse('https://standalone-response.test:9443/page')?
		headers: {
			'Content-Security-Policy-Report-Only': ['style-src https:']
			'content-security-policy':             ["script-src 'self'", ' ; ']
		}
	}
	assert projected.header_list == none
	policies := csp.parse_a_responses_content_security_policies(projected).policies
	assert policies.len == 2
	assert policies[0].disposition() == .enforce
	assert policies[1].disposition() == .report
	assert policies[0].self_origin_value().serialize() == 'https://standalone-response.test:9443'
}
