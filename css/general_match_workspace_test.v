module css

import dom
import platform

fn workspace_match_append(parent &dom.Node, child &dom.Element) {
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(child.as_node()) or { panic(err) }
}

fn test_general_query_workspaces_keep_parsed_selectors_and_read_live_relations() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	defer {
		allocations.finish()
		document.finalize()
		document.release_native_storage()
	}
	root := document.create_element('main')!
	mut child := document.create_element('span')!
	child.set_attribute_value('class', 'target')
	workspace_match_append(document.as_node(), root)
	workspace_match_append(root.as_node(), child)
	selectors := ['main > .target:first-child', ':scope > span:not([hidden])',
		'main:has(> .target)', 'main:has(> .missing)']
	for source in selectors { _ = document_query_selector_list(document, source) or { panic(source) } }
	hook := document.selector_query_hook() or { panic('missing query hook') }
	scope := unsafe { &dom.ParentNode(root) }
	parsed := document_query_selector_list(document, selectors[0]) or { panic('missing parsed selector') }
	before_control := platform.thread_arena_usage().used
	for _ in 0 .. 512 {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		assert matches(parsed.selectors[0], child, none, mut context, none, scope, .normal, none)
	}
	control := platform.thread_arena_usage().used - before_control
	// Warm optional name/attribute access before measuring repeat calls.
	assert element_matches_selector(root, selectors[2])
	before := platform.thread_arena_usage().used
	for _ in 0 .. 512 {
		assert dom_selector_query_matches(hook.target, selectors[0], child, scope)
		assert dom_selector_query_matches(hook.target, selectors[1], child, scope)
		assert element_matches_selector(root, selectors[2])
		assert !element_matches_selector(root, selectors[3])
	}
	retained := platform.thread_arena_usage().used - before
	$if prealloc {
		assert retained < 4096, '${retained} retained query bytes'
		assert control > retained + 16 * 1024
		println('GENERAL_MATCH_STORAGE control=${control} candidate=${retained}')
	}
	for _ in 0 .. 3 {
		reuse := platform.begin_thread_scratch('overwrite general matching work')
		_ = []u8{len: 256 * 1024, init: 0xa5}
		reuse.finish()
	}
	child.set_attribute_value('class', 'missing')
	assert !element_matches_selector(root, selectors[2])
	assert element_matches_selector(root, selectors[3])
	assert !dom_selector_query_matches(hook.target, selectors[0], child, scope)
	assert dom_selector_query_matches(hook.target, selectors[1], child, scope)
	child.set_attribute_value('hidden', '')
	assert !dom_selector_query_matches(hook.target, selectors[1], child, scope)
}

fn test_stylesheet_match_probes_retire_property_vectors_and_contexts() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	root := document.create_element('main')!
	mut child := document.create_element('span')!
	child.set_attribute_value('class', 'target')
	child.set_attribute_value('data-key', 'retained')
	workspace_match_append(document.as_node(), root)
	workspace_match_append(root.as_node(), child)
	list := parse_selector_with_parser('main > .target:first-child[data-key="retained"]',
		map[string]bool{}) or { panic('invalid selector') }
	mut set := InvalidationSet{}
	set.set_needs_invalidate_class('target')
	set.set_needs_invalidate_attribute('data-key')
	mut cache := RuleCache.new()
	cache.add_rule(&MatchingRule{selector: list.selectors[0]}, none, false)
	assert style_sheet_element_matches_anchor_rule(child, set, list.selectors[0], none, none, none)
	assert static_user_style_subject_matches(child, cache)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 512 {
		assert style_sheet_element_matches_anchor_rule(child, set, list.selectors[0], none, none, none)
		assert !style_sheet_element_matches_anchor_rule(root, set, list.selectors[0], none, none, none)
		assert static_user_style_subject_matches(child, cache)
		assert !static_user_style_subject_matches(root, cache)
	}
	retained := platform.thread_arena_usage().used - before
	$if prealloc { assert retained < 4096, '${retained} retained invalidation probe bytes' }
	reuse := platform.begin_thread_scratch('overwrite invalidation matching work')
	_ = []u8{len: 256 * 1024, init: 0xa5}
	reuse.finish()
	child.set_attribute_value('data-key', 'changed')
	assert !style_sheet_element_matches_anchor_rule(child, set, list.selectors[0], none, none, none)
	assert !static_user_style_subject_matches(child, cache)
	child.set_attribute_value('data-key', 'retained')
	assert style_sheet_element_matches_anchor_rule(child, set, list.selectors[0], none, none, none)
	assert static_user_style_subject_matches(child, cache)
}
