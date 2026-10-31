module css

import dom

fn plan_union_rule(name string, payload &InvalidationPlan) DescendantInvalidationRule {
	mut set := InvalidationSet{}
	set.set_needs_invalidate_class(name)
	return DescendantInvalidationRule{
		match_set: set
		payload:   payload
	}
}

fn test_plan_union_merges_equal_payloads_and_preserves_source_and_value_copies() {
	mut source := InvalidationPlan.create()
	mut set := InvalidationSet{}
	set.set_needs_invalidate_class('first')
	set.set_needs_invalidate_id('second')
	set.set_needs_invalidate_attribute('third')
	source.descendant_rules << DescendantInvalidationRule{
		match_set: set
		payload:   &InvalidationPlan{
			invalidate_self: true
		}
	}
	mut result := InvalidationPlan.create()
	result.include_all_from(source)
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [
			plan_union_rule('fourth', &InvalidationPlan{
				invalidate_self: true
			}),
		]
	})
	assert result.descendant_rules.len == 1
	assert result.descendant_rules[0].match_set.property_count() == 4
	assert source.descendant_rules[0].match_set.property_count() == 3
	snapshot := *result
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [
			plan_union_rule('fifth', &InvalidationPlan{
				invalidate_self: true
			}),
		]
	})
	gc_collect()
	assert result.descendant_rules[0].match_set.property_count() == 5
	assert snapshot.descendant_rules[0].match_set.property_count() == 4
	assert source.descendant_rules[0].match_set.property_count() == 3
	alias := result
	result.include_all_from(alias)
	assert result.descendant_rules.len == 1
	assert result.descendant_rules[0].match_set.property_count() == 5
}

fn test_plan_union_compares_unordered_nested_rules_without_losing_multiplicity() {
	self := &InvalidationPlan{
		invalidate_self: true
	}
	whole := &InvalidationPlan{
		invalidate_whole_subtree: true
	}
	first := plan_union_rule('first', self)
	second := plan_union_rule('second', whole)
	left := &InvalidationPlan{
		descendant_rules: [first, second]
	}
	right := &InvalidationPlan{
		descendant_rules: [second, first]
	}
	mut result := InvalidationPlan.create()
	result.include_all_from(&InvalidationPlan{ descendant_rules: [
		plan_union_rule('a', left),
	] })
	result.include_all_from(&InvalidationPlan{ descendant_rules: [
		plan_union_rule('b', right),
	] })
	assert result.descendant_rules.len == 1
	assert result.descendant_rules[0].match_set.property_count() == 2
	duplicate := &InvalidationPlan{
		descendant_rules: [first, first]
	}
	result.include_all_from(&InvalidationPlan{ descendant_rules: [
		plan_union_rule('c', duplicate),
	] })
	assert result.descendant_rules.len == 2
	// Equal set membership with a different first inline property is still equal.
	mut set_a := InvalidationSet{}
	set_a.set_needs_invalidate_class('x')
	set_a.set_needs_invalidate_id('y')
	mut set_b := InvalidationSet{}
	set_b.set_needs_invalidate_id('y')
	set_b.set_needs_invalidate_class('x')
	a := &InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: set_a, payload: self }]
	}
	b := &InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: set_b, payload: self }]
	}
	mut merged := InvalidationPlan.create()
	merged.include_all_from(&InvalidationPlan{ descendant_rules: [
		plan_union_rule('one', a),
	] })
	merged.include_all_from(&InvalidationPlan{ descendant_rules: [
		plan_union_rule('two', b),
	] })
	assert merged.descendant_rules.len == 1
}

fn test_plan_union_keeps_sibling_reach_any_matching_and_whole_subtree_actions() {
	mut result := InvalidationPlan.create()
	for reach in [SiblingInvalidationReach.adjacent, .subsequent] {
		for any in [false, true] {
			for _ in 0 .. 32 {
				result.include_all_from(&InvalidationPlan{
					sibling_rules: [
						SiblingInvalidationRule{
							reach:     reach
							match_any: any
							payload:   &InvalidationPlan{
								invalidate_self: true
							}
						},
					]
				})
			}
		}
	}
	assert result.sibling_rules.len == 4
	result.include_all_from(&InvalidationPlan{ invalidate_self: true, invalidate_whole_subtree: true })
	assert result.invalidate_self
	assert result.invalidate_whole_subtree
	assert result.sibling_rules.len == 0
	assert result.descendant_rules.len == 0
}

