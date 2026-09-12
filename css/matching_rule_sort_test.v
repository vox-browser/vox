module css

fn test_sort_matching_rules_uses_cached_specificity() {
	mut higher_specificity := &MatchingRule{
		specificity: 2
		style_sheet_index: 0
		rule_index: 0
	}
	mut lower_specificity := &MatchingRule{
		specificity: 1
		style_sheet_index: 1
		rule_index: 1
	}
	mut rules := [&MatchingRule(higher_specificity), lower_specificity]

	sort_matching_rules(mut rules)

	assert voidptr(rules[0]) == voidptr(lower_specificity)
	assert voidptr(rules[1]) == voidptr(higher_specificity)
}
