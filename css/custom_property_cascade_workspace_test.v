module css

import dom
import platform

fn test_custom_cascade_publishes_values_and_lazy_declarations_before_workspace_retirement() {
	mut owner := platform.new_retained_arena('custom cascade publication fixture')
	mut entry := owner.enter()
	defer {
		entry.finish()
		owner.release()
	}
	_, mut child := empty_cascade_test_elements()
	child.set_attribute_value('style', '--first: purple; --inline: tail')
	sheet := deferred_sheet_for_test('span { --first: red !important; --edge: old; } span { --first: blue; --edge: green; }')
	rules := MatchingRuleSet{
		author_rules: [LayerMatchingRules{
			rules: [ScopedMatchingRule{rule: &MatchingRule{rule: sheet.rules.rules[0]}},
				ScopedMatchingRule{rule: &MatchingRule{rule: sheet.rules.rules[1]}}]
		}]
	}
	for _ in 0 .. 3 {
		install_custom_property_data_for_style(dom.AbstractElement.new(child, none), rules)
		data := dom.AbstractElement.new(child, none).custom_property_data()?
		assert data.get('--first')?.css_text == 'red'
		assert data.get_property('--first')?.important
		assert data.get('--edge')?.css_text == 'green'
		assert data.get('--inline')?.css_text == 'tail'
		$if prealloc {
			assert owner.arena.contains(data)
			assert owner.arena.contains(data.get('--edge')?)
			assert owner.arena.contains(data.get('--edge')?.css_text.str)
		}
		// The second rule is materialized while the cascade workspace is active.
		declaration := sheet.rules.rules[1].style()?
		assert declaration.get_property_value('--edge') == 'green'
		assert declaration.get_property_value('--first') == 'blue'
	}
}

fn test_custom_cascade_retains_inheritance_and_animation_across_workspace_retirement() {
	mut owner := platform.new_retained_arena('custom cascade inheritance fixture')
	mut entry := owner.enter()
	defer {
		entry.finish()
		owner.release()
	}
	test_empty_custom_cascade_preserves_animation_overlay_when_base_changes()
	test_empty_custom_cascade_keeps_inline_and_pseudo_ownership_distinct()
}
