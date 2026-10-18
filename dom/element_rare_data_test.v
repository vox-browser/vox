module dom

import strings

fn rare_data_test_element(document &Document, name string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

fn test_ordinary_element_metadata_reads_and_clears_do_not_allocate_rare_storage() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for namespace_ in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg',
		'http://www.w3.org/1998/Math/MathML'] {
		mut element := document.create_element_ns(namespace_, 'div') or { panic(err) }
		mut abstract_element := AbstractElement.new(element, none)
		assert element.rare_data_ == unsafe { nil }
		abstract_element.set_has_css_defined_animations()
		assert element.has_css_defined_animations_flag
		assert element.rare_data_ == unsafe { nil }
		before := gc_heap_usage().total_bytes
		mut found := 0
		for _ in 0 .. 1024 {
			found += element.pseudo_element_record_count()
			if element.get_pseudo_element(1) != none { found++ }
			if element.get_pseudo_element_node(1) != none { found++ }
			if element.has_pseudo_element(1) || element.has_pseudo_elements() { found++ }
			if element.element_reference_pseudo_element(1) != none { found++ }
			if abstract_element.css_defined_animations() != none { found++ }
			element.clear_pseudo_element_nodes()
			element.remove_pseudo_element_record(1)
			abstract_element.remove_css_defined_animation('missing')
			element.play_or_cancel_animations_after_display_property_change()
		}
		after := gc_heap_usage().total_bytes
		assert found == 0
		assert element.rare_data_ == unsafe { nil }
		$if gcboehm ? { assert after == before
		 }
	}
}

fn test_late_pseudo_records_preserve_identity_styles_clear_and_reinsertion() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := rare_data_test_element(document, 'div')
	assert element.pseudo_element_record_count() == 0
	assert element.get_pseudo_element(1) == none
	mut original_edges := CellVisitor{}
	element.visit_edges(mut original_edges)
	first := element.ensure_pseudo_element(1)
	store := element.rare_data_
	style := &CSSComputedProperties_{}
	element.set_computed_properties(1, style)
	layout := &LayoutNodeWithStyle_{}
	element.set_pseudo_element_node(1, layout)
	element.set_pseudo_element_node(2, &LayoutNodeWithStyle_{})
	assert element.pseudo_element_record_count() == 2
	assert element.has_pseudo_elements()
	for _ in 0 .. 3 {
		gc_collect()
		assert voidptr(element.get_pseudo_element(1) or { panic('missing pseudo') }) == voidptr(first)
		assert voidptr(element.get_pseudo_element_node(1) or { panic('missing layout') }) == voidptr(layout)
		assert voidptr(element.computed_properties_for_pseudo(1) or {
			panic('missing pseudo style')
		}) == voidptr(style)
	}
	mut visitor := CellVisitor{}
	element.visit_edges(mut visitor)
	assert visitor.visited == original_edges.visited + 2
	element.clear_pseudo_element_nodes()
	assert !element.has_pseudo_elements()
	assert element.pseudo_element_record_count() == 2
	assert element.computed_properties_for_pseudo(1) != none
	element.remove_pseudo_element_record(1)
	assert element.get_pseudo_element(1) == none
	assert element.pseudo_element_record_count() == 1
	replacement := element.ensure_pseudo_element(1)
	assert voidptr(replacement) != voidptr(first)
	assert voidptr(element.rare_data_) == voidptr(store)
	assert voidptr(element.get_pseudo_element(1) or { panic('missing replacement') }) == voidptr(replacement)
	assert first.computed_properties() != none
}

