module css

import platform

fn test_retained_css_errors_own_their_keys_messages_and_map_storage() {
	mut reporter := ErrorReporter{}
	mut scratch := platform.new_arena('CSS diagnostic input')
	entry := scratch.enter()
	error := ParsingError(InvalidSelectorError{
		rule_name: 'rule ${17}'
		value_string: '.invalid-${23}'
		description: 'description ${42}'
	})
	reporter.report(error)
	scratch.leave(entry)
	scratch.release()
	retained := ParsingError(InvalidSelectorError{
		rule_name: 'rule 17'
		value_string: '.invalid-23'
		description: 'description 42'
	})
	assert reporter.occurrences(retained) == 1
	reporter.report(retained)
	assert reporter.occurrences(retained) == 2
	assert reporter.errors[parsing_error_key(retained)].message == serialize_parsing_error(retained)
}
