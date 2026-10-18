module dom

fn duplicate_invalidation_test_rule(name string, payload InvalidationPlan) DescendantInvalidationRule {
	return DescendantInvalidationRule{
		match_set: StyleInvalidationSet{properties: [InvalidationProperty{type_: .class, name: name}]}
		payload: payload
	}
}

fn test_pending_descendant_invalidations_collapse_independent_equal_plans() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut root_node := root.as_node()
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	target.set_attribute_value('class', 'target')
	root_node.append_child(target.as_node())!
	mut invalidator := StyleInvalidator{}
	for _ in 0 .. 256 {
		// Each call owns a new match-set array and nested optional payload.
		invalidator.enqueue_invalidation_plan(root_node, .other, InvalidationPlan{
			descendant_rules: [duplicate_invalidation_test_rule('target', InvalidationPlan{invalidate_self: true})]
		})
	}
	assert invalidator.pending_invalidations[root_node.unique_id()].len == 1
	root_node.set_entire_subtree_needs_style_update(false)
	mut target_node := target.as_node()
	target_node.set_needs_style_update_internal(false)
	invalidator.invalidate(mut root_node)
	assert target_node.needs_style_update()
	assert invalidator.pending_invalidations.len == 0
	assert invalidator.active_descendant_invalidations.len == 0
	// A later drain must still process the same plan after the first was cleared.
	target_node.set_needs_style_update_internal(false)
	invalidator.enqueue_invalidation_plan(root_node, .other, InvalidationPlan{
		descendant_rules: [duplicate_invalidation_test_rule('target', InvalidationPlan{invalidate_self: true})]
	})
	invalidator.invalidate(mut root_node)
	assert target_node.needs_style_update()
}

fn test_active_descendant_invalidations_keep_distinct_nested_payloads() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut invalidator := StyleInvalidator{}
	for _ in 0 .. 128 {
		invalidator.apply_invalidation_plan(mut element, .other, InvalidationPlan{
			descendant_rules: [duplicate_invalidation_test_rule('branch', InvalidationPlan{
				descendant_rules: [duplicate_invalidation_test_rule('leaf', InvalidationPlan{invalidate_self: true})]
			})]
		}, false)
	}
	assert invalidator.active_descendant_invalidations.len == 1
	// The same outer match with a different leaf or whole-subtree action is distinct.
	invalidator.apply_invalidation_plan(mut element, .other, InvalidationPlan{
		descendant_rules: [duplicate_invalidation_test_rule('branch', InvalidationPlan{
			descendant_rules: [duplicate_invalidation_test_rule('another-leaf', InvalidationPlan{invalidate_self: true})]
		})]
	}, false)
	invalidator.apply_invalidation_plan(mut element, .other, InvalidationPlan{
		descendant_rules: [duplicate_invalidation_test_rule('branch', InvalidationPlan{invalidate_whole_subtree: true})]
	}, false)
	assert invalidator.active_descendant_invalidations.len == 3
}

fn test_duplicate_invalidation_identity_preserves_reasons_and_sibling_reach() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut invalidator := StyleInvalidator{}
	for reach in [SiblingInvalidationReach.adjacent, .subsequent] {
		for reason in [StyleInvalidationReason.other, .element_attribute_change] {
			for _ in 0 .. 16 {
				plan := InvalidationPlan{
					descendant_rules: [duplicate_invalidation_test_rule('branch', InvalidationPlan{
						sibling_rules: [SiblingInvalidationRule{
							match_any: true
							reach: reach
							payload: InvalidationPlan{invalidate_self: true}
						}]
					})]
				}
				invalidator.add_pending_invalidation(element.as_node(), reason, plan)
				invalidator.apply_invalidation_plan(mut element, reason, plan, false)
			}
		}
	}
	assert invalidator.pending_invalidations[element.as_node().unique_id()].len == 4
	assert invalidator.active_descendant_invalidations.len == 4
}
