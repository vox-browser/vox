module html

import contentsecuritypolicy as csp
import dom
import fetch
import http
import os
import page
import url as liburl

fn test_source_file_policy_reaches_cached_dom_and_actual_csp_container_owners() {
	assert !liburl.file_scheme_urls_have_tuple_origins()
	cached := dom.dom_url_parse('page.html', dom.URL{value: 'file://cached-owner/tmp/'}, 'UTF-8')?
	retained_record := cached.parsed()?
	before_enable := cached.origin()
	assert before_enable.is_opaque_file_origin()
	enabled := os.getenv('VOX2_SOURCE_FILE_POLICY_OWNERS') == 'enabled'
	if enabled {
		liburl.set_file_scheme_urls_have_tuple_origins()
	}
	assert liburl.file_scheme_urls_have_tuple_origins() == enabled
	assert cached.serialize() == 'file://cached-owner/tmp/page.html'
	assert retained_record.host?.serialize() == 'cached-owner'
	actual := cached.origin()
	assert actual.is_opaque_file_origin() == !enabled
	assert before_enable.is_opaque_file_origin()
	if enabled {
		assert actual.serialize() == 'file://'
		assert actual.is_same_origin(dom.URL{value: 'file://different-owner/tmp/other.html'}.origin())
		assert actual.is_same_origin(dom.URL{value: 'blob:file:///tmp/actual-file-blob'}.origin())
	} else {
		assert !actual.is_same_origin(cached.origin())
	}
	mut response := fetch.Response.create()
	response.url_list = [cached]
	response.header_list.append(http.Header{'Content-Security-Policy', "connect-src 'self'"})
	response.header_list.append(http.Header{'Content-Security-Policy-Report-Only', "img-src 'self'"})
	container := create_a_policy_container_from_fetch_response(response)
	assert container.csp_list.len == 2
	assert container.csp_list[0].self_origin.is_opaque_file_origin() == !enabled
	assert container.csp_list[1].self_origin.is_opaque_file_origin() == !enabled
	assert container.csp_list[0].self_origin.is_same_origin(container.csp_list[1].self_origin) == enabled
	copy := container.clone()
	assert copy.csp_list[0].self_origin.is_same_origin(container.csp_list[0].self_origin)
	owner := page.Page.create(1)!
	mut document := create_navigation_document_for_page(cached, actual, none, unsafe { &dom.Page(owner) })!
	defer { document.finalize() }
	document.set_policy_container(container)
	window := unsafe { &WindowModel(document.get_window()?) }
	settings := window.environment_settings_.settings
	assert voidptr(settings.policy_container()) == voidptr(document.policy_container())
	assert voidptr(settings.policy_container()) == voidptr(container)
	policies := settings.fetch_request_client_policy_container().csp_list.policies
	assert policies.len == 2
	origin := policies[0].self_origin?
	assert origin.is_opaque_file_origin() == !enabled
	assert origin.is_same_origin(container.csp_list[0].self_origin.liburl_origin()?)
	assert document.origin().is_same_origin(actual)
	result := csp.does_url_match_expression_in_origin_with_redirect_count(dom.URL{value: 'file://other-owner/tmp/target'}.parsed()?,
		"'self'", origin, 0)
	assert result == if enabled { csp.MatchResult.matches } else { csp.MatchResult.does_not_match }
	assert !dom.URL{value: 'data:text/plain,file-owner-control'}.origin().is_opaque_file_origin()
	assert dom.URL{value: 'https://file-owner.test:8443/page'}.origin().serialize() == 'https://file-owner.test:8443'
	if enabled {
		return
	}
	mut environment := os.environ()
	environment['VOX2_SOURCE_FILE_POLICY_OWNERS'] = 'enabled'
	mut process := os.new_process(os.executable())
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code == 0, output
	process.close()
	assert !liburl.file_scheme_urls_have_tuple_origins()
	assert cached.origin().is_opaque_file_origin()
}
