module html

import dom
import fetch
import http
import page

fn source_csp_policy_owner_document(address string) !(&dom.Document, &EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	install_document_csp_hook(document)
	window := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(window) }.environment_settings_.settings
}

fn source_csp_policy_owner_headers(mut settings EnvironmentSettingsObject, document &dom.Document, enforce string, report string) {
	mut response := fetch.Response.create()
	response.url_list = [document.url]
	if enforce != '' {
		response.header_list.append(http.Header{ name: 'Content-Security-Policy', value: enforce })
	}
	if report != '' {
		response.header_list.append(http.Header{ name: 'Content-Security-Policy-Report-Only', value: report })
	}
	settings.set_policy_container(create_a_policy_container_from_fetch_response(response))
}

fn test_source_document_inline_csp_uses_header_owner_and_preserves_policy_order_once() {
	mut document, mut settings := source_csp_policy_owner_document('https://policy-owner.test/page')!
	defer { document.finalize() }
	source_csp_policy_owner_headers(mut settings, document,
		"style-src 'none'; trusted-types header-name",
		"script-src-attr 'none'; trusted-types report-name")
	document.enforce_meta_csp("style-src 'unsafe-inline'; trusted-types stale-name")
	policies := document_csp_policies(document)
	assert policies.len == 2
	assert policies[0].source() == .header && policies[0].disposition() == .enforce
	assert policies[1].source() == .header && policies[1].disposition() == .report
	assert policies[0].self_origin?.serialize() == document.origin().serialize()
	assert policies[1].self_origin?.serialize() == document.origin().serialize()
	style := document.create_element('style')!
	assert document.should_block_inline_content(style, 'style', 'body { color: red }')
	button := document.create_element('button')!
	assert !document.should_block_inline_content(button, 'script-attribute', 'allowed()')
	trusted := trusted_types_meta_policies(document)
	assert trusted.len == 2
	assert trusted[0].trusted_types? == ['header-name']
	assert trusted[1].trusted_types? == ['report-name']
	assert trusted[0].disposition == .enforce && trusted[1].disposition == .report_only
	document.run_csp_initialization()
}

fn test_source_csp_current_document_settings_replace_stale_strings_and_follow_adoption() {
	mut original, mut old_settings := source_csp_policy_owner_document('https://old-policy-owner.test/page')!
	mut replacement, mut new_settings := source_csp_policy_owner_document('https://new-policy-owner.test/page')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	original.enforce_meta_csp("script-src-attr 'none'")
	assert document_csp_policies(original).len == 0
	mut button := original.create_element('button')!
	assert !original.should_block_inline_content(button, 'script-attribute', 'allowed()')
	source_csp_policy_owner_headers(mut old_settings, original, "script-src-attr 'none'", '')
	assert original.should_block_inline_content(button, 'script-attribute', 'blocked()')
	source_csp_policy_owner_headers(mut new_settings, replacement, "script-src-attr 'unsafe-inline'", '')
	body := replacement.body()?
	mut body_node := body.as_node()
	body_node.append_child(button.as_node())!
	assert voidptr(button.document()) == voidptr(replacement)
	assert !replacement.should_block_inline_content(button, 'script-attribute', 'allowed()')
	assert document_csp_policies(replacement)[0].self_origin?.serialize() == replacement.origin().serialize()
}

fn test_source_standalone_csp_adapter_retains_meta_string_inline_and_trusted_types() {
	mut document := parse_document('<!doctype html><button id="button"></button>')
	defer { document.finalize() }
	assert document.relevant_settings_object() == unsafe { nil }
	document.enforce_meta_csp("script-src-attr 'none'; trusted-types standalone-name")
	button := document.get_element_by_id('button')?
	assert document.should_block_inline_content(button, 'script-attribute', 'blocked()')
	policies := document_csp_policies(document)
	assert policies.len == 1 && policies[0].source() == .meta
	assert trusted_types_meta_policies(document)[0].trusted_types? == ['standalone-name']
	document.run_csp_initialization()
}