fn test_merged_match_sets_invalidate_every_matching_dom_branch() {
	mut plan := InvalidationPlan.create()
	for index in 0 .. 128 {
		plan.include_all_from(&InvalidationPlan{
			descendant_rules: [
				plan_union_rule('match-${index}', &InvalidationPlan{
					invalidate_self: true
				}),
			]
		})
	}
	assert plan.descendant_rules.len == 1
	assert plan.descendant_rules[0].match_set.property_count() == 128
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut bystander := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	target.set_attribute_value('class', 'match-77')
	bystander.set_attribute_value('class', 'unrelated')
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	for node in [root_node, target.as_node(), bystander.as_node()] {
		mut current := unsafe { &dom.Node(node) }
		current.set_needs_style_update_internal(false)
		current.set_child_needs_style_update(false)
		current.set_entire_subtree_needs_style_update(false)
	}
	mut invalidator := dom.StyleInvalidator{}
	invalidator.enqueue_invalidation_plan(root_node, .other, invalidation_plan_to_dom(plan))
	invalidator.invalidate(mut root_node)
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
}

fn test_match_set_union_preserves_growing_map_order_flags_and_duplicate_payloads() {
	mut first := InvalidationSet{}
	first.set_needs_invalidate_self()
	first.set_needs_invalidate_class('inline')
	for index in 0 .. 256 {
		first.add_property(InvalidationProperty{
			type_: .class
			value: 'shared-${index}'
			pseudo_class: .hover
		})
	}
	mut second := InvalidationSet{}
	second.set_needs_invalidate_whole_subtree()
	second.add_property(InvalidationProperty{
		type_: .class
		value: 'shared-0'
		pseudo_class: .checked
	})
	second.set_needs_invalidate_id('second')
	mut result := union_invalidation_match_sets(first, second)
	assert result.needs_invalidate_self() && result.needs_invalidate_whole_subtree()
	properties := result.properties()
	assert properties.len == 258
	assert properties[0].name() == 'inline'
	for index in 0 .. 256 {
		assert properties[index + 1].name() == 'shared-${index}'
		assert properties[index + 1].pseudo_class == .hover
	}
	assert properties[properties.len - 1].type_ == .id
	assert properties[properties.len - 1].name() == 'second'

	// A merge owns its map even after a long sequence of growing unions.
	// Later writes on either source and the result must stay independent.
	first.set_needs_invalidate_attribute('first-only')
	second.set_needs_invalidate_attribute('second-only')
	result.set_needs_invalidate_attribute('result-only')
	gc_collect()
	assert first.property_count() == 258
	assert second.property_count() == 3
	assert result.property_count() == 259
	assert !invalidation_set_has_stored_key(&result, '[first-only]')
	assert !invalidation_set_has_stored_key(&result, '[second-only]')
	assert !invalidation_set_has_stored_key(&first, '[result-only]')
	assert !invalidation_set_has_stored_key(&second, '[result-only]')
	first.clear_properties()
	second.clear_properties()
	gc_collect()
	assert result.property_count() == 259
	remaining_properties := result.properties()
	assert remaining_properties[remaining_properties.len - 1].name() == 'result-only'
}

fn test_match_set_union_keeps_empty_inline_and_self_inputs_independent() {
	mut single := InvalidationSet{}
	single.set_needs_invalidate_self()
	single.set_needs_invalidate_class('only')
	mut from_empty := union_invalidation_match_sets(InvalidationSet{}, single)
	mut with_empty := union_invalidation_match_sets(single, InvalidationSet{})
	assert from_empty.to_string() == '$, .only'
	assert with_empty.to_string() == '$, .only'
	assert from_empty.additional_properties_ == none
	assert with_empty.additional_properties_ == none
	from_empty.set_needs_invalidate_id('left')
	with_empty.set_needs_invalidate_id('right')
	assert single.to_string() == '$, .only'
	assert from_empty.to_string() == '$, .only, #left'
	assert with_empty.to_string() == '$, .only, #right'

	mut self_union := union_invalidation_match_sets(from_empty, from_empty)
	assert self_union.to_string() == '$, .only, #left'
	self_union.set_needs_invalidate_attribute('union-only')
	from_empty.set_needs_invalidate_attribute('source-only')
	gc_collect()
	assert self_union.to_string() == '$, .only, #left, [union-only]'
	assert from_empty.to_string() == '$, .only, #left, [source-only]'
}
