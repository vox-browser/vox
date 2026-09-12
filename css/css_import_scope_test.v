module css

fn scoped_import_rules(source string) []&CSSRule {
	return parse_css_stylesheet_contents_with_parser(source, map[string]bool{})
}

fn test_import_rule_parses_and_serializes_scope_bounds() {
	rules := scoped_import_rules('
		@import url(a.css) scope;
		@import url(b.css) scope();
		@import url(c.css) scope(.scope, .other);
		@import url(d.css) scope(to (.limit));
		@import url(e.css) scope((.scope) to (.limit));
	')
	assert rules.len == 5
	for rule in rules {
		assert rule.type_ == .import_rule
		assert rule.has_scope()
	}
	assert rules[0].css_text() == '@import url("a.css") scope;'
	assert rules[1].css_text() == '@import url("b.css") scope;'
	assert rules[2].css_text() == '@import url("c.css") scope(.scope, .other);'
	assert rules[3].css_text() == '@import url("d.css") scope(to (.limit));'
	assert rules[4].css_text() == '@import url("e.css") scope((.scope) to (.limit));'
	assert serialize_a_group_of_selectors(rules[4].import_scope_start_selectors()?) == '.scope'
	assert serialize_a_group_of_selectors(rules[4].import_scope_end_selectors()?) == '.limit'
}

fn test_import_modifiers_parse_in_any_order_and_serialize_canonically() {
	rules := scoped_import_rules('
		@import url(a.css) layer(foo) supports(display: block) scope(.scope) screen;
		@import url(b.css) supports(display: block) scope(.scope) layer(bar) screen;
	')
	assert rules.len == 2
	assert rules[0].css_text() == '@import url("a.css") layer(foo) scope(.scope) supports(display: block) screen;'
	assert rules[1].css_text() == '@import url("b.css") layer(bar) scope(.scope) supports(display: block) screen;'
	assert rules[0].layer_name()? == 'foo'
	assert rules[1].layer_name()? == 'bar'
	assert rules[0].supports_text()? == 'display: block'
	assert rules[1].supports_text()? == 'display: block'
	assert rules[0].import_media()?.media_text() == 'screen'
	assert rules[1].import_media()?.media_text() == 'screen'
}

fn test_import_scope_rejects_invalid_selectors() {
	assert scoped_import_rules('@import url(a.css) scope(.root::before);').len == 0
	assert scoped_import_rules('@import url(a.css) scope(to);').len == 0
	assert scoped_import_rules('@import url(a.css) scope(to ());').len == 0
}
