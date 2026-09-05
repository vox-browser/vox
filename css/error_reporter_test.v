module css

fn test_error_reporter_aggregates_identical_complete_errors() {
	error := ParsingError(InvalidPropertyError{
		property_name: 'codex-error-reporter-property'
		value_string:  'codex-value'
		description:   'first diagnostic'
	})
	mut reporter := ErrorReporter{
		errors: map[string]ParsingErrorMetadata{}
	}

	reporter.report(error)
	reporter.report(error)

	assert reporter.number_of_errors() == 1
	assert reporter.occurrences(error) == 2
	assert serialize_parsing_error(error) == "Property 'codex-error-reporter-property' in style rule has invalid value `codex-value`."
}

fn test_error_reporter_identity_includes_non_serialized_fields() {
	first := ParsingError(InvalidPropertyError{
		property_name: 'codex-error-identity-property'
		value_string:  'codex-value'
		description:   'first diagnostic'
	})
	second := ParsingError(InvalidPropertyError{
		property_name: 'codex-error-identity-property'
		value_string:  'codex-value'
		description:   'second diagnostic'
	})
	mut reporter := ErrorReporter{
		errors: map[string]ParsingErrorMetadata{}
	}

	reporter.report(first)
	reporter.report(second)

	assert serialize_parsing_error(first) == serialize_parsing_error(second)
	assert reporter.number_of_errors() == 2
	assert reporter.occurrences(first) == 1
	assert reporter.occurrences(second) == 1
}

fn test_parser_error_entry_points_report_to_singleton() {
	property_error := ParsingError(UnknownPropertyError{
		property_name: 'codex-singleton-property'
	})
	location_error := InvalidRuleLocationError{
		outer_rule_name: '@codex-outer'
		inner_rule_name: '@codex-inner'
	}
	property_before := ErrorReporter.the().occurrences(property_error)
	location_before := ErrorReporter.the().occurrences(ParsingError(location_error))
	assert property_before == 0
	assert location_before == 0

	parser_report_error(property_error)
	report_invalid_rule_location(location_error)

	assert ErrorReporter.the() == ErrorReporter.the()
	assert ErrorReporter.the().occurrences(property_error) == property_before + 1
	assert ErrorReporter.the().occurrences(ParsingError(location_error)) == location_before + 1
}
