module html

import contentsecuritypolicy
import dom
import fetch
import http
import page

@[heap]
struct SourceBaseCSPObservation {
mut:
	violations []string
}

fn source_base_csp_document(owner &page.Page, address string) !(&dom.Document, &EnvironmentSettingsObject, &EventLoop) {
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	window := document.get_window() or { return error('missing actual Window') }
	mut settings := unsafe { &WindowModel(window) }.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	return document, settings, loop
}

fn source_base_csp_headers(mut settings EnvironmentSettingsObject, document &dom.Document, enforce string, report string) {
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

fn source_base_csp_observe(document &dom.Document) &SourceBaseCSPObservation {
	observation := &SourceBaseCSPObservation{}
	target := unsafe { &dom.EventTarget(document) }
	target.add_event_listener_without_options('securitypolicyviolation', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation, document] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('actual violation target') }) == voidptr(document)
			assert event.is_trusted() && event.type_name() == 'securitypolicyviolation'
			violation := unsafe { &contentsecuritypolicy.SecurityPolicyViolationEvent(event) }
			mut observed := unsafe { &SourceBaseCSPObservation(observation) }
			observed.violations << '${violation.disposition()}:${violation.blocked_uri()}:${violation.effective_directive()}'
			return dom.js_undefined()
		}
	}))
	return observation
}

fn source_base_csp_run_queued_violations(loop &EventLoop) {
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable() or { break }
		assert task.source() == .unspecified && task.document() == none
		task.execute()
	}
}

fn source_base_csp_append(document &dom.Document, href string) !&dom.Element {
	mut base := document.create_element('base')!
	base.set_attribute_value('href', href)
	head := document.head() or { return error('missing actual head') }
	mut head_node := head.as_node()
	head_node.append_child(base.as_node())!
	return base
}

fn test_source_native_base_csp_gate_reaches_real_header_policy_before_any_parser() {
	owner := page.Page.create(1)!
	mut document, mut settings, loop := source_base_csp_document(owner, 'https://base-csp.test/root/page.html')!
	defer { document.finalize() }
	source_base_csp_headers(mut settings, document, "base-uri 'none'", '')
	observation := source_base_csp_observe(document)
	base := source_base_csp_append(document, 'https://foreign-base.test/assets/')!
	assert voidptr(document.first_base_element_with_href_in_tree_order()?) == voidptr(base)
	assert unsafe { &dom.HTMLBaseElement(base) }.frozen_base_url_initialized_
	assert document.base_url() == document.fallback_base_url()
	assert observation.violations.len == 0
	source_base_csp_run_queued_violations(loop)
	assert observation.violations == ['enforce:inline:base-uri']
}

fn test_source_base_csp_self_gate_and_url_short_circuits_use_current_actual_settings() {
	owner := page.Page.create(1)!
	mut document, mut settings, loop := source_base_csp_document(owner, 'https://base-csp.test/root/page.html')!
	defer { document.finalize() }
	source_base_csp_headers(mut settings, document, "base-uri 'self'", '')
	observation := source_base_csp_observe(document)
	mut base := source_base_csp_append(document, 'assets/')!
	assert document.base_url().serialize() == 'https://base-csp.test/root/assets/'
	assert loop.task_queue().last_added_task() == none
	base.set_attribute_value('href', 'https://foreign-base.test/')
	assert document.base_url() == document.fallback_base_url()
	for value in ['data:text/html,blocked', 'javascript:blocked()', 'http://[invalid'] {
		base.set_attribute_value('href', value)
		assert document.base_url() == document.fallback_base_url()
	}
	source_base_csp_run_queued_violations(loop)
	assert observation.violations == ['enforce:inline:base-uri']
}

fn test_source_base_csp_report_only_reports_and_missing_base_uri_does_not_block() {
	owner := page.Page.create(1)!
	mut document, mut settings, loop := source_base_csp_document(owner, 'https://base-csp.test/root/page.html')!
	defer { document.finalize() }
	source_base_csp_headers(mut settings, document, "default-src 'none'", "base-uri 'none'")
	observation := source_base_csp_observe(document)
	source_base_csp_append(document, 'https://foreign-base.test/report-only/')!
	assert document.base_url().serialize() == 'https://foreign-base.test/report-only/'
	assert observation.violations.len == 0
	source_base_csp_run_queued_violations(loop)
	assert observation.violations == ['report:inline:base-uri']
}

fn test_source_adopted_base_csp_gate_reads_actual_destination_document_settings() {
	old_owner := page.Page.create(1)!
	new_owner := page.Page.create(1)!
	mut original, mut old_settings, old_loop := source_base_csp_document(old_owner, 'https://old-base-csp.test/root/page.html')!
	mut replacement, mut new_settings, new_loop := source_base_csp_document(new_owner, 'https://new-base-csp.test/other/page.html')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	source_base_csp_headers(mut old_settings, original, "base-uri 'none'", '')
	source_base_csp_headers(mut new_settings, replacement, "base-uri 'self'", '')
	old_observation := source_base_csp_observe(original)
	new_observation := source_base_csp_observe(replacement)
	base := source_base_csp_append(original, 'assets/')!
	assert original.base_url() == original.fallback_base_url()
	head := replacement.head()?
	mut head_node := head.as_node()
	head_node.append_child(base.as_node())!
	assert voidptr(base.document()) == voidptr(replacement)
	assert replacement.base_url().serialize() == 'https://new-base-csp.test/other/assets/'
	assert voidptr(replacement.page()) == voidptr(new_owner)
	source_base_csp_run_queued_violations(old_loop)
	source_base_csp_run_queued_violations(new_loop)
	assert old_observation.violations == ['enforce:inline:base-uri']
	assert new_observation.violations.len == 0
}

fn test_source_parser_csp_installer_retains_base_check_for_real_fragment_created_element() {
	owner := page.Page.create(1)!
	mut document, mut settings, loop := source_base_csp_document(owner, 'https://base-csp.test/root/page.html')!
	defer { document.finalize() }
	source_base_csp_headers(mut settings, document, "base-uri 'none'", '')
	mut document_node := document.as_node()
	document_node.replace_all(none)
	parse_html_from_a_string(document, '<!doctype html><html><head></head><body>real parser</body></html>')
	observation := source_base_csp_observe(document)
	mut head := unsafe { &dom.Element(document.head()?) }
	head.set_inner_html('<base href="https://foreign-base.test/fragment/">')!
	assert document.first_base_element_with_href_in_tree_order() != none
	assert document.base_url() == document.fallback_base_url()
	source_base_csp_run_queued_violations(loop)
	assert observation.violations == ['enforce:inline:base-uri']
}
