module main

import html
import dom
import platform

fn test_static_document_heap_counts_elements_and_skips_scripted_or_text_only_documents() {
	mut document := html.parse_document('<!doctype html><div>' + 'large text '.repeat(8000) + '</div>')
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_scripting_enabled_by_embedder(false)
	assert static_document_heap_element_count(document) == 4
	assert !prepare_static_document_render_heap(document)
	document.set_scripting_enabled_by_embedder(true)
	assert document.as_node().is_scripting_enabled()
	assert static_document_heap_element_count(document) == 0
}

fn test_static_document_heap_stops_at_the_large_document_threshold() {
	mut document := html.parse_document('<!doctype html>' + '<span></span>'.repeat(1200))
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_scripting_enabled_by_embedder(false)
	assert static_document_heap_element_count(document) == platform.static_document_heap_element_threshold
	document.set_scripting_enabled_by_embedder(true)
	assert document.as_node().is_scripting_enabled()
	assert static_document_heap_element_count(document) == 0
}
