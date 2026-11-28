module css

import dom

fn environment_substitution_data(tone string) &dom.CSSCustomPropertyData_ {
	return dom.CSSCustomPropertyData_.create({
		'--tone': dom.CSSCustomProperty_{
			value: custom_property_bridge_value(parse_custom_property_value(tone))
		}
	}, none)
}

// Elements with one custom property environment share the resolved value of a
// var() declaration within a style batch; another environment resolves its
// own, each equal to an uncached resolution, and every element still records
// its var() use. Outside a batch nothing is kept.
fn test_var_declarations_resolve_once_per_environment_within_a_batch() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	shared := environment_substitution_data('rgb(1, 2, 3)')
	other := environment_substitution_data('rgb(4, 5, 6)')
	mut elements := []&dom.Element{}
	for index in 0 .. 4 {
		element := document.create_element('span') or { panic(err) }
		mut abstract := dom.AbstractElement.new(element, none)
		abstract.set_custom_property_data(if index < 3 { shared } else { other })
		elements << element
	}
	declaration := parse_css_value(ParsingParams{}, 'var(--tone, red)', .color) or { panic('declaration') }
	computer := css_style_computer_for(document)
	computer.begin_computed_property_page_batch()
	mut results := []&dom.StyleValue{}
	for element in elements {
		results << resolve_cascade_declaration_value(dom.AbstractElement.new(element, none), .color, declaration)
		assert element.style_uses_var_css_function()
	}
	cache := computer.environment_substitutions_
	assert cache != unsafe { nil }
	assert cache.entries.len == 2
	computer.end_computed_property_page_batch()
	assert voidptr(results[0]) == voidptr(results[1]) && voidptr(results[1]) == voidptr(results[2])
	assert voidptr(results[3]) != voidptr(results[0])
	typed := style_value_logic_from_dom(.color, declaration) or { panic('typed') }
	for index, element in elements {
		uncached := resolve_unresolved_style_value_for_property(dom.AbstractElement.new(element, none),
			.color, typed as UnresolvedStyleValue)
		assert results[index].css_text == uncached.css_text
	}
	assert results[0].css_text != results[3].css_text
	first := resolve_cascade_declaration_value(dom.AbstractElement.new(elements[0], none), .color, declaration)
	again := resolve_cascade_declaration_value(dom.AbstractElement.new(elements[0], none), .color, declaration)
	assert voidptr(first) != voidptr(again)
}

// Substitutions reading more than the environment always resolve.
fn test_environment_substitution_reuse_excludes_element_dependent_functions() {
	assert environment_substitution_applies(UnresolvedStyleValue{substitution_functions_presence: SubstitutionFunctionsPresence{var: true, env: true}})
	for presence in [SubstitutionFunctionsPresence{var: true, attr: true}, SubstitutionFunctionsPresence{if_: true},
		SubstitutionFunctionsPresence{inherit: true}, SubstitutionFunctionsPresence{var: true, custom_function: true}] {
		assert !environment_substitution_applies(UnresolvedStyleValue{substitution_functions_presence: presence})
	}
}
