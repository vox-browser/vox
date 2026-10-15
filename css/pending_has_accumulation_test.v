module css

import dom

fn pending_has_test_scope(source string) &StyleScope {
	document := dom.Document.create(dom.url_about_blank())
	mut sheet := parse_css_stylesheet_with_parser(source, none)
	sheet.add_owning_document_or_shadow_root(document.as_node())
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()
	return scope
}

fn pending_has_test_assert_equal(actual &PendingHasInvalidationMutationFeatures, expected &PendingHasInvalidationMutationFeatures) {
	assert actual.is_conservative == expected.is_conservative
	assert actual.may_affect_sibling_relationships == expected.may_affect_sibling_relationships
	assert actual.may_affect_pseudo_classes == expected.may_affect_pseudo_classes
	assert actual.tag_names.len == expected.tag_names.len
	for key, _ in expected.tag_names { assert actual.tag_names[key] }
	assert actual.ids.len == expected.ids.len
	for key, _ in expected.ids { assert actual.ids[key] }
	assert actual.class_names.len == expected.class_names.len
	for key, _ in expected.class_names { assert actual.class_names[key] }
	assert actual.attribute_names.len == expected.attribute_names.len
	for key, _ in expected.attribute_names { assert actual.attribute_names[key] }
	assert actual.pseudo_classes.len == expected.pseudo_classes.len
	for key, _ in expected.pseudo_classes { assert actual.pseudo_classes[key] }
}

fn test_pending_has_repeated_node_and_subtree_recording_matches_original_merge() {
	document := dom.Document.create(dom.url_about_blank())
	parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	root.set_attribute_value('id', 'root-id')
	root.set_attribute_value('class', 'root-class')
	mut child := document.create_element_ns('http://www.w3.org/2000/svg', 'linearGradient') or { panic(err) }
	child.set_attribute_value('id', 'child-id')
	child.set_attribute_value('class', 'svg-class')
	child.set_attribute_value('viewBox', '0 0 10 10')
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	mut actual := StyleScope.new(document.as_node())
	mut oracle := StyleScope.new(document.as_node())
	for descendants in [false, true, false] {
		actual.record_pending_has_invalidation_mutation_features(parent.as_node(), root.as_node(), descendants)
		features := collect_pending_has_invalidation_mutation_features(root.as_node(), descendants)
		oracle.record_pending_has_invalidation_features(parent.as_node(), features)
		got := actual.pending_has_invalidation_features[parent.as_node().unique_id().value()] or { panic('missing actual features') }
		expected := oracle.pending_has_invalidation_features[parent.as_node().unique_id().value()] or { panic('missing oracle features') }
		pending_has_test_assert_equal(got, expected)
		if !descendants && !got.may_affect_sibling_relationships { assert !got.ids['child-id'] }
	}
	gc_collect()
	got := actual.pending_has_invalidation_features[parent.as_node().unique_id().value()] or { panic('missing features') }
	assert got.ids['root-id'] && got.ids['child-id']
	assert got.tag_names['linearGradient'] && got.tag_names['lineargradient']
	assert got.attribute_names['viewBox'] && got.attribute_names['viewbox']
	assert got.may_affect_sibling_relationships && got.may_affect_pseudo_classes
	assert actual.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
}

fn test_pending_has_accumulation_keeps_queue_order_and_cleared_generations_independent() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'aside') or { panic(err) }
	mut a := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a') or { panic(err) }
	a.set_attribute_value('class', 'first-class')
	mut b := document.create_element_ns('http://www.w3.org/1999/xhtml', 'b') or { panic(err) }
	b.set_attribute_value('class', 'second-class')
	mut scope := StyleScope.new(document.as_node())
	scope.record_pending_has_invalidation_mutation_features(first.as_node(), a.as_node(), true)
	retained := scope.pending_has_invalidation_features[first.as_node().unique_id().value()] or { panic('missing retained features') }
	scope.record_pending_has_invalidation_mutation_features(second.as_node(), b.as_node(), false)
	scope.record_pending_has_invalidation_mutation_features(first.as_node(), b.as_node(), false)
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 2
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[0].unique_id() == first.as_node().unique_id()
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[1].unique_id() == second.as_node().unique_id()
	assert retained.class_names['first-class'] && retained.class_names['second-class']
	scope.clear_pending_has_invalidations()
	scope.record_pending_has_invalidation_mutation_features(first.as_node(), b.as_node(), false)
	current := scope.pending_has_invalidation_features[first.as_node().unique_id().value()] or { panic('missing current features') }
	gc_collect()
	assert voidptr(current) != voidptr(retained)
	assert !current.class_names['first-class'] && current.class_names['second-class']
	assert !current.may_affect_sibling_relationships
	assert retained.class_names['first-class'] && retained.may_affect_sibling_relationships
}

fn test_pending_has_node_accumulation_preserves_conservative_and_property_features() {
	document := dom.Document.create(dom.url_about_blank())
	parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or { panic(err) }
	child.set_attribute_value('class', 'new-class')
	mut scope := StyleScope.new(document.as_node())
	scope.record_conservative_pending_has_invalidation(parent.as_node(), true)
	scope.record_pending_has_invalidation_mutation_properties(parent.as_node(), [InvalidationProperty.pseudo_class(.checked), InvalidationProperty.id('old-id')])
	retained := scope.pending_has_invalidation_features[parent.as_node().unique_id().value()] or { panic('missing retained features') }
	scope.record_pending_has_invalidation_mutation_features(parent.as_node(), child.as_node(), false)
	gc_collect()
	current := scope.pending_has_invalidation_features[parent.as_node().unique_id().value()] or { panic('missing features') }
	assert voidptr(current) == voidptr(retained)
	assert current.is_conservative && current.may_affect_sibling_relationships
	assert current.may_affect_pseudo_classes && current.pseudo_classes[.checked]
	assert current.ids['old-id'] && current.class_names['new-class']
}

fn test_dom_child_insertions_accumulate_different_has_features_on_one_parent() {
	mut scope := pending_has_test_scope('.subject:has(.first), .subject:has(.second) { color: red }')
	document := scope.document() or { panic('missing document') }
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	parent.set_attribute_value('class', 'subject')
	mut document_node := document.as_node()
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	first.set_attribute_value('class', 'first')
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'b') or { panic(err) }
	second.set_attribute_value('class', 'second')
	scope.clear_pending_has_invalidations()
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node()) or { panic(err) }
	retained := scope.pending_has_invalidation_features[parent_node.unique_id().value()] or { panic('missing first features') }
	assert retained.class_names['first'] && !retained.class_names['second']
	parent_node.append_child(second.as_node()) or { panic(err) }
	gc_collect()
	current := scope.pending_has_invalidation_features[parent_node.unique_id().value()] or { panic('missing accumulated features') }
	assert voidptr(current) == voidptr(retained)
	assert current.class_names['first'] && current.class_names['second']
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
}
