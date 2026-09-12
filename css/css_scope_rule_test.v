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
	assert rule.css_text() == '@scope (.root) {\n  > .child { color: red; }\n}'
}

fn test_scope_rule_insert_rule_preserves_relative_selector() {
	mut sheet := parse_css_stylesheet_with_parser('@scope (.root) {}', none)
	mut scope_rule := sheet.rules.item(0) or { panic('missing scope rule') }
	assert scope_rule.insert_rule('> .child { color: red }', 0)! == 0
	children := scope_rule.css_rules() or { panic('missing scope child rules') }
	mut child := children.item(0) or { panic('missing inserted child') }
	assert child.selector_text() == '> .child'
	assert serialize_a_group_of_selectors(child.absolutized_selectors()) == ':where(:scope) > .child'
}

fn test_scope_rule_insert_rule_uses_nearest_nesting_parent_through_groups() {
	mut scope_then_style := parse_css_stylesheet_with_parser('@scope { .nest {} }', none)
	mut outer_scope := scope_then_style.rules.item(0) or { panic('missing outer scope') }
	mut nested_style := (outer_scope.css_rules() or { panic('missing scope children') }).item(0) or {
		panic('missing nested style')
	}
	nested_style.insert_rule('> .child {}', 0)!
	style_child := (nested_style.css_rules() or { panic('missing style children') }).item(0) or {
		panic('missing inserted style child')
	}
	assert style_child.selector_text() == '& > .child'

	mut style_then_scope := parse_css_stylesheet_with_parser('.nest { @scope {} }', none)
	mut outer_style := style_then_scope.rules.item(0) or { panic('missing outer style') }
	mut nested_scope := (outer_style.css_rules() or { panic('missing style children') }).item(0) or {
		panic('missing nested scope')
	}
	nested_scope.insert_rule('> .child {}', 0)!
	scope_child := (nested_scope.css_rules() or { panic('missing scope children') }).item(0) or {
		panic('missing inserted scope child')
	}
	assert scope_child.selector_text() == '> .child'

	mut scope_then_media := parse_css_stylesheet_with_parser('@scope { @media screen {} }', none)
	mut media_scope := scope_then_media.rules.item(0) or { panic('missing media scope') }
	mut media := (media_scope.css_rules() or { panic('missing media scope children') }).item(0) or {
		panic('missing media rule')
	}
	media.insert_rule('> .child {}', 0)!
	media_child := (media.css_rules() or { panic('missing media children') }).item(0) or {
		panic('missing inserted media child')
	}
	assert media_child.selector_text() == '> .child'

	mut scope_style_media := parse_css_stylesheet_with_parser('@scope { .nest { @media screen {} } }', none)
	mut grouped_scope := scope_style_media.rules.item(0) or { panic('missing grouped scope') }
	mut grouped_style := (grouped_scope.css_rules() or { panic('missing grouped style') }).item(0) or {
		panic('missing grouped style')
	}
	mut grouped_media := (grouped_style.css_rules() or { panic('missing grouped media') }).item(0) or {
		panic('missing grouped media')
	}
	grouped_media.insert_rule('> .child {}', 0)!
	grouped_style_child := (grouped_media.css_rules() or { panic('missing grouped child') }).item(0) or {
		panic('missing grouped child')
	}
	assert grouped_style_child.selector_text() == '& > .child'

	mut style_scope_media := parse_css_stylesheet_with_parser('.nest { @scope { @media screen {} } }', none)
	mut grouped_outer_style := style_scope_media.rules.item(0) or { panic('missing outer style') }
	mut grouped_inner_scope := (grouped_outer_style.css_rules() or { panic('missing inner scope') }).item(0) or {
		panic('missing inner scope')
	}
	mut grouped_inner_media := (grouped_inner_scope.css_rules() or { panic('missing inner media') }).item(0) or {
		panic('missing inner media')
	}
	grouped_inner_media.insert_rule('> .child {}', 0)!
	grouped_scope_child := (grouped_inner_media.css_rules() or { panic('missing scoped child') }).item(0) or {
		panic('missing scoped child')
	}
	assert grouped_scope_child.selector_text() == '> .child'
}

