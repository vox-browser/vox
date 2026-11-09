module css

import dom

fn test_alignment_computation_preserves_specified_values_and_canonicalizes_aliases() {
	for property in [PropertyID.align_content, .justify_content, .align_items, .justify_items, .align_self, .justify_self] {
		for source, expected in {'flex-start':'flow-start', 'flex-end':'flow-end', 'safe flex-start':'safe flow-start', 'unsafe flex-end':'unsafe flow-end', 'flow-start':'flow-start'} {
			parsed := parse_css_value(ParsingParams{}, source, property) or { panic(source) }
			assert parsed.css_text == source
			value := typed_style_value_logic_from_dom(parsed) or { panic('typed') }
			assert alignment_computed_value(value).serialize(.normal) == expected
		}
	}
}

fn test_legacy_justify_items_resolves_against_each_actual_parent() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	parent.as_node().append_child(child.as_node())!
	computer := StyleComputer.new(document)
	for source, expected in {'legacy left':'legacy left', 'legacy right':'legacy right', 'legacy center':'legacy center', 'flex-end':'normal', 'normal':'normal'} {
		parent.set_attribute_value('style', 'justify-items:${source}')
		mut abstract_parent := dom.AbstractElement.new(parent, none)
		parent_style := computer.compute_style(abstract_parent)
		abstract_parent.set_computed_properties(computed_properties_to_dom(parent_style))
		style := computer.compute_style(dom.AbstractElement.new(child, none))
		assert style.property(.justify_items, .no)?.css_text == expected
	}
}
