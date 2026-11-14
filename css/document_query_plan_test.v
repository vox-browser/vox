module css

import dom
import platform

fn plan_element(document &dom.Document, parent &dom.Node, name string) &dom.Element {
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
	mut parent_node := unsafe { &dom.Node(parent) }
	parent_node.append_child(child.as_node()) or { panic(err) }
	return child
}

fn test_query_plans_reuse_only_syntax_and_keep_dom_results_live() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := plan_element(document, document.as_node(), 'main')
	mut child := plan_element(document, root.as_node(), 'span')
	child.set_attribute_value('class', 'target')
	text := 'span.target, [data-live]'
	first := document_query_plan(document, text) or { panic('plan') }
	address := u64(voidptr(first))
	if first.independent == none { panic('independent plan missing') }
	for _ in 0 .. 8 {
		again := document_query_plan(document, text) or { panic('cached plan') }
		actual_address := u64(voidptr(again))
		assert actual_address == address
		assert query_selector_all(document.as_node(), text).len == 1
		assert child.matches(text)!
	}
	child.remove_attribute('class')
	assert query_selector_all(document.as_node(), text).len == 0
	assert !child.matches(text)!
	child.set_attribute_value('data-live', '')
	assert query_selector_all(document.as_node(), text).len == 1
	parent := unsafe { &dom.ParentNode(root) }
	assert parent.query_selector_all(text)!.length() == 1
	assert closest_matching_selector(child, text) != none
}

fn test_query_plan_metadata_survives_the_first_callers_scratch_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut child := plan_element(document, document.as_node(), 'span')
	child.set_attribute_value('data-label', 'λ😀')
	text := 'span[data-label="λ😀"], .absent'
	work := platform.begin_thread_scratch('first selector plan caller')
	borrowed := text.clone()
	first := document_query_plan(document, borrowed) or { panic('first plan') }
	address := u64(voidptr(first))
	work.finish()
	for _ in 0 .. 4 {
		churn := platform.begin_thread_scratch('first selector plan caller')
		_ = []u8{len: 256 * 1024, init: 0xa5}
		churn.finish()
		gc_collect()
	}
	cached := document_query_plan(document, text) or { panic('lost plan') }
	actual_address := u64(voidptr(cached))
	assert actual_address == address
	assert child.matches(text)!
	child.set_attribute_value('data-label', 'changed')
	assert !child.matches(text)!
	assert query_selector_all(document.as_node(), text).len == 0
}

fn test_general_query_plans_preserve_scope_relations_and_cached_failures() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := plan_element(document, document.as_node(), 'main')
	mut child := plan_element(document, root.as_node(), 'span')
	for text in ['main > span', ':scope', 'main:has(> .active)', 'span, main > span'] {
		plan := document_query_plan(document, text) or { panic(text) }
		if plan.independent != none { panic('general selector classified independent') }
	}
	assert root.matches(':scope')!
	assert !root.matches('main:has(> .active)')!
	child.set_attribute_value('class', 'active')
	assert root.matches('main:has(> .active)')!
	assert query_selector_all(root.as_node(), 'main > span.active').len == 1
	child.remove_attribute('class')
	assert query_selector_all(root.as_node(), 'main > span.active').len == 0
	for text in ['[', 'span,', ':not('] {
		for _ in 0 .. 2 { assert document_query_plan(document, text) == none }
	}
	hook := document.selector_query_hook() or { panic('hook') }
	state := unsafe { &DocumentSelectorQueryState(hook.target) }
	assert state.invalid.len == 3
	for text in ['[', 'span,', ':not('] { assert text !in state.plans }
}

fn test_query_plans_keep_document_owners_and_namespace_classification_separate() {
	mut first := dom.Document.create(dom.url_about_blank())
	mut second := dom.Document.create(dom.url_about_blank())
	defer { first.finalize(); second.finalize() }
	install_document_selector_query_hook(first)
	install_document_selector_query_hook(second)
	first_hook := first.selector_query_hook() or { panic('first hook') }
	second_hook := second.selector_query_hook() or { panic('second hook') }
	mut first_state := unsafe { &DocumentSelectorQueryState(first_hook.target) }
	mut second_state := unsafe { &DocumentSelectorQueryState(second_hook.target) }
	for text in ['span', 'svg|rect', '[svg|href]', ':is(svg|rect, span)'] {
		// DOM queries do not declare namespace prefixes. Seed the same parsed
		// representation used by a CSS parser with a declared prefix.
		first_state.parsed[text] = parse_selector_with_parser(text, {'svg': true}) or { panic(text) }
		second_state.parsed[text] = parse_selector_with_parser(text, {'svg': true}) or { panic(text) }
		a := document_query_plan(first, text) or { panic(text) }
		b := document_query_plan(second, text) or { panic(text) }
		a_address := u64(voidptr(a))
		b_address := u64(voidptr(b))
		assert a_address != b_address
		assert a.named_namespace == selector_list_contains_named_namespace(a.selectors)
		assert a.named_namespace == (text != 'span')
	}
}