fn test_scope_rule_string_parsing_uses_nearest_nesting_parent_through_groups() {
	mut scope_style := parse_css_stylesheet_with_parser('@scope { .nest { > .child {} } }', none)
	mut outer_scope := scope_style.rules.item(0) or { panic('missing outer scope') }
	mut nested_style := (outer_scope.css_rules() or { panic('missing nested style') }).item(0) or {
		panic('missing nested style')
	}
	style_child := (nested_style.css_rules() or { panic('missing style child') }).item(0) or {
		panic('missing style child')
	}
	assert style_child.selector_text() == '& > .child'

	mut style_scope := parse_css_stylesheet_with_parser('.nest { @scope { > .child {} } }', none)
	mut outer_style := style_scope.rules.item(0) or { panic('missing outer style') }
	mut nested_scope := (outer_style.css_rules() or { panic('missing nested scope') }).item(0) or {
		panic('missing nested scope')
	}
	scope_child := (nested_scope.css_rules() or { panic('missing scope child') }).item(0) or {
		panic('missing scope child')
	}
	assert scope_child.selector_text() == '> .child'

	mut scope_style_media := parse_css_stylesheet_with_parser('@scope { .nest { @media screen { > .child {} } } }', none)
	mut grouped_scope := scope_style_media.rules.item(0) or { panic('missing grouped scope') }
	mut grouped_style := (grouped_scope.css_rules() or { panic('missing grouped style') }).item(0) or {
		panic('missing grouped style')
	}
	mut grouped_media := (grouped_style.css_rules() or { panic('missing grouped media') }).item(0) or {
		panic('missing grouped media')
	}
	grouped_style_child := (grouped_media.css_rules() or { panic('missing grouped child') }).item(0) or {
		panic('missing grouped child')
	}
	assert grouped_style_child.selector_text() == '& > .child'

	mut style_scope_media := parse_css_stylesheet_with_parser('.nest { @scope { @media screen { > .child {} } } }', none)
	mut grouped_outer_style := style_scope_media.rules.item(0) or { panic('missing outer style') }
	mut grouped_inner_scope := (grouped_outer_style.css_rules() or { panic('missing inner scope') }).item(0) or {
		panic('missing inner scope')
	}
	mut grouped_inner_media := (grouped_inner_scope.css_rules() or { panic('missing inner media') }).item(0) or {
		panic('missing inner media')
	}
	grouped_scope_child := (grouped_inner_media.css_rules() or { panic('missing scoped child') }).item(0) or {
		panic('missing scoped child')
	}
	assert grouped_scope_child.selector_text() == '> .child'
}

fn test_scope_rule_selector_text_uses_nearest_nesting_parent() {
	mut sheet := parse_css_stylesheet_with_parser('@scope { .nest { .child {} } }', none)
	mut scope_rule := sheet.rules.item(0) or { panic('missing scope') }
	mut style_rule := (scope_rule.css_rules() or { panic('missing style') }).item(0) or {
		panic('missing style')
	}
	mut child := (style_rule.css_rules() or { panic('missing child') }).item(0) or {
		panic('missing child')
	}
	child.set_selector_text('> .changed')
	assert child.selector_text() == '& > .changed'

	mut scoped_sheet := parse_css_stylesheet_with_parser('.nest { @scope { .child {} } }', none)
	mut outer_style := scoped_sheet.rules.item(0) or { panic('missing outer style') }
	mut nested_scope := (outer_style.css_rules() or { panic('missing nested scope') }).item(0) or {
		panic('missing nested scope')
	}
	mut scoped_child := (nested_scope.css_rules() or { panic('missing scoped child') }).item(0) or {
		panic('missing scoped child')
	}
	scoped_child.set_selector_text('> .changed')
	assert scoped_child.selector_text() == '> .changed'
}

fn test_nested_scope_rule_absolutizes_relative_start_selector_for_matching() {
	mut sheet := parse_css_stylesheet_with_parser('@scope { @scope (> .boundary) {} }', none)
	mut outer_scope := sheet.rules.item(0) or { panic('missing outer scope') }
	mut nested_scope := (outer_scope.css_rules() or { panic('missing nested scope') }).item(0) or {
		panic('missing nested scope')
	}
	assert nested_scope.scope_start()? == '> .boundary'
	matching := nested_scope.scope_start_selectors_for_matching() or {
		panic('missing matching selector')
	}
	assert serialize_a_group_of_selectors(matching) == ':where(:scope) > .boundary'
}

fn test_nested_scope_rule_rejects_top_level_only_at_rules_with_hierarchy_error() {
	mut sheet := parse_css_stylesheet_with_parser('@scope {}', none)
	mut scope_rule := sheet.rules.item(0) or { panic('missing scope') }
	if _ := scope_rule.insert_rule('@import "nested.css";', 0) {
		assert false
	} else {
		assert err.msg().starts_with('HierarchyRequestError:')
	}
	if _ := scope_rule.insert_rule('@namespace svg url("urn:svg");', 0) {
		assert false
	} else {
		assert err.msg().starts_with('HierarchyRequestError:')
	}
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