fn test_element_reference_pseudo_storage_keeps_shadow_identity_through_adoption() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(URL{ value: 'https://adoption.example/' })
	defer { source.finalize() }
	defer { destination.finalize() }
	mut host := rare_data_test_element(source, 'div')
	mut root := host.attach_shadow(ShadowRootInit{ mode: .closed }) or { panic(err) }
	root.set_user_agent_internal(true)
	mut child := rare_data_test_element(source, 'span')
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	assert host.rare_data_ == unsafe { nil }
	child.set_associated_shadow_host_pseudo_element(7)
	store := host.rare_data_
	assert (child.associated_shadow_host_pseudo_element() or { panic('missing association') }) == 7
	assert voidptr(host.element_reference_pseudo_element(7) or { panic('missing reference') }) == voidptr(child)
	assert host.element_reference_pseudo_element(8) == none
	assert child.rare_data_ == unsafe { nil }
	destination.adopt_node(host.as_node())
	gc_collect()
	assert voidptr(host.rare_data_) == voidptr(store)
	assert voidptr(host.document()) == voidptr(destination)
	assert voidptr(child.document()) == voidptr(destination)
	assert voidptr(host.element_reference_pseudo_element(7) or { panic('lost adopted reference') }) == voidptr(child)
	mut replacement := rare_data_test_element(destination, 'span')
	root_node.append_child(replacement.as_node()) or { panic(err) }
	replacement.set_associated_shadow_host_pseudo_element(7)
	gc_collect()
	assert voidptr(host.element_reference_pseudo_element(7) or { panic('missing replacement') }) == voidptr(replacement)
	assert (child.associated_shadow_host_pseudo_element() or { panic('lost original association') }) == 7
}

fn test_lazy_css_animation_maps_keep_names_pseudo_keys_and_published_snapshots() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := rare_data_test_element(document, 'div')
	mut base := AbstractElement.new(element, none)
	mut before := AbstractElement.new(element, .before)
	assert base.css_defined_animations() == none
	first := &CSSAnimation_{}
	second := &CSSAnimation_{}
	pseudo := &CSSAnimation_{}
	base.set_css_defined_animation('fade', first)
	store := element.rare_data_
	base.set_css_defined_animation('spin', second)
	before.set_css_defined_animation('fade', pseudo)
	assert element.has_css_defined_animations_flag
	published := base.css_defined_animations() or { panic('missing animation map') }
	assert published.len == 2
	base.remove_css_defined_animation('fade')
	remaining := base.css_defined_animations() or { panic('missing remaining map') }
	assert remaining.len == 1
	assert 'fade' !in remaining
	assert published.len == 2
	gc_collect()
	assert voidptr(published['fade'] or { panic('lost published animation') }) == voidptr(first)
	assert voidptr(remaining['spin'] or { panic('lost remaining animation') }) == voidptr(second)
	pseudo_animations := before.css_defined_animations() or { panic('missing pseudo animations') }
	assert voidptr(pseudo_animations['fade'] or { panic('lost pseudo animation') }) == voidptr(pseudo)
	base.remove_css_defined_animation('spin')
	assert base.css_defined_animations() == none
	assert before.css_defined_animations() != none
	before.remove_css_defined_animation('fade')
	assert before.css_defined_animations() == none
	base.set_css_defined_animation('fade', second)
	assert voidptr(element.rare_data_) == voidptr(store)
	reinserted := base.css_defined_animations() or { panic('missing reinserted animation') }
	assert voidptr(reinserted['fade'] or { panic('missing reinserted name') }) == voidptr(second)
}

fn test_lazy_css_random_values_survive_collection_and_document_adoption() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(URL{ value: 'https://random.example/' })
	defer { source.finalize() }
	defer { destination.finalize() }
	mut element := rare_data_test_element(source, 'div')
	assert element.rare_data_ == unsafe { nil }
	first := element.ensure_css_random_base_value('same-key')
	store := element.rare_data_
	assert first >= 0 && first < 1
	second := element.ensure_css_random_base_value('other-key')
	assert second >= 0 && second < 1
	assert store.style_data_.element_specific_css_random_base_values.len == 2
	for _ in 0 .. 3 {
		gc_collect()
		assert element.ensure_css_random_base_value('same-key') == first
		assert element.ensure_css_random_base_value('other-key') == second
	}
	destination.adopt_node(element.as_node())
	gc_collect()
	assert voidptr(element.document()) == voidptr(destination)
	assert voidptr(element.rare_data_) == voidptr(store)
	assert element.ensure_css_random_base_value('same-key') == first
	assert element.ensure_css_random_base_value('other-key') == second
}

