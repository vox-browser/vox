module css

fn parse_scope_rule(text string) ?&CSSRule {
	rules := parse_css_stylesheet_contents_with_parser(text, map[string]bool{})
	if rules.len != 1 {
		return none
	}
	return rules[0]
}

fn test_scope_rule_parses_bounds_and_serializes_cssom() {
	implicit := parse_scope_rule('@scope {}') or { panic('implicit @scope did not parse') }
	assert implicit.type_ == .scope
	assert implicit.class_name() == 'CSSScopeRule'
	assert implicit.scope_start() == none
	assert implicit.scope_end() == none
	assert implicit.css_text() == '@scope {\n}'

	bounded := parse_scope_rule('@scope (.a) to (.b) { div { display: block } }') or {
		panic('bounded @scope did not parse')
	}
	assert bounded.scope_start()? == '.a'
	assert bounded.scope_end()? == '.b'
	assert bounded.css_text() == '@scope (.a) to (.b) {\n  div { display: block; }\n}'

	limited := parse_scope_rule('@scope to (.limit) {}') or {
		panic('limit-only @scope did not parse')
	}
	assert limited.scope_start() == none
	assert limited.scope_end()? == '.limit'
	assert limited.css_text() == '@scope to (.limit) {\n}'
}

fn test_scope_rule_preserves_scoped_relative_style_rules() {
	rule := parse_scope_rule('@scope (.root) { > .child { color: red } }') or {
		panic('relative style rule in @scope did not parse')
	}
	assert rule.css_text() == '@scope (.root) {\n  & > .child { color: red; }\n}'
}

fn test_scope_rule_accepts_direct_declarations() {
	rule := parse_scope_rule('@scope (.root) { color: red }') or {
		panic('declaration in @scope did not parse')
	}
	assert rule.css_text() == '@scope (.root) {\n  color: red;\n}'
}

fn test_scope_rule_rejects_invalid_bounds() {
	assert parse_scope_rule('@scope (.root)::before {}') == none
	assert parse_scope_rule('@scope (.root) trailing {}') == none
	assert parse_scope_rule('@scope to {}') == none
	assert parse_scope_rule('@scope;') == none
}
