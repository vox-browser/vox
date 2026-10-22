module css

import dom

fn test_selector_conversion_retires_discarded_prelude_components() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut small_growth := i64(0)
		for count in [1, 1, 2048] {
			source := '.probe' + ' /* separator */'.repeat(count) + '{ color: red; }'
			mut owner := document.enter_native_storage()
			before := document.native_storage().arena.usage().used
			sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, false)
			growth := document.native_storage().arena.usage().used - before
			if count == 1 {
				small_growth = growth
			} else {
				assert growth < small_growth + 16384, '${growth} retained versus ${small_growth}'
			}
			rule := sheet.css_rules().item(0)?
			assert rule.selectors.selectors[0].text() == '.probe'
			assert rule.style()?.get_property_value('color') == 'red'
			owner.finish()
		}
		document.release_native_storage()
	}
}

fn test_selector_inputs_keep_escaped_and_nested_payloads_after_retirement() {
	for source in [
		r'.\70 robe:is([data-label="esc\61 ped"], :has(> .child)) { color: red; }',
		'@namespace s url("http://www.w3.org/2000/svg"); s|svg:not(.other) { fill: blue; }',
		'.parent { > .child, &:hover { color: green; } }',
	] {
		mut legacy := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
		expected := legacy.parse_as_css_stylesheet(none, none)
		actual := parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, false)
		assert actual.css_rules().length() == expected.css_rules().length()
		assert actual.css_rules().length() > 0
		for index, rule in actual.css_rules().rules {
			assert rule.css_text() == expected.css_rules().rules[index].css_text()
		}
	}
}
