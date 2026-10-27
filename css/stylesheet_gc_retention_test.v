module css

import strings

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn make_retained_stylesheet() &CSSStyleSheet {
	mut source := strings.new_builder(32_768)
	for i in 0 .. 128 {
		source.write_string('.item-${i}[data-label="name-${i}"] {
			--label: var(--base, "value-${i}"); content: "value-${i}";
			width: calc(5px + 2%);
		}\n')
	}
	return parse_css_stylesheet_with_parser(source.str(), none)
}

// Pointer-free buffers can be atomic, but the CSSOM graph, nested component
// values, and borrowed token strings must remain traced after parsing ends.
fn test_stylesheet_graph_retains_nested_values_after_parser_and_arena_release() {
	sheet := make_retained_stylesheet()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		rules := sheet.css_rules()
		assert rules.length() == 128
		for i in 0 .. 128 {
			rule := rules.item(uint(i)) or { panic('missing rule') }
			assert rule.selector_text() == '.item-${i}[data-label="name-${i}"]'
			declarations := rule.style() or { panic('missing declaration') }
			assert declarations.get_property_value('content') == '"value-${i}"'
			assert declarations.get_property_value('--label').contains('value-${i}')
			assert declarations.get_property_value('width').contains('2%')
		}
	}
}
