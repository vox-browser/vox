module css

import platform

fn assert_parsed_selector_graph_matches(actual Selector, expected Selector) {
	assert actual.text() == expected.text()
	assert actual.serialize() == expected.serialize()
	assert actual.specificity() == expected.specificity()
	assert actual.sibling_invalidation_distance() == expected.sibling_invalidation_distance()
	assert actual.can_use_fast_matches() == expected.can_use_fast_matches()
	assert actual.can_use_ancestor_filter() == expected.can_use_ancestor_filter()
	assert actual.ancestor_hashes() == expected.ancestor_hashes()
	assert actual.contains_the_nesting_selector() == expected.contains_the_nesting_selector()
	assert actual.has_part_pseudo_element() == expected.has_part_pseudo_element()
	assert actual.data_.contained_pseudo_classes == expected.data_.contained_pseudo_classes
	assert actual.compound_selectors().len == expected.compound_selectors().len
	for compound_index, expected_compound in expected.compound_selectors() {
		actual_compound := actual.compound_selectors()[compound_index]
		assert actual_compound.combinator == expected_compound.combinator
		assert actual_compound.simple_selectors.len == expected_compound.simple_selectors.len
		for index in 0 .. expected_compound.simple_selectors.len {
			actual_simple := unsafe { &actual_compound.simple_selectors[index] }
			expected_simple := unsafe { &expected_compound.simple_selectors[index] }
			assert actual_simple.type_ == expected_simple.type_
			assert actual_simple.payload_kind_ == expected_simple.payload_kind_
			assert actual_simple.name() == expected_simple.name()
			assert actual_simple.qualified_name() == expected_simple.qualified_name()
			assert actual_simple.attribute() == expected_simple.attribute()
			assert actual_simple.invalid_text() == expected_simple.invalid_text()
			actual_class := actual_simple.pseudo_class()
			expected_class := expected_simple.pseudo_class()
			assert actual_class.type_ == expected_class.type_
			assert actual_class.an_plus_b_pattern == expected_class.an_plus_b_pattern
			assert actual_class.is_forgiving == expected_class.is_forgiving
			assert actual_class.languages == expected_class.languages
			assert actual_class.ident == expected_class.ident
			assert actual_class.levels == expected_class.levels
			assert actual_class.argument_selector_list.selectors.len == expected_class.argument_selector_list.selectors.len
			for child_index, child in expected_class.argument_selector_list.selectors {
				assert_parsed_selector_graph_matches(actual_class.argument_selector_list.selectors[child_index], child)
			}
			actual_element := actual_simple.pseudo_element()
			expected_element := expected_simple.pseudo_element()
			assert actual_element.type_ == expected_element.type_
			assert actual_element.name == expected_element.name
			assert actual_element.value_kind == expected_element.value_kind
			assert actual_element.pt_name_selector == expected_element.pt_name_selector
			assert actual_element.ident_list == expected_element.ident_list
			if child := expected_element.compound_selector {
				actual_child := actual_element.compound_selector or {
					panic('missing compound selector')
				}
				assert_parsed_selector_graph_matches(actual_child, child)
			} else {
				assert actual_element.compound_selector == none
			}
		}
	}
}

fn selector_workspace_samples() []string {
	return [
		r'svg|Path.\43 ard[data-label="esc\61 ped" i]:is(.one, :made-up):not(.hidden):has(> .child)',
		':nth-child(2n+1 of .row, #last):nth-last-of-type(3n-2)',
		':lang(en, "fr"):dir(rtl):state(open):heading(1, 3)',
		':host(.ready) ::slotted(svg|path.selected)',
		'.host::part(first second)::before',
		'::view-transition-old(card)',
		'::-webkit-input-placeholder',
		'.owner > & + [*|title~="word" s] ~ |span',
		':unknown(invalid)',
		'',
	]
}

fn test_selector_parse_workspace_keeps_recursive_payloads_and_cached_metadata() {
	for source in selector_workspace_samples() {
		actual := selector_from_text(source)
		expected := selector_from_text_impl(source)
		assert_parsed_selector_graph_matches(actual, expected)
	}
}

fn test_selector_parse_graph_owns_input_and_nested_strings_after_input_arena_release() {
	for source in selector_workspace_samples() {
		mut input := platform.new_arena('selector input lifetime')
		entry := input.enter()
		borrowed_text := source.clone()
		input.leave(entry)
		actual := selector_from_text(borrowed_text)
		input.release()
		assert_parsed_selector_graph_matches(actual, selector_from_text_impl(source))
	}
}

