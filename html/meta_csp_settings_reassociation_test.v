module html

import dom
import fetch
import http
import page

fn source_meta_settings_document(address string, policy string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	mut response := fetch.Response.create()
	response.url_list = [url]
	response.header_list.append(http.Header{'Content-Security-Policy', policy})
	document.set_policy_container(create_a_policy_container_from_fetch_response(response))
	native := document.get_window() or { return error('missing actual Meta Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_source_meta_csp_append_uses_current_settings_container_and_element_document_origin() {
	mut original, mut window := source_meta_settings_document('https://old-meta-settings.test/page', "img-src 'self'")!
	mut replacement, _ := source_meta_settings_document('https://new-meta-settings.test:8443/page', "script-src 'self'")!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	old_container := original.policy_container()
	new_container := replacement.policy_container()
	opaque := dom.origin_create_opaque()
	original.set_origin(opaque)
	window.set_associated_document(replacement)
	settings := window.environment_settings_.settings
	assert voidptr(settings.policy_container()) == voidptr(new_container)
	mut meta := original.create_element('meta')!
	meta.set_attribute_value('http-equiv', 'CONTENT-SECURITY-POLICY')
	meta.set_attribute_value('content', "sandbox; frame-ancestors 'none'; report-uri /report; style-src 'none'")
	old_head := original.head()?
	mut old_head_node := old_head.as_node()
	old_head_node.append_child(meta.as_node())!
	assert voidptr(meta.document()) == voidptr(original)
	// HTMLMetaElement.cpp:221 explicitly uses relevant settings. Its self
	// origin still comes from element.document(), per Source line218.
	assert old_container.csp_list.len == 1
	assert new_container.csp_list.len == 2
	assert new_container.csp_list.map(it.source) == [.header, .meta]
	assert new_container.csp_list[0].pre_parsed_policy_string == "script-src 'self'"
	assert new_container.csp_list[1].directives.map(it.name) == ['style-src']
	assert new_container.csp_list[1].self_origin.serialize_for_ipc() == opaque.serialize_for_ipc()
	assert settings.fetch_request_client_policy_container().csp_list.policies[1].self_origin?.opaque_data()?.nonce == opaque.liburl_origin()?.opaque_data()?.nonce
	assert settings.serialize().policy_container.csp_list.len == 2
	assert document_csp_initialization_policies(original).len == 1
	meta.set_attribute_value('content', "base-uri 'none'")
	assert old_container.csp_list.len == 1 && new_container.csp_list.len == 2
	mut meta_node := meta.as_node()
	meta_node.remove(false)
	assert new_container.csp_list.len == 2
	new_head := replacement.head()?
	mut new_head_node := new_head.as_node()
	new_head_node.append_child(meta.as_node())!
	assert voidptr(meta.document()) == voidptr(replacement)
	assert old_container.csp_list.len == 1
	assert new_container.csp_list.len == 3
	assert new_container.csp_list[2].source == .meta
	assert new_container.csp_list[2].directives[0].name == 'base-uri'
	assert new_container.csp_list[2].self_origin.serialize_for_ipc() == replacement.origin().serialize_for_ipc()
	assert new_container.csp_list[2].self_origin.serialize() == 'https://new-meta-settings.test:8443'
	window.set_associated_document(original)
	assert voidptr(settings.policy_container()) == voidptr(old_container)
	assert settings.serialize().policy_container.csp_list.len == 1
}
