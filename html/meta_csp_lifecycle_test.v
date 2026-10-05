module html

import dom
import fetch
import http
import page

fn source_meta_document(address string, header string) !(&dom.Document, &EnvironmentSettingsObject, &EventLoop) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	window := document.get_window() or { return error('missing actual Window') }
	mut settings := unsafe { &WindowModel(window) }.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	mut response := fetch.Response.create()
	response.url_list = [document.url]
	if header != '' {
		response.header_list.append(http.Header{ name: 'Content-Security-Policy', value: header })
	}
	settings.set_policy_container(create_a_policy_container_from_fetch_response(response))
	return document, settings, loop
}

fn source_meta_element(document &dom.Document, keyword string, content string) !&dom.Element {
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('http-equiv', keyword)
	meta.set_attribute_value('content', content)
	return meta
}

fn source_meta_append(parent &dom.Node, element &dom.Element) ! {
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node())!
}

fn test_source_meta_insertion_appends_filtered_policy_once_to_actual_header_container() {
	mut document, settings, _ := source_meta_document('https://meta-owner.test/root/page', "script-src 'self'")!
	defer { document.finalize() }
	container := settings.policy_container()
	raw := "report-uri /report; frame-ancestors 'none'; sandbox; img-src 'none'; style-src 'none'; STYLE-SRC 'unsafe-inline'"
	head := document.head()?
	head_node := head.as_node()
	meta := source_meta_element(document, 'CONTENT-SECURITY-POLICY', raw)!
	assert container.csp_list.len == 1
	source_meta_append(head_node, meta)!
	assert voidptr(settings.policy_container()) == voidptr(container)
	assert container.csp_list.len == 2
	assert container.csp_list[0].source == .header
	policy := container.csp_list[1]
	assert policy.source == .meta && policy.disposition == .enforce
	assert policy.pre_parsed_policy_string == raw
	assert policy.self_origin.serialize_for_ipc() == document.origin().serialize_for_ipc()
	assert policy.directives.map(it.name) == ['img-src', 'style-src']
	assert policy.directives[1].value == ["'none'"]
	assert document.enforced_meta_csp_policies().len == 1
	assert document_csp_policies(document).len == 2
	install_document_csp_hook(document)
	style := document.create_element('style')!
	assert document.should_block_inline_content(style, 'style', 'body { color: red }')
	mut request := fetch.Request.create()
	request.set_client(settings)
	request.set_url(dom.URL{value: 'https://meta-owner.test/image.png'})
	request.destination = .image
	fetch.populate_request_from_client(mut request)
	assert settings.fetch_request_client_policy_container().csp_list.policies.len == 2
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response {
			panic('Meta CSP must block before transport')
		}
	}).response()?
	assert response.is_network_error()
}

fn test_source_meta_csp_guards_use_document_tree_html_head_and_exact_keyword() {
	mut document, settings, _ := source_meta_document('https://meta-guards.test/page', '')!
	defer { document.finalize() }
	container := settings.policy_container()
	head := document.head()?
	head_node := head.as_node()
	body := document.body()?
	body_node := body.as_node()
	disconnected_head := document.create_element('head')!
	source_meta_append(disconnected_head.as_node(), source_meta_element(document, 'content-security-policy', "default-src 'none'")!)!
	source_meta_append(body_node, source_meta_element(document, 'content-security-policy', "default-src 'none'")!)!
	foreign_head := document.create_element_ns('urn:foreign', 'head')!
	source_meta_append(body_node, foreign_head)!
	source_meta_append(foreign_head.as_node(), source_meta_element(document, 'content-security-policy', "default-src 'none'")!)!
	mut host := document.create_element('div')!
	source_meta_append(body_node, host)!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	shadow_head := document.create_element('head')!
	source_meta_append(unsafe { &dom.Node(shadow) }, shadow_head)!
	shadow_meta := source_meta_element(document, 'content-security-policy', "default-src 'none'")!
	source_meta_append(shadow_head.as_node(), shadow_meta)!
	assert shadow_meta.as_node().is_connected() && !shadow_meta.as_node().in_a_document_tree()
	mut shadow_referrer := document.create_element('meta')!
	shadow_referrer.set_attribute_value('name', 'referrer')
	shadow_referrer.set_attribute_value('content', 'never')
	source_meta_append(shadow_head.as_node(), shadow_referrer)!
	assert document.meta_referrer_policy() == ''
	for keyword in [' content-security-policy', 'content-security-policy '] {
		source_meta_append(head_node, source_meta_element(document, keyword, "default-src 'none'")!)!
	}
	source_meta_append(head_node, source_meta_element(document, 'content-security-policy', '')!)!
	mut missing_content := document.create_element('meta')!
	missing_content.set_attribute_value('http-equiv', 'content-security-policy')
	source_meta_append(head_node, missing_content)!
	mut foreign_meta := document.create_element_ns('urn:foreign', 'meta')!
	foreign_meta.set_attribute_value('http-equiv', 'content-security-policy')
	foreign_meta.set_attribute_value('content', "default-src 'none'")
	source_meta_append(head_node, foreign_meta)!
	assert container.csp_list.len == 0
	valid := source_meta_element(document, 'Content-Security-Policy', "default-src 'none'")!
	source_meta_append(head_node, valid)!
	assert container.csp_list.len == 1
	assert voidptr(valid.document()) == voidptr(document)
}

