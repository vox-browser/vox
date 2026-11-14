module css

import dom
import platform

fn test_independent_query_results_and_cached_selectors_survive_workspace_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_quirks_mode(.yes)
	root := document.create_element('main')!
	document.as_node().append_child(root.as_node())!
	mut expected := []&dom.Element{}
	for index in 0 .. 160 {
		mut child := document.create_element('span')!
		child.set_attribute_value('class', 'TARGET')
		child.set_attribute_value('data-key', 'Value ${index}')
		root.as_node().append_child(child.as_node())!
		expected << child
	}
	selector := '.target[data-key^="value " i], span'
	// The first query installs its document cache before entering scratch.
	results := query_selector_all(root.as_node(), selector)
	first := query_selector(root.as_node(), selector) or { panic('missing first') }
	dom_results := unsafe { &dom.ParentNode(root.as_node()) }.query_selector_all(selector)!
	assert results.len == expected.len && dom_results.length() == expected.len
	for _ in 0 .. 3 {
		reuse := platform.begin_thread_scratch('reuse independent DOM query')
		_ = []u8{len: 256 * 1024, init: 0xa5}
		reuse.finish()
		gc_collect()
	}
	assert voidptr(first) == voidptr(expected[0])
	for index, element in expected {
		assert voidptr(results[index]) == voidptr(element)
		assert voidptr(dom_results.item(index) or { panic('lost retained node') }) == voidptr(element.as_node())
	}
	// Reusing the parsed graph after retirement must still read live DOM state.
	mut changed := unsafe { &dom.Element(expected[0]) }
	changed.set_attribute_value('data-key', 'Changed')
	again := query_selector_all(root.as_node(), '.target[data-key^="value " i]')
	assert again.len == expected.len - 1
	assert query_selector_all(root.as_node(), selector).len == expected.len
	assert query_selector_all(root.as_node(), 'main > span:first-child').len == 1
}

fn test_independent_queries_keep_only_the_final_result_vector() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_quirks_mode(.yes)
	root := document.create_element('main')!
	document.as_node().append_child(root.as_node())!
	for _ in 0 .. 512 {
		mut child := document.create_element('span')!
		child.set_attribute_value('class', 'TARGET')
		root.as_node().append_child(child.as_node())!
	}
	selector := '.target, span'
	_ = document_query_selector_list(document, selector) or { panic('invalid selector') }
	before := platform.thread_arena_usage().used
	results := query_selector_all(root.as_node(), selector)
	after := platform.thread_arena_usage().used
	assert results.len == 512
	$if prealloc {
		assert after - before <= results.len * int(sizeof(voidptr)) + 1024
	}
	first_before := platform.thread_arena_usage().used
	assert query_selector(root.as_node(), selector) != none
	first_after := platform.thread_arena_usage().used
	$if prealloc {
		assert first_after - first_before < 256
	}
}
