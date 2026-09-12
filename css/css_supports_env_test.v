module css

fn supports_env_condition(text string) &Supports {
	return parse_css_supports(ParsingParams{}, text) or {
		panic('invalid supports condition: ${text}')
	}
}

fn test_supports_env_matches_known_environment_variables() {
	supported := supports_env_condition('env(preferred-text-scale)')
	assert supported.matches_condition()
	assert supported.condition.kind == .supports_env
	assert supported.to_string() == 'env(preferred-text-scale)'
	assert supported.condition.dump(0) == 'Env: `preferred-text-scale` matches=true\n'

	viewport_segment := supports_env_condition('env(viewport-segment-width)')
	assert viewport_segment.matches_condition()
	assert viewport_segment.condition.kind == .supports_env
}

fn test_supports_env_rejects_unknown_and_invalid_environment_variables() {
	unknown := supports_env_condition('env(definitely-unknown)')
	assert !unknown.matches_condition()
	assert unknown.condition.kind == .supports_env
	assert unknown.to_string() == 'env(definitely-unknown)'

	invalid := supports_env_condition('env(preferred-text-scale extra)')
	assert !invalid.matches_condition()
	assert invalid.condition.kind == .general_enclosed
}

fn test_supports_env_participates_in_boolean_conditions() {
	condition := supports_env_condition('env(preferred-text-scale) and (display: grid)')
	assert condition.matches_condition()
	assert condition.to_string() == 'env(preferred-text-scale) and (display: grid)'
}