fn test_selector_parse_export_keeps_expanded_payloads_and_shared_child_identity() {
	mut input := platform.new_arena('selector graph lifetime')
	entry := input.enter()
	child := selector_from_text_impl('.child[data-x="owned"]'.clone())
	fields := SimpleSelectorInit{
		type_:          .pseudo_element
		name:           SelectorName.new('inactive'.clone())
		qualified_name: SelectorQualifiedName{ namespace_type: .named, namespace_: 'ns'.clone(), name: SelectorName.new('Tag'.clone()) }
		attribute:      SelectorAttribute{ value: 'attribute'.clone() }
		pseudo_class:   PseudoClassSelector{
			type_:                  .is_
			argument_selector_list: SelectorList{
				selectors: [
					child,
					child,
				]
			}
			languages:              ['en'.clone()]
			ident:                  PseudoClassIdent{ string_value: 'open'.clone() }
			levels:                 [i64(3)]
		}
		pseudo_element: PseudoElementSelector{ type_: .slotted, name: 'slotted'.clone(), value_kind: .compound_selector, compound_selector: child, pt_name_selector: PseudoElementPTNameSelector{ value: 'unused'.clone() }, ident_list: ['unused'.clone()] }
		invalid_text:   'inactive invalid'.clone()
	}
	parsed := create_selector('expanded'.clone(), [CompoundSelector{ simple_selectors: [SimpleSelector.create(fields)] }])
	_ = parsed.specificity()
	_ = parsed.sibling_invalidation_distance()
	mut copy := ParsedSelectorCopy{}
	copy.prepare(parsed)
	input.leave(entry)
	owned := copy.selector(parsed)
	assert_parsed_selector_graph_matches(owned, parsed)
	assert voidptr(owned.data_) != voidptr(parsed.data_)
	input.release()
	payload := owned.compound_selectors()[0].simple_selectors[0]
	assert payload.name().name == 'inactive'
	assert payload.qualified_name().namespace_ == 'ns'
	assert payload.attribute().value == 'attribute'
	assert payload.invalid_text() == 'inactive invalid'
	first := payload.pseudo_class().argument_selector_list.selectors[0]
	second := payload.pseudo_class().argument_selector_list.selectors[1]
	slotted := payload.pseudo_element().compound_selector?
	assert voidptr(first.data_) == voidptr(second.data_)
	assert voidptr(first.data_) == voidptr(slotted.data_)
	assert first.serialize() == '.child[data-x="owned"]'
	assert payload.pseudo_class().languages == ['en']
	assert payload.pseudo_class().ident?.string_value == 'open'
	assert payload.pseudo_class().levels == [i64(3)]
	assert payload.pseudo_element().pt_name_selector.value == 'unused'
	assert payload.pseudo_element().ident_list == ['unused']
	assert owned.pseudo_element()?.compound_selector?.serialize() == '.child[data-x="owned"]'
}

fn test_selector_parse_workspace_keeps_public_selector_and_payload_copy_semantics() {
	selector := selector_from_text(':lang(en, fr)::part(first second)')
	snapshot := selector
	assert voidptr(snapshot.data_) == voidptr(selector.data_)
	original := selector.compound_selectors()[0].simple_selectors[0]
	mut changed := original
	mut language := changed.pseudo_class()
	language.languages = language.languages.clone()
	language.languages[0] = 'de'
	changed.set_pseudo_class(language)
	assert original.pseudo_class().languages == ['en', 'fr']
	assert changed.pseudo_class().languages == ['de', 'fr']
	assert snapshot.serialize() == ':lang(en, fr)::part(first second)'
}

fn selector_parse_retained_bytes(source string, workspace bool) u64 {
	mut owner := platform.new_arena('selector parse budget')
	entry := owner.enter()
	mut last := Selector{}
	for _ in 0 .. 8 {
		last = if workspace { selector_from_text(source) } else { selector_from_text_impl(source) }
	}
	owner.leave(entry)
	used := owner.usage().used
	assert last.compound_selectors().len > 0
	owner.release()
	return used
}

fn test_selector_parse_workspace_retires_validation_builders_and_vector_growth() {
	$if prealloc {
		source := '.root:not(.one > .two + .three):has(> .child.foo[data-kind="value"]) > .leaf:is(.first, .second, .third):nth-child(2n of .row, #last)'
		_ = selector_from_text(source)
		reference := selector_parse_retained_bytes(source, false)
		owned := selector_parse_retained_bytes(source, true)
		assert owned < reference * 8 / 10, 'owned=${owned} reference=${reference}'
	}
}
