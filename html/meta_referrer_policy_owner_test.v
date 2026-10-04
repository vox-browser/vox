module html

import dom
import fetch
import http
import page

fn source_referrer_document(address string, header_policy string, referrer string) !(&dom.Document, &WindowModel, &EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	mut response := fetch.Response.create()
	response.url_list = [url]
	response.header_list.append(http.Header{'Content-Security-Policy', header_policy})
	response.header_list.append(http.Header{'Referrer-Policy', referrer})
	document.set_policy_container(create_a_policy_container_from_fetch_response(response))
	native := document.get_window() or { return error('missing actual Window') }
	window := unsafe { &WindowModel(native) }
	return document, window, window.environment_settings_.settings
}

fn source_referrer_meta(document &dom.Document, name string, content string) !&dom.Element {
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('name', name)
	meta.set_attribute_value('content', content)
	return meta
}

fn source_referrer_append(parent &dom.Node, element &dom.Element) ! {
	mut actual_parent := unsafe { &dom.Node(parent) }
	actual_parent.append_child(element.as_node())!
}

fn test_source_parser_meta_referrer_writes_retained_document_owner_and_fetch_projection() {
	mut document, _, settings := source_referrer_document('https://parser-referrer-owner.test/page', "img-src 'self'", 'origin')!
	defer { document.finalize() }
	container := document.policy_container()
	mut node := document.as_node()
	node.replace_all(none)
	parse_html_from_a_string(document, '<!doctype html><html><head><meta name="ReFeRrEr" content="NEVER"><meta http-equiv="content-security-policy" content="style-src \'none\'"></head><body>actual parser</body></html>')
	assert voidptr(document.policy_container()) == voidptr(container)
	assert container.referrer_policy == .no_referrer
	assert document.meta_referrer_policy() == 'no-referrer'
	assert settings.serialize().policy_container.referrer_policy == .no_referrer
	assert container.csp_list.len == 2
	assert container.csp_list.map(it.source) == [.header, .meta]
	assert container.csp_list[0].pre_parsed_policy_string == "img-src 'self'"
	mut request := fetch.Request.create()
	request.set_client(settings)
	request.set_url(dom.URL{'https://request-referrer-owner.test/image.png'})
	request.destination = .image
	fetch.populate_request_from_client(mut request)
	assert request.resolved_policy_container?.referrer_policy == 'no-referrer'
}

fn test_source_meta_referrer_exact_tokens_and_historical_last_modified_owner() {
	mut document, _, settings := source_referrer_document('https://tokens-referrer-owner.test/page', "img-src 'self'", 'strict-origin')!
	defer { document.finalize() }
	container := document.policy_container()
	head := document.head()?
	mut first := source_referrer_meta(document, 'REFERRER', 'NEVER')!
	source_referrer_append(head.as_node(), first)!
	assert container.referrer_policy == .no_referrer
	mut last := source_referrer_meta(document, 'referrer', 'ALWAYS')!
	source_referrer_append(head.as_node(), last)!
	assert container.referrer_policy == .unsafe_url
	for token, policy in {
		'DEFAULT':                         dom.ReferrerPolicy.strict_origin_when_cross_origin
		'origin-when-crossorigin':         dom.ReferrerPolicy.origin_when_cross_origin
		'NO-REFERRER-WHEN-DOWNGRADE':      dom.ReferrerPolicy.no_referrer_when_downgrade
		'SAME-ORIGIN':                     dom.ReferrerPolicy.same_origin
		'ORIGIN':                          dom.ReferrerPolicy.origin
		'STRICT-ORIGIN':                   dom.ReferrerPolicy.strict_origin
		'ORIGIN-WHEN-CROSS-ORIGIN':        dom.ReferrerPolicy.origin_when_cross_origin
		'STRICT-ORIGIN-WHEN-CROSS-ORIGIN': dom.ReferrerPolicy.strict_origin_when_cross_origin
		'UNSAFE-URL':                      dom.ReferrerPolicy.unsafe_url
		'NO-REFERRER':                     .no_referrer
	} {
		first.set_attribute_value('content', token)
		assert container.referrer_policy == policy
		assert settings.fetch_request_client_policy_container().referrer_policy == policy.to_string()
	}
	first.set_attribute_value('content', 'origin')
	last.set_attribute_value('content', 'same-origin')
	first.set_attribute_value('id', 'most-recent-referrer')
	assert container.referrer_policy == .origin
	assert voidptr(document.get_element_by_id('most-recent-referrer')?) == voidptr(first)
	first.set_attribute_value('name', 'other-metadata')
	assert container.referrer_policy == .origin
	mut first_node := first.as_node()
	first_node.remove(false)
	mut last_node := last.as_node()
	last_node.remove(false)
	assert container.referrer_policy == .origin
	assert container.csp_list.len == 1
}