fn test_warm_query_plan_reuses_compound_storage_without_allocating() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	plan := document_query_plan(document, 'span.target[data-live], .other') or { panic('plan') }
	_ = plan.independent_compounds() or { panic('independent plan') }
	mut before := u64(0)
	$if prealloc { before = platform.thread_arena_usage().used }
	$if gcboehm ? { before = gc_heap_usage().total_bytes }
	for _ in 0 .. 512 {
		_ = plan.independent_compounds() or { panic('lost independent plan') }
	}
	mut after := before
	$if prealloc { after = platform.thread_arena_usage().used }
	$if gcboehm ? { after = gc_heap_usage().total_bytes }
	growth := after - before
	if document_query_plan_diagnostics { eprintln('Vox query-plan allocation: recompute=${recompute_document_query_plans} growth=${growth}') }
	$if prealloc {
		if recompute_document_query_plans { assert growth >= 512 * u64(sizeof(CompoundSelector)) }
		else { assert growth == 0 }
	}
	$if gcboehm ? {
		if recompute_document_query_plans { assert growth >= 512 * u64(sizeof(CompoundSelector)) }
		else { assert growth == 0 }
	}
}

// Plans made only of names, IDs and classes match without a workspace outside
// quirks mode; attribute selectors and quirks-mode documents keep it. The
// answers equal the general matcher's either way.
fn test_scalar_query_plans_match_like_the_general_matcher_in_both_modes() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(.html)
		if quirks { document.set_quirks_mode(.yes) }
		mut root := document.create_element('main')!
		root.set_attribute_value('class', 'Pane wide')
		root.set_attribute_value('id', 'Root')
		root.set_attribute_value('data-k', 'v')
		mut document_node := document.as_node()
		_ = document_node.append_child(root.as_node())!
		install_document_selector_query_hook(document)
		hook := document.selector_query_hook() or { panic('missing selector hook') }
		mut state := unsafe { &DocumentSelectorQueryState(hook.target) }
		for selector, scalar in {
			'main':            true
			'MAIN':            true
			'lazy-element':    true
			'*':               true
			'.Pane':           true
			'.pane':           true
			'#Root':           true
			'#root':           true
			'main.wide#Root':  true
			'lazy-one, main':  true
			'[data-k]':        false
			'main[data-k=v]':  false
			'main:not(.x)':    false
			'body main':       false
		} {
			plan := state.query_plan(selector) or { panic(selector) }
			assert plan.scalar == scalar, selector
			assert plan.matches_without_workspace(document) == (scalar && !quirks && !retain_scalar_query_scratch), selector
			expected := general_query_matches(root, plan.selectors, none)
			assert element_matches_query_plan(root, plan, none) == expected, '${selector} quirks=${quirks}'
			assert root.matches(selector)! == expected, '${selector} quirks=${quirks}'
		}
		// Quirks mode folds class and ID case; standards mode does not.
		assert root.matches('.pane')! == quirks
		assert root.matches('#root')! == quirks
	}
}

fn test_require_document_selector_reports_the_matches_error() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut root := document.create_element('main')!
	mut document_node := document.as_node()
	_ = document_node.append_child(root.as_node())!
	for selector in ['main', 'lazy-element', 'a > b', ':not(.x)', '[data-k="v"]'] {
		require_document_selector(document, selector)!
	}
	for selector in ['[', ':unknown-pseudo', '', 'a >', '>>']{
		mut reported := ''
		require_document_selector(document, selector) or { reported = err.msg() }
		mut matched := ''
		_ = root.matches(selector) or { matched = err.msg(); false }
		assert reported != '' && reported == matched, selector
	}
}
