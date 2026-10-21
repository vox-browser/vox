module css

import dom

fn test_fixed_marker_styles_do_not_populate_the_named_counter_registry() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('li') or { panic(err) }
	abstract_element := dom.AbstractElement.new(element, none)
	scope := css_style_scope_for(abstract_element)
	assert scope.needs_counter_style_cache_update
	for name in ['disc', 'decimal'] {
		counter := if name == 'disc' { builtin_counter_styles().disc } else { builtin_counter_styles().decimal }
		style := ListStyleType{kind:.counter_style, name:name, counter_style:counter}
		registered := registered_counter_styles_for_marker(style, abstract_element)
		assert registered.len == 0
		for ordinal in [i32(-2147483648), -1, 0, 1, 2147483647] {
			representation := generate_a_counter_representation(counter, registered, ordinal)
			if name == 'disc' { assert representation == '•' }
			else { assert representation == ordinal.str() }
		}
		assert scope.needs_counter_style_cache_update
	}
}

fn test_named_markers_keep_author_definitions_and_fallback_resolution() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('li') or { panic(err) }
	add_document_author_style_sheet(document, '@counter-style marker {system:fixed;symbols:"X";fallback:other} @counter-style other{system:cyclic;symbols:"Y"}')
	abstract_element := dom.AbstractElement.new(element, none)
	style := ListStyleType{kind:.counter_style, name:'marker'}
	registered := registered_counter_styles_for_marker(style, abstract_element)
	assert generate_a_counter_representation(registered['marker'], registered, 1) == 'X'
	assert generate_a_counter_representation(registered['marker'], registered, 2) == 'Y'
	holder := css_author_style_sheets_for(document)
	mut rule := holder.sheets[0].rules.rules[1].counter_style_rule_value() or { panic('missing rule') }
	rule.set_symbols('"Z"')
	updated := registered_counter_styles_for_marker(style, abstract_element)
	assert generate_a_counter_representation(updated['marker'], updated, 2) == 'Z'
}