fn test_source_meta_attribute_changes_do_not_reenforce_and_adoption_uses_current_owner() {
	mut original, old_settings, _ := source_meta_document('https://old-meta-owner.test/page', "img-src 'self'")!
	mut replacement, new_settings, _ := source_meta_document('https://new-meta-owner.test/page', "script-src 'self'")!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut meta := source_meta_element(original, 'content-security-policy', "style-src 'none'")!
	old_head := original.head()?
	new_head := replacement.head()?
	source_meta_append(old_head.as_node(), meta)!
	assert old_settings.policy_container().csp_list.len == 2
	meta.set_attribute_value('content', "base-uri 'none'")
	meta.set_attribute_value('id', 'real-meta')
	assert voidptr(original.get_element_by_id('real-meta')?) == voidptr(meta)
	assert old_settings.policy_container().csp_list.len == 2
	mut meta_node := meta.as_node()
	meta_node.remove(false)
	assert old_settings.policy_container().csp_list.len == 2
	source_meta_append(new_head.as_node(), meta)!
	assert voidptr(meta.document()) == voidptr(replacement)
	assert old_settings.policy_container().csp_list[1].self_origin.serialize_for_ipc() == original.origin().serialize_for_ipc()
	policies := new_settings.policy_container().csp_list
	assert policies.len == 2 && policies[0].source == .header && policies[1].source == .meta
	assert policies[1].directives[0].name == 'base-uri'
	assert policies[1].self_origin.serialize_for_ipc() == replacement.origin().serialize_for_ipc()
}

fn test_source_full_parser_meta_enforcement_precedes_actual_base_freeze() {
	mut document, settings, loop := source_meta_document('https://parser-meta.test/root/page', "img-src 'self'")!
	defer { document.finalize() }
	container := settings.policy_container()
	mut document_node := document.as_node()
	document_node.replace_all(none)
	parse_html_from_a_string(document, '<!doctype html><html><head><meta http-equiv="content-security-policy" content="base-uri \'none\'"><base href="https://foreign-base.test/assets/"></head><body>real parser</body></html>')
	assert voidptr(settings.policy_container()) == voidptr(container)
	assert container.csp_list.len == 2
	assert document.base_url() == document.fallback_base_url()
	mut queue := loop.task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable() or { break }
		assert task.source() == .unspecified && task.document() == none
		task.execute()
		count++
	}
	assert count == 1
}

fn test_source_meta_metadata_changes_reach_actual_document_and_keep_referrer_removal_effect() {
	mut document, _, _ := source_meta_document('https://meta-metadata.test/page', '')!
	defer { document.finalize() }
	head := document.head()?
	head_node := head.as_node()
	mut language := source_meta_element(document, 'content-language', '\t en-GB trailing')!
	source_meta_append(head_node, language)!
	assert document.pragma_set_default_language_value()? == 'en-GB'
	comma_language := source_meta_element(document, 'content-language', 'en,fr')!
	source_meta_append(head_node, comma_language)!
	assert document.pragma_set_default_language_value()? == 'en-GB'
	vertical_tab_language := source_meta_element(document, 'content-language', '\ven trailing')!
	source_meta_append(head_node, vertical_tab_language)!
	assert document.pragma_set_default_language_value()? == '\ven'
	mut referrer := document.create_element('meta')!
	referrer.set_attribute_value('name', 'referrer')
	referrer.set_attribute_value('content', 'NEVER')
	source_meta_append(head_node, referrer)!
	assert document.meta_referrer_policy() == 'no-referrer'
	referrer.set_attribute_value('content', 'ALWAYS')
	assert document.meta_referrer_policy() == 'unsafe-url'
	mut referrer_node := referrer.as_node()
	referrer_node.remove(false)
	assert document.meta_referrer_policy() == 'unsafe-url'
	mut scheme := document.create_element('meta')!
	scheme.set_attribute_value('name', 'color-scheme')
	scheme.set_attribute_value('content', 'only light')
	source_meta_append(head_node, scheme)!
	assert document.supported_color_schemes()? == ['light']
	assert document.supported_color_schemes_are_only()
	scheme.set_attribute_value('content', 'dark')
	assert document.supported_color_schemes()? == ['dark']
	assert !document.supported_color_schemes_are_only()
	mut scheme_node := scheme.as_node()
	scheme_node.remove(false)
	assert document.supported_color_schemes() == none
}

