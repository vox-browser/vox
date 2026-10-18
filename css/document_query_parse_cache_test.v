module css

import dom

fn query_cache_test_element(document &dom.Document, parent &dom.Node) &dom.Element {
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node()) or { panic(err) }
	return element
}

fn test_css_and_dom_queries_share_parsing_but_observe_live_matching_state() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := query_cache_test_element(document, document.as_node())
	selector := 'span.target[data-active]'
	assert !element_matches_selector(element, selector)
	hook := document.selector_query_hook() or { panic('missing hook') }
	state := unsafe { &DocumentSelectorQueryState(hook.target) }
	first := state.parsed[selector].selectors[0].data_
	element.set_attribute_value('class', 'target')
	element.set_attribute_value('data-active', '')
	assert element_matches_selector(element, selector)
	assert voidptr(query_selector(document.as_node(), selector) or { panic('missing match') }) == voidptr(element)
	assert query_selector_all(document.as_node(), selector).len == 1
	assert voidptr(closest_matching_selector(element, selector) or { panic('missing closest') }) == voidptr(element)
	assert hook.matches(hook.target, selector, element, unsafe { &dom.ParentNode(document) })
	gc_collect()
	assert voidptr(state.parsed[selector].selectors[0].data_) == voidptr(first)
	element.remove_attribute('data-active')
	assert !element_matches_selector(element, selector)
	assert query_selector_all(document.as_node(), selector).len == 0
	assert state.parsed.len == 1
}

fn test_document_query_caches_are_separate_and_keep_relational_results_live() {
	mut one := dom.Document.create(dom.url_about_blank())
	mut two := dom.Document.create(dom.url_about_blank())
	defer { one.finalize(); two.finalize() }
	parent := query_cache_test_element(one, one.as_node())
	mut child := query_cache_test_element(one, parent.as_node())
	other := query_cache_test_element(two, two.as_node())
	selector := 'span:has(> .active)'
	assert !element_matches_selector(parent, selector)
	child.set_attribute_value('class', 'active')
	assert element_matches_selector(parent, selector)
	assert !element_matches_selector(other, selector)
	first_hook := one.selector_query_hook() or { panic('first') }
	second_hook := two.selector_query_hook() or { panic('second') }
	assert first_hook.target != second_hook.target
	child.set_attribute_value('class', '')
	assert !element_matches_selector(parent, selector)
	for invalid in ['[', 'span,', ':not('] {
		assert query_selector(one.as_node(), invalid) == none
		assert query_selector_all(one.as_node(), invalid).len == 0
	}
	state := unsafe { &DocumentSelectorQueryState(first_hook.target) }
	assert state.invalid.len == 3
}

fn test_repeated_css_queries_do_not_reparse_long_attribute_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := query_cache_test_element(document, document.as_node())
	value := 'q'.repeat(4096)
	element.set_attribute_value('data-label', value)
	selector := '[data-label="${value}"]'
	$if gcboehm ? {
		before := gc_heap_usage().total_bytes
		assert voidptr(query_selector(document.as_node(), selector) or { panic('missing match') }) == voidptr(element)
		parsed_bytes := gc_heap_usage().total_bytes - before
		warm_before := gc_heap_usage().total_bytes
		for _ in 0 .. 8 { assert voidptr(query_selector(document.as_node(), selector) or { panic('missing match') }) == voidptr(element) }
		warm_bytes := gc_heap_usage().total_bytes - warm_before
		assert warm_bytes < parsed_bytes, 'cached=${warm_bytes}, parsed=${parsed_bytes}'
	} $else {
		for _ in 0 .. 9 { assert voidptr(query_selector(document.as_node(), selector) or { panic('missing match') }) == voidptr(element) }
	}
}
