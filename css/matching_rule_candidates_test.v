module css

import dom
import platform

fn candidate_scratch_element(document &dom.Document, name string, classes string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic('invalid candidate fixture')
	}
	element.set_attribute_value('class', classes)
	return element
}

fn candidate_rule_snapshot(rules []ScopedMatchingRule) []string {
	return rules.map('${it.rule.selector.serialize()}:${it.rule.rule_index}:${it.rule.specificity}:${it.scope_proximity}')
}

fn test_matching_query_reuses_context_for_rejected_candidates() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := candidate_scratch_element(document, 'div', '')
	computer := StyleComputer.new(document)
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing author cache') }
	selectors := parse_selector_with_parser('div:hover', map[string]bool{}) or { panic('invalid hover fixture') }
	rule := &MatchingRule{selector:selectors.selectors[0]}
	cache.rules_by_tag_name['div'] = []&MatchingRule{len:1024, init:rule}
	mut attempted := PseudoClassBitmap{}
	abstract := dom.AbstractElement.new(element, none)
	assert style_computer_collect_matching_rules_in_scope(computer, abstract, .author, mut attempted, none, scope).len == 0
	assert attempted.get(.hover)
	assert computer.matching_rule_candidates_.buffers[0].context.subject == none
	assert computer.matching_rule_candidates_.buffers[0].context.has_result_cache == unsafe { nil }
	assert computer.matching_rule_candidates_.buffers[0].context.short_attribute_match_owner == unsafe { nil }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 4 {
		assert style_computer_collect_matching_rules_in_scope(computer, abstract, .author, mut attempted, none, scope).len == 0
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}

fn test_candidate_scratch_reuses_storage_without_retaining_rules_or_aliasing_outputs() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computer := StyleComputer.new(document)
	mut host := candidate_scratch_element(document, 'div', '')
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut first := computer.acquire_matching_rule_candidates()
	mut candidates := unsafe { first.rules }
	rule := &MatchingRule{
		rule_index: 73
	}
	candidates << ScopedMatchingRule{
		rule:            rule
		shadow_root:     shadow
	}
	output := candidates.clone()
	storage := candidates.data
	computer.release_matching_rule_candidates(mut first, candidates)
	assert first.rules.data == storage
	assert first.rules.len == 0
	assert first.rules.cap > 0
	for byte_index in 0 .. int(sizeof(ScopedMatchingRule)) {
		assert unsafe { (&u8(storage))[byte_index] } == 0
	}
	for _ in 0 .. 3 {
		gc_collect()
		assert voidptr(output[0].rule) == voidptr(rule)
		assert voidptr(output[0].shadow_root or { panic('lost candidate shadow') }) == voidptr(shadow)
		mut next := computer.acquire_matching_rule_candidates()
		assert voidptr(next) == voidptr(first)
		assert next.rules.data == storage
		computer.release_matching_rule_candidates(mut next, next.rules)
	}
	assert computer.matching_rule_candidates_.active_depth == 0
}

fn test_public_matching_query_uses_separate_nested_scratch_and_keeps_scoped_output_live() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := candidate_scratch_element(document, 'html', '')
	mut feed := candidate_scratch_element(document, 'section', 'feed')
	mut story := candidate_scratch_element(document, 'article', 'story')
	content := candidate_scratch_element(document, 'span', 'content')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(feed.as_node())!
	mut feed_node := feed.as_node()
	feed_node.append_child(story.as_node())!
	mut story_node := story.as_node()
	story_node.append_child(content.as_node())!
	add_document_author_style_sheet(document,
		'.story{color:red}.story:has(>.content){background:blue}.story::before{content:""}@scope(.feed){.story{opacity:.5}}.story{&>.content{color:green}}')
	mut computer := StyleComputer.new(document)
	computer.push_ancestor(root)
	computer.push_ancestor(feed)
	mut outer := computer.acquire_matching_rule_candidates()
	mut outer_candidates := unsafe { outer.rules }
	sentinel := &MatchingRule{
		rule_index: 911
	}
	outer_candidates << ScopedMatchingRule{
		rule: sentinel
	}
	mut attempted := PseudoClassBitmap{}
	scope := css_style_scope_for_document(document)
	output := style_computer_collect_matching_rules_in_scope(computer,
		dom.AbstractElement.new(story, none), .author, mut attempted, none, scope)
	// The nesting parent contributes its own .story matching rule as well.
	assert output.len == 4
	mut scoped_count := 0
	for matched in output {
		if resolved := matched.resolved_scope_root {
			scoped_count++
			assert voidptr(resolved) == voidptr(feed)
			assert matched.scope_proximity == 1
		} else {
			assert matched.scope_proximity == 0x3fffffff
		}
	}
	assert scoped_count == 1
	assert computer.matching_rule_candidates_.active_depth == 1
	assert computer.matching_rule_candidates_.buffers.len == 2
	assert computer.matching_rule_candidates_.buffers[1].rules.len == 0
	assert output.data != computer.matching_rule_candidates_.buffers[1].rules.data
	assert voidptr(outer_candidates[0].rule) == voidptr(sentinel)
	snapshot := candidate_rule_snapshot(output)
	for _ in 0 .. 3 {
		_ = style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(content, none), .author, mut attempted, none, scope)
		gc_collect()
		assert candidate_rule_snapshot(output) == snapshot
		assert voidptr(outer_candidates[0].rule) == voidptr(sentinel)
	}
	computer.release_matching_rule_candidates(mut outer, outer_candidates)
	assert computer.matching_rule_candidates_.active_depth == 0
	computed := computer.compute_style(dom.AbstractElement.new(story, none))
	assert computed.opacity() == f32(.5)
	assert computed.property(.color, .no)?.css_text == 'rgb(255, 0, 0)'
	assert candidate_rule_snapshot(output) == snapshot
}

