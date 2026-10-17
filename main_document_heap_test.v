module main

import css
import html
import dom
import platform

fn test_document_heap_counts_elements_independently_of_scripting_policy() {
	mut document := html.parse_document('<!doctype html><div>' + 'large text '.repeat(8000) + '</div>')
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_scripting_enabled_by_embedder(false)
	assert document_heap_element_count(document) == 4
	assert !prepare_document_render_heap(document)
	document.set_scripting_enabled_by_embedder(true)
	assert document.as_node().is_scripting_enabled()
	assert document_heap_element_count(document) == 4
}

fn test_document_heap_stops_at_the_large_document_threshold() {
	mut document := html.parse_document('<!doctype html>' + '<span></span>'.repeat(1200))
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_scripting_enabled_by_embedder(false)
	assert document_heap_element_count(document) == platform.document_heap_element_threshold
	document.set_scripting_enabled_by_embedder(true)
	assert document.as_node().is_scripting_enabled()
	assert document_heap_element_count(document) == platform.document_heap_element_threshold
	_ = prepare_document_render_heap(document)
	assert document.as_node().is_scripting_enabled()
	assert css.query_selector_all(document.as_node(), 'span').len == 1200
}
