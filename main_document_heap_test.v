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

fn test_markup_start_tags_size_the_heap_before_the_first_parse() {
	// A tag-like run inside a comment also counts; the hint only needs a bound.
	assert markup_start_tag_count('<!doctype html><html><body><p>a < b</p><!-- <x> --></body>') == 4
	assert markup_start_tag_count('</div> <? x ?> <1 <') == 0
	assert markup_start_tag_count('<span></span>'.repeat(1200)) == platform.document_heap_element_threshold
	assert !prepare_markup_render_heap('<!doctype html><p>small</p>', true)
}

fn test_script_disabled_documents_skip_heap_hints_before_and_after_parsing() {
	markup := '<!doctype html>' + '<span></span>'.repeat(1200)
	assert !prepare_markup_render_heap(markup, false)
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_scripting_enabled_by_embedder(false)
	assert !prepare_document_render_heap(document)
	assert !document.as_node().is_scripting_enabled()
	assert css.query_selector_all(document.as_node(), 'span').len == 1200
}
