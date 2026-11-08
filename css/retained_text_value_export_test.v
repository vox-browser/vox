module css

import platform

fn retained_text_export_graph() StyleValue {
	source := r'var(--esc\61 ped, calc(7px + env(safe-area-inset-left, 2px)))'
	tokens := ParserTokenStream.from_source(source.clone(), 'utf-8').values
	return StyleValue(StyleValueList.create([
		StyleValue(UnresolvedStyleValue.create_with_original_source_text(tokens, source.clone())),
		StyleValue(StringStyleValue.create('β😀 family'.clone())),
		StyleValue(CustomIdentStyleValue{
			custom_ident_: 'Multi Word'.clone()
			family_identifiers_: ['Multi'.clone(), 'Word'.clone()]
		}),
	], .comma, .no))
}

fn test_retained_text_export_owns_nested_components_strings_and_identifiers() {
	expected := retained_text_export_graph()
	scratch := platform.begin_thread_scratch('retained text export input')
	temporary := retained_text_export_graph()
	assert property_value_can_export(temporary) == !disable_retained_text_value_export
	scratch.leave()
	owned := export_property_value(temporary)
	scratch.finish()
	gc_collect()
	assert owned.serialize(.normal) == expected.serialize(.normal)
	if owned is StyleValueList {
		unresolved := owned.values_[0] as UnresolvedStyleValue
		assert unresolved.includes_var_function() && unresolved.includes_env_function()
		assert unresolved.tokens[0].function().value[0].token().value == '--escaped'
		family := owned.values_[2] as CustomIdentStyleValue
		assert family.family_identifiers_ == ['Multi', 'Word']
	} else { panic('missing owned list') }
}

fn test_retained_text_workspace_preserves_property_grammar_and_dependencies() {
	for property, source in {
		PropertyID.width: r'var(--esc\61 ped, calc(7px + env(safe-area-inset-left, 2px)))'
		.font_family: r'"f\61 mily", Multi Word, serif'
		.animation_name: r'n\61 me, other'
	} {
		mut parser := Parser.from_css_text(source)
		expected := parser.parse_css_value(property)?
		actual := parse_css_value_logic(property, source)?
		gc_collect()
		assert actual.serialize(.normal) == expected.serialize(.normal)
		if expected is UnresolvedStyleValue {
			assert actual is UnresolvedStyleValue
			assert actual.substitution_functions_presence == expected.substitution_functions_presence
		}
	}
}