fn test_source_meta_retains_empty_filtered_policy_and_genuine_opaque_origin_snapshot() {
	mut document, settings, _ := source_meta_document('https://opaque-meta.test/page', '')!
	defer { document.finalize() }
	document.set_origin(dom.origin_create_opaque())
	raw := "sandbox; report-uri /report; frame-ancestors 'none'"
	meta := source_meta_element(document, 'content-security-policy', raw)!
	head := document.head()?
	source_meta_append(head.as_node(), meta)!
	policies := settings.policy_container().csp_list
	assert policies.len == 1 && policies[0].directives.len == 0
	assert policies[0].pre_parsed_policy_string == raw
	assert policies[0].self_origin.serialize_for_ipc() == document.origin().serialize_for_ipc()
	assert policies[0].self_origin.is_opaque()
}

fn test_source_standalone_parser_meta_adapter_uses_filtered_translated_csp_policy() {
	mut document := parse_document('<!doctype html><html><head><meta http-equiv="content-security-policy" content="style-src \'none\'; sandbox; frame-ancestors \'none\'; report-uri /report"><style id="style">body { color: red }</style></head><body>standalone</body></html>')
	defer { document.finalize() }
	assert document.relevant_settings_object() == unsafe { nil }
	policies := document_csp_policies(document)
	assert policies.len == 1
	assert policies[0].source() == .meta && policies[0].disposition() == .enforce
	assert policies[0].directives().map(it.name()) == ['style-src']
	style := document.get_element_by_id('style')?
	assert document.should_block_inline_content(style, 'style', 'body { color: red }')
}

fn test_source_real_meta_refresh_insertion_uses_existing_declarative_refresh_steps() {
	mut document, _, _ := source_meta_document('https://refresh-meta.test/page', '')!
	defer { document.finalize() }
	head := document.head()?
	source_meta_append(head.as_node(), source_meta_element(document, ' refresh ', '5; url=/wrong')!)!
	assert document.last_declarative_refresh_input() == none
	meta := source_meta_element(document, 'ReFrEsH', '5; url=/next')!
	source_meta_append(head.as_node(), meta)!
	assert document.last_declarative_refresh_input()? == '5; url=/next'
	assert document.will_declaratively_refresh
	assert document.active_refresh_timer != unsafe { nil }
}

@[heap]
struct SourceMetaRemovalObservation {
mut:
	calls           int
	is_subtree_root dom.NodeIsSubtreeRoot
	old_ancestor    ?&dom.Node
	old_root        ?&dom.Node
}

fn source_meta_record_removal(target voidptr, is_subtree_root dom.NodeIsSubtreeRoot, old_ancestor ?&dom.Node, old_root &dom.Node) {
	mut observation := unsafe { &SourceMetaRemovalObservation(target) }
	observation.calls++
	observation.is_subtree_root = is_subtree_root
	observation.old_ancestor = old_ancestor
	observation.old_root = old_root
}

fn test_source_meta_removal_keeps_actual_parent_context_once_for_subtree_and_direct_removal() {
	mut document, _, _ := source_meta_document('https://removal-meta.test/page', '')!
	defer { document.finalize() }
	head := document.head()?
	wrapper := document.create_element('div')!
	meta := document.create_element('meta')!
	mut meta_node := meta.as_node()
	observation := &SourceMetaRemovalObservation{}
	meta_node.set_lifecycle_hook(dom.NodeLifecycleHook{
		target:       voidptr(observation)
		removed_from: source_meta_record_removal
	})
	source_meta_append(wrapper.as_node(), meta)!
	source_meta_append(head.as_node(), wrapper)!
	mut wrapper_node := wrapper.as_node()
	wrapper_node.remove(false)
	assert observation.calls == 1 && observation.is_subtree_root == .no
	assert voidptr(observation.old_ancestor?) == voidptr(head)
	assert voidptr(observation.old_root?) == voidptr(document)
	source_meta_append(head.as_node(), meta)!
	mut mutable_observation := unsafe { &SourceMetaRemovalObservation(observation) }
	mutable_observation.calls = 0
	meta_node.remove(false)
	assert observation.calls == 1 && observation.is_subtree_root == .yes
	assert voidptr(observation.old_ancestor?) == voidptr(head)
	assert voidptr(observation.old_root?) == voidptr(document)
}
