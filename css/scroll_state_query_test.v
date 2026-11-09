module css

import dom

fn scroll_query_for_test(text string) &ContainerQuery {
	rule := parse_css_rule_with_params(ParsingParams{}, '@container ${text} {}') or { panic(text) }
	return rule.container_conditions[0].container_query or { panic('missing query') }
}

fn test_scroll_state_query_grammar_serialization_and_unknown_features() {
	for name in ['scrollable', 'scrolled', 'snapped', 'stuck'] {
		query := scroll_query_for_test('scroll-STate(  ${name}: NONE)')
		assert query.to_string() == 'scroll-state(${name}: none)'
		assert query.feature_requirements.requires_scroll_state_container
		assert !query.feature_requirements.has_unknown_or_unsupported_feature
	}
	logical := scroll_query_for_test('scroll-state(( scrollable: LEFT) OR (SCROLLABLE: BOTTOM))')
	assert logical.to_string() == 'scroll-state((scrollable: left) or (scrollable: bottom))'
	for invalid in ['scroll-STate(scrollable:    )', 'scroll-state(scrollable: auto)', 'scroll-state(style(scrollable: left))'] {
		query := scroll_query_for_test(invalid)
		assert query.feature_requirements.has_unknown_or_unsupported_feature
	}
}

fn test_scroll_state_queries_use_frozen_snapshots_and_logical_container_axes() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(subject.as_node())!
	parent.set_attribute_value('style', 'container-type:scroll-state;writing-mode:vertical-rl;direction:rtl')
	computer := css_style_computer_for(document)
	parent.set_computed_properties(none, computed_properties_to_dom(computer.compute_style(dom.AbstractElement.new(parent, none))))
	query := scroll_query_for_test('scroll-state(scrollable: inline-end)')
	assert query.evaluate(dom.AbstractElement.new(subject, none), none) == .false_
	mut entry := scroll_state_query_container(parent)
	assert publish_scroll_state_query_snapshot(mut entry, ScrollStateQuerySnapshot{scrollable: 1})
	assert query.evaluate(dom.AbstractElement.new(subject, none), none) == .true_
	assert !publish_scroll_state_query_snapshot(mut entry, ScrollStateQuerySnapshot{scrollable: 1})
}
