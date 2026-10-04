module html

import dom
import fetch
import http
import page

fn source_factory_actual_document(address string) !(&dom.Document, &EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	install_document_csp_hook(document)
	window := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(window) }.environment_settings_.settings
}

fn source_factory_response(address string, headers []http.Header) &fetch.Response {
	mut response := fetch.Response.create()
	response.url_list = [dom.URL{address}]
	for header in headers {
		response.header_list.append(header)
	}
	return response
}

fn test_source_response_factory_uses_each_raw_policy_and_source_list_order() {
	mut raw := 'unknown '.bytes()
	raw << u8(0xe9)
	raw << "; connect-src 'self'".bytes()
	response := source_factory_response('https://factory-policy.test:8443/page', [
		http.Header{'Content-Security-Policy-Report-Only', 'style-src https:'},
		http.Header{'Content-Security-Policy', "SCRIPT-SRC 'self'; script-src 'none'"},
		http.Header{'content-security-policy', "img-src data:, script-src 'none'"},
		http.Header{'Content-Security-Policy', raw.bytestr()},
		http.Header{'Content-Security-Policy', ' ;\t;'},
		http.Header{'CONTENT-SECURITY-POLICY-REPORT-ONLY', "default-src 'none'"},
		http.Header{'Referrer-Policy', 'ORIGIN'},
		http.Header{'Referrer-Policy', 'no-referrer, same-origin'},
	])
	container := create_a_policy_container_from_fetch_response(response)
	assert container.csp_list.len == 5
	assert container.csp_list.map(it.disposition) == [
		dom.CSPPolicyDisposition.enforce,
		.enforce,
		.enforce,
		.report,
		.report,
	]
	assert container.csp_list[0].directives[0].value == ["'self'"]
	assert container.csp_list[1].directives.len == 1
	assert container.csp_list[1].directives[0].value == ['data:,', 'script-src', "'none'"]
	assert container.csp_list[2].directives.len == 1
	assert container.csp_list[2].directives[0].name == 'connect-src'
	assert container.csp_list[2].pre_parsed_policy_string == "unknown \u00e9; connect-src 'self'"
	assert container.csp_list[3].directives[0].name == 'style-src'
	assert container.csp_list[4].directives[0].name == 'default-src'
	for policy in container.csp_list {
		assert policy.source == .header
		assert policy.self_origin.serialize() == 'https://factory-policy.test:8443'
	}
	assert container.referrer_policy == .origin
	assert container.embedder_policy.value == .unsafe_none
	assert container.integrity_policy.is_empty()
	assert container.report_only_integrity_policy.is_empty()
}

fn test_source_response_factory_keeps_default_for_raw_invalid_referrer_values() {
	for values in [
		[]string{},
		[''],
		['invalid'],
		['origin, no-referrer'],
		[' \tno-referrer\t '],
	] {
		mut response := source_factory_response('https://factory-referrer.test/page', [])
		for value in values {
			response.header_list.append(http.Header{'Referrer-Policy', value})
		}
		container := create_a_policy_container_from_fetch_response(response)
		assert container.referrer_policy == .strict_origin_when_cross_origin
		assert container.csp_list.len == 0
	}
}

fn test_source_response_factory_omits_empty_csp_policies_without_reading_an_absent_url() {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{'Content-Security-Policy', ' ;\t; '})
	response.header_list.append(http.Header{'Content-Security-Policy-Report-Only', '\r\f;'})
	container := create_a_policy_container_from_fetch_response(response)
	assert container.csp_list.len == 0
	assert container.referrer_policy == .strict_origin_when_cross_origin
}

fn test_source_response_factory_retains_each_real_opaque_origin_through_clone_and_projection() {
	for address in ['file:///tmp/factory-policy.html', 'data:text/html,hello'] {
		response := source_factory_response(address, [
			http.Header{'Content-Security-Policy', "default-src 'self'"},
			http.Header{'Content-Security-Policy-Report-Only', 'img-src data:'},
		])
		container := create_a_policy_container_from_fetch_response(response)
		assert container.csp_list.len == 2
		first := container.csp_list[0].self_origin
		second := container.csp_list[1].self_origin
		assert first.is_opaque()
		assert second.is_opaque()
		assert first.is_opaque_file_origin() == address.starts_with('file:')
		assert !first.is_same_origin(second)
		cloned := container.clone()
		projected := fetch_csp_policy_list(container.csp_list)
		for index, policy in container.csp_list {
			assert cloned.csp_list[index].self_origin.is_same_origin(policy.self_origin)
			assert projected.policies[index].self_origin?.is_same_origin(policy.self_origin.liburl_origin()?)
			assert projected.policies[index].self_origin?.opaque_data()?.nonce == policy.self_origin.liburl_origin()?.opaque_data()?.nonce
		}
	}
}

fn test_source_response_factory_populates_the_actual_document_settings_policy_owner() {
	mut document, settings := source_factory_actual_document('https://factory-owner.test:8443/page')!
	defer { document.finalize() }
	mut response := source_factory_response(document.url.serialize(), [
		http.Header{'Content-Security-Policy-Report-Only', "script-src 'self'"},
		http.Header{'Content-Security-Policy', "img-src 'none'"},
		http.Header{'Referrer-Policy', 'NO-REFERRER'},
	])
	container := create_a_policy_container_from_a_fetch_response(response, settings)
	document.set_policy_container(container)
	assert voidptr(document.policy_container()) == voidptr(container)
	assert voidptr(settings.policy_container()) == voidptr(container)
	assert container.csp_list.len == 2
	response.header_list.append(http.Header{'Content-Security-Policy', "default-src 'none'"})
	assert container.csp_list.len == 2
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('http-equiv', 'content-security-policy')
	meta.set_attribute_value('content', "style-src 'none'")
	head := document.head()?
	mut head_node := head.as_node()
	head_node.append_child(meta.as_node())!
	assert container.csp_list.len == 3
	assert settings.fetch_request_client_policy_container().referrer_policy == 'no-referrer'
	assert settings.fetch_request_client_policy_container().csp_list.policies.len == 3
	assert settings.serialize().policy_container.csp_list.len == 3
	mut request := fetch.Request.create()
	request.set_client(settings)
	request.set_url(dom.URL{'https://other-factory-owner.test/image.png'})
	request.destination = .image
	fetch.populate_request_from_client(mut request)
	actual := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response {
			panic('actual Source factory policy must block before transport')
		}
	}).response()?
	assert actual.is_network_error()
}