fn test_candidate_scratch_bounds_retained_depth_and_capacity_without_limiting_queries() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computer := StyleComputer.new(document)
	mut active := []&MatchingRuleCandidateBuffer{}
	for _ in 0 .. max_matching_rule_candidate_buffers + 2 {
		active << computer.acquire_matching_rule_candidates()
	}
	assert computer.matching_rule_candidates_.buffers.len == max_matching_rule_candidate_buffers
	for index := active.len - 1; index >= 0; index-- {
		mut buffer := active[index]
		rules := [
			ScopedMatchingRule{
				rule: &MatchingRule{
					rule_index: uint(index)
				}
			},
		]
		computer.release_matching_rule_candidates(mut buffer, rules)
		if index >= max_matching_rule_candidate_buffers {
			assert buffer.rules.cap == 0
		}
	}
	assert computer.matching_rule_candidates_.active_depth == 0
	mut large := computer.acquire_matching_rule_candidates()
	oversized := []ScopedMatchingRule{len: max_retained_matching_rule_candidates + 1}
	computer.release_matching_rule_candidates(mut large, oversized)
	assert large.rules.cap == 0
	mut next := computer.acquire_matching_rule_candidates()
	small := [ScopedMatchingRule{ rule: &MatchingRule{ rule_index: 314 } }]
	computer.release_matching_rule_candidates(mut next, small)
	assert next.rules.cap > 0
	assert computer.matching_rule_candidates_.active_depth == 0
}

fn test_candidate_scratch_clears_grown_prefix_and_retains_cloned_rule_and_shadow_identity() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut first_host := candidate_scratch_element(document, 'div', '')
	mut second_host := candidate_scratch_element(document, 'section', '')
	first_shadow := first_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	second_shadow := second_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	computer := StyleComputer.new(document)
	mut buffer := computer.acquire_matching_rule_candidates()
	mut candidates := unsafe { buffer.rules }
	for index in 0 .. 257 {
		candidates << ScopedMatchingRule{
			rule: &MatchingRule{rule_index: uint(index)}
			shadow_root: if index % 3 == 0 { ?&dom.ShadowRoot(first_shadow) } else if index % 3 == 1 { ?&dom.ShadowRoot(second_shadow) } else { none }
		}
	}
	assert candidates.cap >= 257
	retained := candidates.clone()
	storage := candidates.data
	computer.release_matching_rule_candidates(mut buffer, candidates)
	assert buffer.rules.len == 0
	assert buffer.rules.cap >= 257
	assert buffer.rules.data == storage
	for byte_index in 0 .. 257 * int(sizeof(ScopedMatchingRule)) {
		assert unsafe { (&u8(storage))[byte_index] } == 0
	}
	for _ in 0 .. 3 {
		gc_collect()
		for index, candidate in retained {
			assert candidate.rule.rule_index == uint(index)
			if index > 0 { assert voidptr(candidate.rule) != voidptr(retained[index - 1].rule) }
			if index % 3 == 0 {
				assert voidptr(candidate.shadow_root or { panic('lost first shadow') }) == voidptr(first_shadow)
			} else if index % 3 == 1 {
				assert voidptr(candidate.shadow_root or { panic('lost second shadow') }) == voidptr(second_shadow)
			} else {
				assert candidate.shadow_root == none
			}
		}
		mut next := computer.acquire_matching_rule_candidates()
		assert voidptr(next) == voidptr(buffer)
		assert next.rules.data == storage
		computer.release_matching_rule_candidates(mut next, next.rules)
	}
	assert computer.matching_rule_candidates_.active_depth == 0
}
