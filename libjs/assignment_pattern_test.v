module libjs

fn test_parenthesized_nested_literals_cannot_be_refined_into_assignment_patterns() {
	for text in ['([([a])] = value);', '({x: ({a})} = value);',
		'([({a})] = value);', '({x: ([a])} = value);', '([([a]) = []] = value);'] {
		parsed := parse_source(text, .script)
		assert parsed.has_errors(), text
	}
}

fn test_parenthesized_simple_targets_and_unparenthesized_nested_patterns_are_valid() {
	for text in ['([(a)] = value);', '({x: (object.value)} = value);',
		'([[a]] = value);', '({x: {a}} = value);', '([[a] = []] = value);'] {
		parsed := parse_source(text, .script)
		assert !parsed.has_errors(), '${text}: ${parsed.diagnostics}'
	}
}
