module css

import dom

fn has_cache_test_element(document &dom.Document, tag string, class_name string) &dom.Element {
	mut element := document.create_element(tag) or { panic(err) }
	element.set_attribute_value('class', class_name)
	return element
}

fn has_cache_test_append(parent &dom.Node, child &dom.Element) {
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(child.as_node()) or { panic(err) }
}

fn has_cache_test_selector(source string) Selector {
	list := parse_selector_with_parser(source, map[string]bool{}) or { panic(source) }
	return list.selectors[0]
}

fn test_has_result_cache_is_shared_across_matching_contexts_and_growth() {
	document := dom.Document.create(dom.url_about_blank())
	mut computer := css_style_computer_for(document)
	selector := has_cache_test_selector('.anchor:has(> .flag)')
	negative_selector := has_cache_test_selector('.anchor:not(:has(> .missing))')
	mut anchors := []&dom.Element{}
	for index in 0 .. 192 {
		anchor := has_cache_test_element(document, 'section', 'anchor')
		child := has_cache_test_element(document, 'span', if index % 2 == 0 { 'flag' } else { '' })
		has_cache_test_append(anchor.as_node(), child)
		anchors << anchor
		mut context := MatchContext{
			has_result_cache: style_scope_has_result_cache_boundary(computer)
		}
		assert matches(selector, anchor, none, mut context, none, none, .normal, none) == (index % 2 == 0)
		assert matches(negative_selector, anchor, none, mut context, none, none, .normal, none)
		assert computer.has_result_cache_.results.len == (index + 1) * 2
	}
	// Later contexts must see every positive and negative entry after the map grows.
	for index, anchor in anchors {
		mut context := MatchContext{
			has_result_cache: style_scope_has_result_cache_boundary(computer)
		}
		assert matches(selector, anchor, none, mut context, none, none, .normal, none) == (index % 2 == 0)
		assert matches(negative_selector, anchor, none, mut context, none, none, .normal, none)
	}
	assert computer.has_result_cache_.results.len == anchors.len * 2
	computer.reset_has_result_cache()
	assert computer.has_result_cache_.results.len == 0
}

fn test_has_result_cache_reset_reaches_existing_contexts() {
	document := dom.Document.create(dom.url_about_blank())
	mut computer := css_style_computer_for(document)
	anchor := has_cache_test_element(document, 'section', 'anchor')
	mut child := has_cache_test_element(document, 'span', 'flag')
	has_cache_test_append(anchor.as_node(), child)
	selector := has_cache_test_selector('.anchor:has(> .flag)')
	mut context := MatchContext{
		has_result_cache: style_scope_has_result_cache_boundary(computer)
	}
	assert matches(selector, anchor, none, mut context, none, none, .normal, none)
	child.set_attribute_value('class', '')
	assert matches(selector, anchor, none, mut context, none, none, .normal, none)
	computer.reset_has_result_cache()
	assert !matches(selector, anchor, none, mut context, none, none, .normal, none)
	assert computer.has_result_cache_.results.len == 1
	child.set_attribute_value('class', 'flag')
	computer.reset_has_result_cache()
	assert matches(selector, anchor, none, mut context, none, none, .normal, none)
}

fn test_has_result_cache_in_style_passes_and_live_mutation() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	css_style_computer_for(document)
	root := has_cache_test_element(document, 'html', '')
	has_cache_test_append(document.as_node(), root)
	add_document_author_style_sheet(document,
		'.anchor:has(> .flag) { color: red } .anchor:not(:has(> .flag)) { color: blue }')
	mut anchors := []&dom.Element{}
	mut children := []&dom.Element{}
	for index in 0 .. 128 {
		anchor := has_cache_test_element(document, 'section', 'anchor')
		child := has_cache_test_element(document, 'span', if index % 2 == 0 { 'flag' } else { '' })
		has_cache_test_append(anchor.as_node(), child)
		has_cache_test_append(root.as_node(), anchor)
		anchors << anchor
		children << child
	}
	document.update_style()
	for index, anchor in anchors {
		expected_color := if index % 2 == 0 { 'rgb(255, 0, 0)' } else { 'rgb(0, 0, 255)' }
		assert computed_value_for(anchor, .color) or { '' } == expected_color
	}
	for index, child in children {
		mut mutable_child := unsafe { &dom.Element(child) }
		mutable_child.set_attribute_value('class', if index % 2 == 0 { '' } else { 'flag' })
	}
	document.update_style()
	for index, anchor in anchors {
		expected_color := if index % 2 == 0 { 'rgb(0, 0, 255)' } else { 'rgb(255, 0, 0)' }
		assert computed_value_for(anchor, .color) or { '' } == expected_color
		assert element_matches_selector(anchor, '.anchor:has(> .flag)') == (index % 2 != 0)
	}
}

fn test_has_cache_hits_preserve_attempted_pseudo_classes_for_each_subject() {
	document := dom.Document.create(dom.url_about_blank())
	anchor := has_cache_test_element(document, 'section', 'anchor')
	trigger := has_cache_test_element(document, 'button', 'trigger')
	first := has_cache_test_element(document, 'span', 'target')
	second := has_cache_test_element(document, 'span', 'target')
	has_cache_test_append(anchor.as_node(), trigger)
	has_cache_test_append(anchor.as_node(), first)
	has_cache_test_append(anchor.as_node(), second)
	selector := has_cache_test_selector('.anchor:has(.trigger:hover) .target')
	mut cache := &HasResultCache{}
	mut first_context := MatchContext{
		has_result_cache: cache
	}
	assert !matches(selector, first, none, mut first_context, none, none, .normal, none)
	assert first_context.attempted_pseudo_class_matches.get(.hover)
	mut second_context := MatchContext{
		has_result_cache: cache
	}
	assert !matches(selector, second, none, mut second_context, none, none, .normal, none)
	assert second_context.attempted_pseudo_class_matches.get(.hover)
	assert second_context.attempted_pseudo_class_matches.get(.has)
	assert cache.results.len == 1
}

fn test_hover_has_invalidation_keeps_old_and_new_results_separate() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	css_style_computer_for(document)
	root := has_cache_test_element(document, 'html', '')
	anchor := has_cache_test_element(document, 'section', 'anchor')
	trigger := has_cache_test_element(document, 'button', 'trigger')
	has_cache_test_append(document.as_node(), root)
	has_cache_test_append(root.as_node(), anchor)
	has_cache_test_append(anchor.as_node(), trigger)
	mut targets := []&dom.Element{}
	for _ in 0 .. 192 {
		target := has_cache_test_element(document, 'span', 'target')
		has_cache_test_append(anchor.as_node(), target)
		targets << target
	}
	add_document_author_style_sheet(document,
		'.target { color: blue } .anchor:has(.trigger:hover) .target { color: red }')
	document.update_style()
	for target in targets {
		assert target.affected_by_pseudo_class(.hover)
		assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	}
	document.set_hovered_node(trigger.as_node())
	for target in targets {
		assert target.needs_style_update()
	}
	document.update_style()
	for target in targets {
		assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	}
	document.set_hovered_node(none)
	document.update_style()
	for target in targets {
		assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	}
}
