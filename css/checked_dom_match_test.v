module css

import dom
import os
import platform

fn test_dom_matches_keeps_live_selector_lists_scope_and_errors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := document.create_element('main')!
	mut child := document.create_element('span')!
	document.as_node().append_child(root.as_node())!
	root.as_node().append_child(child.as_node())!
	child.set_attribute_value('class', 'target')
	install_document_selector_query_hook(document)
	assert root.matches(':scope:has(> .target)')!
	assert child.matches('p, main > span.target')!
	assert child.matches(':scope')!
	child.remove_attribute('class')
	assert !root.matches(':scope:has(> .target)')!
	assert !child.matches('p, main > span.target')!
	for selector in ['', '[', 'span,', ':is('] {
		mut rejected := false
		child.matches(selector) or {
			rejected = err.msg() == 'SyntaxError: Failed to parse selector'
		}
		assert rejected, selector
	}
}

@[heap]
struct MatchFallbackObservations {
mut:
	validations int
	namespaces int
	matches int
}

fn observed_match_validation(target voidptr, selector string) bool {
	mut observations := unsafe { &MatchFallbackObservations(target) }
	observations.validations++
	return selector != '['
}

fn observed_match_namespace(target voidptr, _ string) bool {
	mut observations := unsafe { &MatchFallbackObservations(target) }
	observations.namespaces++
	return false
}

fn observed_match_callback(target voidptr, selector string, element &dom.Element, scope &dom.ParentNode) bool {
	mut observations := unsafe { &MatchFallbackObservations(target) }
	observations.matches++
	return selector == 'span, main' && voidptr(scope) == voidptr(element)
}

fn test_dom_matches_preserves_foreign_bridge_validation_and_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('span')!
	observations := &MatchFallbackObservations{}
	document.set_selector_query_hook(dom.DocumentSelectorQueryHook{
		target: observations
		validate: observed_match_validation
		contains_named_namespace: observed_match_namespace
		matches: observed_match_callback
	})
	assert element.matches('span, main')!
	assert observations.validations == 1 && observations.namespaces == 1 && observations.matches == 1
	element.matches('[') or {}
	assert observations.validations == 2 && observations.namespaces == 1 && observations.matches == 1
}

fn test_cached_dom_matches_do_not_retain_per_call_selector_vectors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('span')!
	element.set_attribute_value('class', 'target')
	install_document_selector_query_hook(document)
	selectors := ['span.target', '.missing', ':scope']
	for selector in selectors { _ = element.matches(selector)! }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		for index, selector in selectors {
			assert element.matches(selector)! == (index != 1)
		}
	}
	growth := platform.thread_arena_usage().used - before
	$if prealloc {
		if os.getenv('VOX_DISABLE_CHECKED_SELECTOR_MATCHES') == '' {
			assert growth < 1024, 'cached boolean queries retained ${growth} bytes'
		}
	}
}

fn test_first_dom_match_keeps_its_parsed_selector_after_argument_scratch_retires() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('span')!
	element.set_attribute_value('data-label', 'borrowed')
	install_document_selector_query_hook(document)
	work := platform.begin_thread_scratch('first DOM match argument')
	selector := 'span[data-label="borrowed"]'.clone()
	assert element.matches(selector)!
	work.finish()
	for _ in 0 .. 3 {
		reuse := platform.begin_thread_scratch('first DOM match argument')
		_ = []u8{len: 256 * 1024, init: 0xa5}
		reuse.finish()
		gc_collect()
	}
	assert element.matches('span[data-label="borrowed"]')!
	element.set_attribute_value('data-label', 'changed')
	assert !element.matches('span[data-label="borrowed"]')!
}

fn test_dom_matches_preserves_svg_names_and_xml_case() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.xml)
	svg := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	gradient := document.create_element_ns('http://www.w3.org/2000/svg', 'linearGradient')!
	document.as_node().append_child(svg.as_node())!
	svg.as_node().append_child(gradient.as_node())!
	install_document_selector_query_hook(document)
	assert gradient.matches('linearGradient')!
	assert gradient.matches(':scope')!
	assert gradient.matches('svg > linearGradient')!
	assert !gradient.matches('lineargradient')!
	assert !svg.matches('linearGradient')!
}
