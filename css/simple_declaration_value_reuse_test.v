module css

import dom

fn test_simple_declaration_reuse_preserves_grammar_importance_and_mutation() {
	mut document := dom.Document.create(dom.URL{value: 'https://declarations.example/base/'})
	defer { document.finalize() }
	source := '.card{width:10px;width:25%;color:#123abc!important;color:red;display:invalid;--size:7px;height:var(--size);margin:1px 2px;background-image:url(../image.png)}'
	params := ParsingParams{document: document}
	mut expected_parser := RuleSelectorParser.create_for_stylesheet(params, source)
	expected := expected_parser.parse_as_css_stylesheet(none, none)
	for _ in 0 .. 3 {
		mut sheet := parse_css_stylesheet_in_workspace(params, source, none, none, true)
		mut actual := sheet.rules.rules[0].style()?
		control := expected.rules.rules[0].style()?
		for property in ['width', 'color', 'display', '--size', 'height', 'margin', 'background-image'] {
			assert actual.get_property_value(property) == control.get_property_value(property)
			assert actual.get_property_priority(property) == control.get_property_priority(property)
		}
		assert actual.get_property_value('display') == ''
		actual.set_property('width', '999px', '')!
		assert control.get_property_value('width') == '25%'
	}
}

fn test_context_sensitive_declaration_spellings_keep_the_ordinary_parser() {
	for text in [r'url(../image.png)', r'"family"', r'var(--x, 1px)',
		r'calc(1px + 2%)', r'attr(data-size px)', r'v\61 r(--x)', 'env(safe-area-inset-top)',
		'light-dark(red, blue)', 'var(--x) trailing'] {
		assert !simple_declaration_spelling(text)
	}
}
