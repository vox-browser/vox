module css

import platform

fn test_substitution_presence_retains_no_discarded_argument_grammar() {
	values := parse_component_values_for_value_logic('calc(1px + var(--x)) [ENV(foo)] { inherit(--y, attr(data-x)) } if(style(--a): 1px)')
	mut presence := SubstitutionFunctionsPresence{}
	collect_arbitrary_substitution_function_presence(values, mut presence)!
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		presence = SubstitutionFunctionsPresence{}
		collect_arbitrary_substitution_function_presence(values, mut presence)!
		assert presence.attr && presence.env && presence.if_ && presence.inherit && presence.var
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	// The single-component entry used by property parsing has the same boundary.
	for _ in 0 .. 128 {
		collect_arbitrary_substitution_function_presence_from_component(values[0], mut presence)!
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}

fn test_substitution_validation_error_and_partial_flags_survive_input_retirement() {
	input := platform.begin_thread_scratch('invalid substitution input')
	values := parse_component_values_for_value_logic('var(--valid) env()')
	input.leave()
	mut presence := SubstitutionFunctionsPresence{}
	mut message := ''
	if _ := collect_arbitrary_substitution_function_presence(values, mut presence) {
		assert false
	} else {
		message = err.msg()
	}
	input.finish()
	assert presence.var && !presence.env
	assert message == 'invalid arbitrary substitution function syntax'
}

fn test_leaf_validation_preserves_existing_flags_and_nested_argument_failures() {
	for source in ['', 'red', '17px 20%', '"var(--literal)"', '--literal, none',
		'calc(1px + var(--x))', '[red env()]', 'red var() blue', 'attr(data-x) var(--valid) env()'] {
		values := parse_component_values_for_value_logic(source)
		mut expected := SubstitutionFunctionsPresence{attr:true}
		mut expected_error := ''
		collect_substitution_presence_in_workspace(values,mut expected) or { expected_error = err.msg() }
		mut actual := SubstitutionFunctionsPresence{attr:true}
		mut actual_error := ''
		collect_arbitrary_substitution_function_presence(values,mut actual) or { actual_error = err.msg() }
		assert actual == expected
		assert actual_error == expected_error
		for value in values {
			mut expected_component := SubstitutionFunctionsPresence{env:true}
			mut expected_component_error := ''
			collect_substitution_presence_from_component_in_workspace(value,mut expected_component) or {
				expected_component_error = err.msg()
			}
			mut actual_component := SubstitutionFunctionsPresence{env:true}
			mut actual_component_error := ''
			collect_arbitrary_substitution_function_presence_from_component(value,mut actual_component) or {
				actual_component_error = err.msg()
			}
			assert actual_component == expected_component
			assert actual_component_error == expected_component_error
		}
	}
}
