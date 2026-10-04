module html

import dom
import fetch
import http
import page

fn source_initialization_response(url dom.URL, enforce string, report string) &fetch.Response {
	mut response := fetch.Response.create()
	response.url_list = [url]
	response.header_list.append(http.Header{'Content-Security-Policy', enforce})
	if report != '' {
		response.header_list.append(http.Header{'Content-Security-Policy-Report-Only', report})
	}
	return response
}

fn source_initialization_document(address string, enforce string, report string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	document.set_policy_container(create_a_policy_container_from_fetch_response(source_initialization_response(url, enforce, report)))
	native := document.get_window() or { return error('missing actual initialization Window') }
	return document, unsafe { &WindowModel(native) }
}

fn source_initialization_meta(document &dom.Document, policy string) ! {
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('http-equiv', 'content-security-policy')
	meta.set_attribute_value('content', policy)
	head := document.head() or { return error('missing actual initialization Head') }
	mut head_node := head.as_node()
	head_node.append_child(meta.as_node())!
}

fn test_source_document_initialization_uses_own_ordered_policies_during_window_reassociation() {
	mut original, mut window := source_initialization_document('https://own-initialization-policy.test:8443/page', "sandbox; img-src 'self'; trusted-types own-name", "sandbox; style-src 'unsafe-inline'")!
	mut replacement, _ := source_initialization_document('https://current-initialization-policy.test/page', "sandbox; default-src 'none'", '')!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	opaque := dom.origin_create_opaque()
	original.set_origin(opaque)
	source_initialization_meta(original, "style-src 'none'; trusted-types meta-name")!
	source_initialization_meta(replacement, "img-src 'none'")!
	original.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_forms))
	window.set_associated_document(replacement)
	assert voidptr(window.environment_settings_.settings.policy_container()) == voidptr(replacement.policy_container())
	// Source inline/global checks intentionally use relevant settings instead.
	assert document_csp_policies(original).len == 2
	assert document_csp_policies(original)[0].pre_parsed_policy_string() == "sandbox; default-src 'none'"
	policies := document_csp_initialization_policies(original)
	assert policies.len == 3
	assert policies.map(it.source()) == [.header, .header, .meta]
	assert policies.map(it.disposition()) == [.enforce, .report, .enforce]
	assert policies[0].pre_parsed_policy_string() == "sandbox; img-src 'self'; trusted-types own-name"
	assert policies[0].directives().map(it.name()) == ['sandbox', 'img-src', 'trusted-types']
	assert policies[0].self_origin?.serialize() == 'https://own-initialization-policy.test:8443'
	assert policies[1].pre_parsed_policy_string() == "sandbox; style-src 'unsafe-inline'"
	assert policies[2].pre_parsed_policy_string() == "style-src 'none'; trusted-types meta-name"
	assert policies[2].self_origin?.opaque_data()?.nonce == opaque.liburl_origin()?.opaque_data()?.nonce
	// Pinned Source Sandbox initialization is Allowed for Documents, even
	// though this enforced policy would block a Worker initialization.
	sandbox := policies[0].get_directive_by_name('sandbox')?
	assert sandbox.initialization(false, policies[0]) == .allowed
	assert sandbox.initialization(true, policies[0]) == .blocked
	original.run_csp_initialization()
	assert original.active_sandboxing_flag_bits() == u32(SandboxingFlag.sandboxed_forms)
	assert original.policy_container().csp_list.len == 3
	assert replacement.policy_container().csp_list.len == 2
	third := create_a_policy_container_from_fetch_response(source_initialization_response(original.url, "script-src 'self'", ''))
	original.set_policy_container(third)
	refreshed := document_csp_initialization_policies(original)
	assert refreshed.len == 1
	assert refreshed[0].pre_parsed_policy_string() == "script-src 'self'"
	assert document_csp_policies(original).len == 2
	original.run_csp_initialization()
	window.set_associated_document(original)
	assert document_csp_initialization_policies(original).len == 1
}

fn test_source_document_initialization_reads_actual_container_without_window_settings() {
	mut document := dom.Document.create(dom.URL{'https://standalone-initialization-policy.test/page'})
	defer { document.finalize() }
	assert document.relevant_settings_object() == unsafe { nil }
	install_document_csp_hook(document)
	container := create_a_policy_container_from_fetch_response(source_initialization_response(document.url, "sandbox; img-src 'none'", "style-src 'self'"))
	document.set_policy_container(container)
	document.enforce_meta_csp('trusted-types standalone-string')
	assert document_csp_policies(document).len == 1
	policies := document_csp_initialization_policies(document)
	assert policies.len == 2
	assert policies[0].source() == .header && policies[0].disposition() == .enforce
	assert policies[1].source() == .header && policies[1].disposition() == .report
	assert policies[0].pre_parsed_policy_string() == "sandbox; img-src 'none'"
	assert policies[1].pre_parsed_policy_string() == "style-src 'self'"
	assert policies[0].self_origin?.serialize() == 'https://standalone-initialization-policy.test'
	document.run_csp_initialization()
	assert voidptr(document.policy_container()) == voidptr(container)
	assert document.active_sandboxing_flag_bits() == 0
}