fn test_source_meta_referrer_guards_use_exact_name_content_and_document_tree() {
	mut document, _, _ := source_referrer_document('https://guards-referrer-owner.test/page', "img-src 'self'", 'strict-origin')!
	defer { document.finalize() }
	container := document.policy_container()
	body := document.body()?
	for name in [' referrer', 'referrer '] {
		source_referrer_append(body.as_node(), source_referrer_meta(document, name, 'never')!)!
	}
	for content in ['', ' never', 'never ', 'invalid', 'NÉVER'] {
		source_referrer_append(body.as_node(), source_referrer_meta(document, 'referrer', content)!)!
	}
	mut missing := document.create_element('meta')!
	missing.set_attribute_value('name', 'referrer')
	source_referrer_append(body.as_node(), missing)!
	mut foreign := document.create_element_ns('urn:foreign', 'meta')!
	foreign.set_attribute_value('name', 'referrer')
	foreign.set_attribute_value('content', 'never')
	source_referrer_append(body.as_node(), foreign)!
	disconnected := document.create_element('div')!
	source_referrer_append(disconnected.as_node(), source_referrer_meta(document, 'referrer', 'never')!)!
	mut host := document.create_element('div')!
	source_referrer_append(body.as_node(), host)!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	shadow_meta := source_referrer_meta(document, 'referrer', 'never')!
	source_referrer_append(unsafe { &dom.Node(shadow) }, shadow_meta)!
	assert shadow_meta.as_node().is_connected() && !shadow_meta.as_node().in_a_document_tree()
	assert container.referrer_policy == .strict_origin
	source_referrer_append(body.as_node(), source_referrer_meta(document, 'referrer', 'origin')!)!
	assert container.referrer_policy == .origin
}

fn test_source_meta_referrer_uses_own_document_during_window_reassociation_and_adoption() {
	mut original, mut window, settings := source_referrer_document('https://old-referrer-owner.test/page', "img-src 'self'", 'strict-origin')!
	mut replacement, _, replacement_settings := source_referrer_document('https://new-referrer-owner.test/page', "style-src 'self'", 'origin')!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	old_container := original.policy_container()
	new_container := replacement.policy_container()
	window.set_associated_document(replacement)
	assert voidptr(settings.policy_container()) == voidptr(new_container)
	mut meta := source_referrer_meta(original, 'referrer', 'never')!
	old_head := original.head()?
	source_referrer_append(old_head.as_node(), meta)!
	assert voidptr(meta.document()) == voidptr(original)
	assert old_container.referrer_policy == .no_referrer
	assert new_container.referrer_policy == .origin
	assert settings.fetch_request_client_policy_container().referrer_policy == 'origin'
	meta.set_attribute_value('content', 'same-origin')
	assert old_container.referrer_policy == .same_origin
	assert new_container.referrer_policy == .origin
	new_head := replacement.head()?
	source_referrer_append(new_head.as_node(), meta)!
	assert voidptr(meta.document()) == voidptr(replacement)
	assert old_container.referrer_policy == .same_origin
	assert new_container.referrer_policy == .same_origin
	meta.set_attribute_value('content', 'always')
	assert new_container.referrer_policy == .unsafe_url
	assert old_container.referrer_policy == .same_origin
	assert replacement_settings.serialize().policy_container.referrer_policy == .unsafe_url
	assert old_container.csp_list.len == 1 && new_container.csp_list.len == 1
}
