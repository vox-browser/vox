module urlpattern

fn test_absolute_string_pattern_and_component_accessors() {
	pattern :=
		URLPattern.new(URLPatternInput('https://*.example.com/books/*'), none, URLPatternOptions{})!
	assert pattern.protocol() == 'https'
	assert pattern.hostname() == '*.example.com'
	assert pattern.pathname() == '/books/*'
	assert pattern.test(URLPatternInput('https://api.example.com/books/42'), none)!
	assert !pattern.test(URLPatternInput('http://api.example.com/books/42'), none)!
}

fn test_named_path_groups_and_base_url() {
	pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		pathname: '/users/:id'
		base_url: 'https://example.test'
	}), none, URLPatternOptions{})!
	execution := pattern.exec(URLPatternInput('https://example.test/users/alex'), none)!
	assert execution.matched
	assert execution.result.pathname.groups['id'] == 'alex'
	assert pattern.test(URLPatternInput('/users/alex'), 'https://example.test')!
}

fn test_exec_returns_nullable_non_match_instead_of_throwing() {
	pattern :=
		URLPattern.new(URLPatternInput('https://example.test/match'), none, URLPatternOptions{})!
	result := pattern.exec(URLPatternInput('https://example.test/other'), none)!
	assert !result.matched
}

fn test_case_option_and_invalid_relative_constructor() {
	insensitive := URLPattern.new(URLPatternInput('https://EXAMPLE.test/Case'), none, URLPatternOptions{
		ignore_case: true
	})!
	assert insensitive.test(URLPatternInput('https://example.test/case'), none)!
	URLPattern.new(URLPatternInput('/relative'), none, URLPatternOptions{}) or {
		assert err.msg().contains('baseURL')
		return
	}
	assert false
}
