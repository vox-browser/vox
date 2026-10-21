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