fn test_pseudo_owner_missing_cold_metadata_reads_and_clears_do_not_allocate() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for namespace_ in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg',
		'http://www.w3.org/1998/Math/MathML'] {
		mut element := document.create_element_ns(namespace_, 'div') or { panic(err) }
		pseudo := element.ensure_pseudo_element(1)
		mut abstract_element := AbstractElement.new(element, none)
		abstract_element.set_has_css_defined_animations()
		assert element.rare_data_.style_data_ == unsafe { nil }
		before := gc_heap_usage().total_bytes
		mut found := 0
		for _ in 0 .. 1024 {
			if element.element_reference_pseudo_element(7) != none { found++ }
			if abstract_element.css_defined_animations() != none { found++ }
			abstract_element.remove_css_defined_animation('missing')
			element.play_or_cancel_animations_after_display_property_change()
		}
		after := gc_heap_usage().total_bytes
		assert found == 0
		assert element.rare_data_.style_data_ == unsafe { nil }
		$if gcboehm ? { assert after == before }
		gc_collect()
		assert voidptr(element.get_pseudo_element(1) or { panic('lost pseudo') }) == voidptr(pseudo)
		assert element.rare_data_.style_data_ == unsafe { nil }
	}
}

fn test_first_cold_metadata_use_keeps_pseudo_owner_and_survives_independent_removal() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(URL{ value: 'https://cold.example/' })
	defer { source.finalize() }
	defer { destination.finalize() }
	mut element := rare_data_test_element(source, 'div')
	pseudo := element.ensure_pseudo_element(-7)
	store := element.rare_data_
	assert store.style_data_ == unsafe { nil }
	random_value := element.ensure_css_random_base_value('retained')
	cold_store := store.style_data_
	assert cold_store != unsafe { nil }
	assert voidptr(element.rare_data_) == voidptr(store)
	mut base := AbstractElement.new(element, none)
	animation := &CSSAnimation_{}
	base.set_css_defined_animation('fade', animation)
	assert voidptr(store.style_data_) == voidptr(cold_store)
	element.remove_pseudo_element_record(-7)
	assert element.pseudo_element_record_count() == 0
	assert base.css_defined_animations() != none
	assert element.ensure_css_random_base_value('retained') == random_value
	replacement := element.ensure_pseudo_element(-7)
	assert voidptr(replacement) != voidptr(pseudo)
	base.remove_css_defined_animation('fade')
	assert base.css_defined_animations() == none
	destination.adopt_node(element.as_node())
	gc_collect()
	assert voidptr(element.document()) == voidptr(destination)
	assert voidptr(element.rare_data_) == voidptr(store)
	assert voidptr(store.style_data_) == voidptr(cold_store)
	assert element.ensure_css_random_base_value('retained') == random_value
	assert voidptr(element.get_pseudo_element(-7) or { panic('lost replacement') }) == voidptr(replacement)
}

fn test_first_pseudo_record_has_no_overflow_and_missing_lookups_allocate_nothing() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := rare_data_test_element(document, 'div')
	first := element.ensure_pseudo_element(-17)
	store := element.rare_data_
	assert store.additional_pseudos_ == unsafe { nil }
	assert store.style_data_ == unsafe { nil }
	assert element.pseudo_element_record_count() == 1
	before := gc_heap_usage().total_bytes
	mut found := 0
	for _ in 0 .. 1024 {
		if element.get_pseudo_element(-17) != none { found++ }
		if element.get_pseudo_element(0) != none { found++ }
		if element.get_pseudo_element(17) != none { found++ }
		element.remove_pseudo_element_record(17)
	}
	after := gc_heap_usage().total_bytes
	assert found == 1024
	assert store.additional_pseudos_ == unsafe { nil }
	$if gcboehm ? { assert after == before }
	element.remove_pseudo_element_record(-17)
	assert element.pseudo_element_record_count() == 0
	replacement := element.ensure_pseudo_element(0)
	assert voidptr(replacement) != voidptr(first)
	gc_collect()
	assert voidptr(element.get_pseudo_element(0) or { panic('missing zero key') }) == voidptr(replacement)
	assert store.additional_pseudos_ == unsafe { nil }
}

