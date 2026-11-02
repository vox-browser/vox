module css

import platform

fn test_retained_css_errors_own_their_keys_messages_and_map_storage() {
	mut reporter := ErrorReporter{}
	mut scratch := platform.new_arena('CSS diagnostic input')
	entry := scratch.enter()
	error := ParsingError(InvalidSelectorError{
		rule_name:    'rule ${17}'
		value_string: '.invalid-${23}'
		description:  'description ${42}'
	})
	reporter.report(error)
	scratch.leave(entry)
	scratch.release()
	retained := ParsingError(InvalidSelectorError{
		rule_name:    'rule 17'
		value_string: '.invalid-23'
		description:  'description 42'
	})
	assert reporter.occurrences(retained) == 1
	reporter.report(retained)
	assert reporter.occurrences(retained) == 2
	assert reporter.errors[parsing_error_key(retained)].message == serialize_parsing_error(retained)
}

fn test_repeated_css_errors_keep_rehashed_map_storage_after_the_caller_retires() {
	for count in 1 .. 129 {
		mut reporter := ErrorReporter{}
		for index in 0 .. count {
			reporter.report(ParsingError(UnknownPropertyError{ property_name: 'arena-error-${index}' }))
		}
		mut scratch := platform.new_arena('repeated CSS diagnostics')
		entry := scratch.enter()
		for index in 0 .. count {
			reporter.report(ParsingError(UnknownPropertyError{ property_name: 'arena-error-${index}' }))
		}
		scratch.leave(entry)
		scratch.reset()
		reuse := scratch.enter()
		mut checksum := 0
		for _ in 0 .. 32 {
			overwrite := []u8{len: 4096, init: 0xa5}
			checksum += int(overwrite[0])
		}
		assert checksum == 32 * 0xa5
		scratch.leave(reuse)
		scratch.release()
		assert reporter.number_of_errors() == count
		for index in 0 .. count {
			assert reporter.occurrences(ParsingError(UnknownPropertyError{ property_name: 'arena-error-${index}' })) == 2
		}
	}
}
