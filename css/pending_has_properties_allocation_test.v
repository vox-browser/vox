module css

import dom

fn pending_properties_test_element(document &dom.Document, name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

fn test_pending_properties_union_preserves_empty_keys_case_identity_and_scheduling() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := pending_properties_test_element(document, 'div')
	second := pending_properties_test_element(document, 'span')
	mut scope := StyleScope.new(document.as_node())
	document.needs_invalidation_of_elements_affected_by_has = false
	scope.record_pending_has_invalidation_mutation_properties(first.as_node(), [
		InvalidationProperty.class('old'),
		InvalidationProperty.id('old-id'),
		InvalidationProperty.tag_name('linearGradient'),
		InvalidationProperty.attribute('viewBox'),
		InvalidationProperty.pseudo_class(.checked),
	])
	retained := scope.pending_has_invalidation_features[first.as_node().unique_id().value()] or {
		panic('missing first record')
	}
	assert document.needs_invalidation_of_elements_affected_by_has
	assert !retained.is_conservative
	assert !retained.may_affect_sibling_relationships && !retained.may_affect_pseudo_classes
	document.needs_invalidation_of_elements_affected_by_has = false
	scope.record_pending_has_invalidation_mutation_properties(first.as_node(), [
		InvalidationProperty.class('new'),
		InvalidationProperty.class(''),
		InvalidationProperty.id(''),
		InvalidationProperty.tag_name(''),
		InvalidationProperty.attribute(''),
		InvalidationProperty.attribute('viewbox'),
		InvalidationProperty.pseudo_class(.hover),
		InvalidationProperty.invalidate_self(),
	])
	assert !document.needs_invalidation_of_elements_affected_by_has
	scope.record_pending_has_invalidation_mutation_properties(first.as_node(), [
		InvalidationProperty.invalidate_whole_subtree(),
		InvalidationProperty.class('old'),
	])
	scope.record_pending_has_invalidation_mutation_properties(second.as_node(),
		[]InvalidationProperty{})
	assert document.needs_invalidation_of_elements_affected_by_has
	gc_collect()
	current := scope.pending_has_invalidation_features[first.as_node().unique_id().value()] or {
		panic('lost record')
	}
	assert voidptr(current) == voidptr(retained)
	assert current.is_conservative
	assert !current.may_affect_sibling_relationships && !current.may_affect_pseudo_classes
	assert current.class_names.len == 3 && current.class_names['old'] && current.class_names['new']
		&& current.class_names['']
	assert current.ids.len == 2 && current.ids['old-id'] && current.ids['']
	assert current.tag_names.len == 2 && current.tag_names['linearGradient']
		&& current.tag_names['']
	assert current.attribute_names.len == 3 && current.attribute_names['viewBox']
		&& current.attribute_names['viewbox'] && current.attribute_names['']
	assert current.pseudo_classes.len == 2 && current.pseudo_classes[.checked]
		&& current.pseudo_classes[.hover]
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 2
	assert voidptr(scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[0]) == voidptr(first.as_node())
	assert voidptr(scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[1]) == voidptr(second.as_node())
	second_features := scope.pending_has_invalidation_features[second.as_node().unique_id().value()] or {
		panic('empty properties must still queue')
	}
	assert second_features.class_names.len == 0 && !second_features.is_conservative
}

fn test_pending_properties_keep_conservative_flags_and_separate_cleared_generations() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := pending_properties_test_element(document, 'div')
	mut scope := StyleScope.new(document.as_node())
	scope.record_conservative_pending_has_invalidation(element.as_node(), true)
	retained := scope.pending_has_invalidation_features[element.as_node().unique_id().value()] or {
		panic('missing conservative record')
	}
	scope.record_pending_has_invalidation_mutation_properties(element.as_node(), [
		InvalidationProperty.id('old-id'),
	])
	scope.record_pending_has_invalidation_mutation_properties(element.as_node(),
		[]InvalidationProperty{})
	assert retained.is_conservative && retained.may_affect_sibling_relationships
		&& retained.may_affect_pseudo_classes
	assert retained.ids['old-id']
	scope.clear_pending_has_invalidations()
	document.needs_invalidation_of_elements_affected_by_has = false
	scope.record_pending_has_invalidation_mutation_properties(element.as_node(),
		[]InvalidationProperty{})
	current := scope.pending_has_invalidation_features[element.as_node().unique_id().value()] or {
		panic('missing next generation')
	}
	gc_collect()
	assert voidptr(current) != voidptr(retained)
	assert document.needs_invalidation_of_elements_affected_by_has
	assert !current.is_conservative && !current.may_affect_sibling_relationships
		&& !current.may_affect_pseudo_classes
	assert current.ids.len == 0
	assert retained.ids['old-id'] && retained.is_conservative
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
}

// The previous algorithm is a positive allocation control. Keep it separate
// from the optimized public method rather than rerunning a passing executable.
fn pending_properties_original_record(mut scope StyleScope, node &dom.Node, properties []InvalidationProperty) {
	features := collect_pending_has_invalidation_mutation_features_from_properties(properties)
	scope.record_pending_has_invalidation_features(node, features)
}

fn test_repeated_known_pending_properties_allocate_no_new_feature_maps() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := pending_properties_test_element(document, 'div')
	properties := [InvalidationProperty.class('same'), InvalidationProperty.id('same'),
		InvalidationProperty.tag_name('same'), InvalidationProperty.attribute('same'),
		InvalidationProperty.pseudo_class(.checked)]
	mut optimized := StyleScope.new(document.as_node())
	mut original := StyleScope.new(document.as_node())
	optimized.record_pending_has_invalidation_mutation_properties(element.as_node(), properties)
	pending_properties_original_record(mut original, element.as_node(), properties)
	retained := optimized.pending_has_invalidation_features[element.as_node().unique_id().value()] or {
		panic('missing initial record')
	}
	gc_collect()
	before := gc_heap_usage().total_bytes
	for _ in 0 .. 1024 {
		optimized.record_pending_has_invalidation_mutation_properties(element.as_node(), properties)
	}
	after := gc_heap_usage().total_bytes
	control_before := gc_heap_usage().total_bytes
	for _ in 0 .. 1024 {
		pending_properties_original_record(mut original, element.as_node(), properties)
	}
	control_after := gc_heap_usage().total_bytes
	// Counter intervals contain no assertions, formatting or property creation.
	$if gcboehm ? {
		assert after == before
		assert control_after > control_before
	}
	gc_collect()
	current := optimized.pending_has_invalidation_features[element.as_node().unique_id().value()] or {
		panic('lost retained record')
	}
	assert voidptr(current) == voidptr(retained)
	assert current.class_names['same'] && current.ids['same'] && current.tag_names['same']
		&& current.attribute_names['same'] && current.pseudo_classes[.checked]
	assert optimized.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	println('PENDING_HAS_ALLOCATION_PROBE calls=1024 optimized_bytes=${after - before} original_algorithm_bytes=${control_after - control_before}')
}