fn test_overflow_record_identity_survives_empty_first_slot_reuse_and_adoption() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(URL{ value: 'https://overflow.example/' })
	defer { source.finalize() }
	defer { destination.finalize() }
	mut element := rare_data_test_element(source, 'div')
	first := element.ensure_pseudo_element(17)
	second := element.ensure_pseudo_element(-17)
	overflow := element.rare_data_.additional_pseudos_
	assert overflow != unsafe { nil }
	assert element.pseudo_element_record_count() == 2
	element.remove_pseudo_element_record(17)
	assert element.pseudo_element_record_count() == 1
	assert voidptr(element.ensure_pseudo_element(-17)) == voidptr(second)
	assert element.pseudo_element_record_count() == 1
	assert element.rare_data_.first_pseudo_ == unsafe { nil }
	replacement := element.ensure_pseudo_element(0)
	assert voidptr(replacement) != voidptr(first)
	assert element.pseudo_element_record_count() == 2
	assert voidptr(element.rare_data_.additional_pseudos_) == voidptr(overflow)
	destination.adopt_node(element.as_node())
	gc_collect()
	assert voidptr(element.document()) == voidptr(destination)
	assert voidptr(element.get_pseudo_element(-17) or { panic('lost overflow') }) == voidptr(second)
	assert voidptr(element.get_pseudo_element(0) or { panic('lost first slot') }) == voidptr(replacement)
	element.remove_pseudo_element_record(-17)
	assert element.pseudo_element_record_count() == 1
	assert element.get_pseudo_element(-17) == none
	assert voidptr(element.get_pseudo_element(0) or { panic('lost retained record') }) == voidptr(replacement)
}

fn test_direct_and_overflow_pseudos_keep_visiting_style_invalidation_and_sorted_json() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := rare_data_test_element(document, 'div')
	mut original_edges := CellVisitor{}
	element.visit_edges(mut original_edges)
	element.set_computed_properties(int(PseudoElement.selection), &CSSComputedProperties_{
		attempted_pseudo_class_matches_: u8(1) << int(PseudoClass.hover)
	})
	element.set_computed_properties(int(PseudoElement.first_letter), &CSSComputedProperties_{
		attempted_pseudo_class_matches_: u8(1) << int(PseudoClass.focus)
	})
	for typ in [PseudoElement.selection, .first_letter, .before] {
		element.set_pseudo_element_node(int(typ), &LayoutNodeWithStyle_{})
	}
	gc_collect()
	mut visitor := CellVisitor{}
	element.visit_edges(mut visitor)
	assert visitor.visited == original_edges.visited + 3
	assert element.affected_by_pseudo_class(.hover)
	assert element.affected_by_pseudo_class(.focus)
	assert !element.affected_by_pseudo_class(.active)
	mut builder := strings.new_builder(512)
	element.serialize_children_as_json(mut builder)
	serialized := builder.str()
	before_index := serialized.index('"name":"::before"') or { panic('missing before') }
	letter_index := serialized.index('"name":"::first-letter"') or { panic('missing first-letter') }
	selection_index := serialized.index('"name":"::selection"') or { panic('missing selection') }
	assert before_index < letter_index
	assert letter_index < selection_index
	assert element.has_pseudo_elements()
	element.clear_pseudo_element_nodes()
	assert !element.has_pseudo_elements()
	assert element.pseudo_element_record_count() == 3
	assert element.computed_properties_for_pseudo(int(PseudoElement.selection)) != none
	assert element.computed_properties_for_pseudo(int(PseudoElement.first_letter)) != none
	element.remove_pseudo_element_record(int(PseudoElement.selection))
	assert !element.affected_by_pseudo_class(.hover)
	assert element.affected_by_pseudo_class(.focus)
}
