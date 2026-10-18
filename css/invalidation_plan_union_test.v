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
