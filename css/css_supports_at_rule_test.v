module css

fn parse_supports_at_rule_condition(text string) &Supports {
	mut parser := Parser.from_css_text(text)
	return parser.parse_as_supports() or { panic('invalid supports condition: ${text}') }
}

fn test_supports_at_rule_recognizes_supported_rules() {
	for name in [
		'supports',
		'media',
		'counter-style',
		'import',
		'container',
		'font-face',
		'font-feature-values',
		'function',
		'keyframes',
		'-webkit-keyframes',
		'layer',
		'namespace',
		'page',
		'property',
		'swash',
		'top-left',
	] {
		condition := parse_supports_at_rule_condition('at-rule(@${name})')
		assert condition.matches_condition(), '@${name} should be supported'
		assert condition.condition.kind == .supports_at_rule
	}
}

fn test_supports_at_rule_rejects_unknown_and_invalid_rules() {
	assert !parse_supports_at_rule_condition('at-rule(@doesnotexist)').matches_condition()
	assert !parse_supports_at_rule_condition('at-rule(@charset)').matches_condition()

	for invalid in ['at-rule(supports)', 'at-rule(@supports extra)',
		'at-rule(@counter-style; system: fixed)'] {
		condition := parse_supports_at_rule_condition(invalid)
		assert !condition.matches_condition(), invalid
		assert condition.condition.kind == .general_enclosed
	}
}

fn test_supports_at_rule_composes_and_serializes() {
	condition := parse_supports_at_rule_condition('at-rule( @MeDiA ) and (color: red)')
	assert condition.matches_condition()
	assert condition.to_string() == 'at-rule(@MeDiA) and (color: red)'

	assert !parse_supports_at_rule_condition('not at-rule(@supports)').matches_condition()
	assert parse_supports_at_rule_condition('not at-rule(@unknown)').matches_condition()
	assert parse_supports_at_rule_condition('(color: red) or at-rule(@unknown)').matches_condition()
}
