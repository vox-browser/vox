module urlpattern

fn test_absolute_string_pattern_and_component_accessors() {
	pattern := URLPattern.construct_impl(URLPatternInput('https://*.example.com/books/*'), none, URLPatternOptions{})!
	assert pattern.protocol() == 'https'
	assert pattern.hostname() == '*.example.com'
	assert pattern.pathname() == '/books/*'
	assert pattern.test(URLPatternInput('https://api.example.com/books/42'), none)!
	assert !pattern.test(URLPatternInput('http://api.example.com/books/42'), none)!
}

fn test_create_and_constructor_share_the_initialize_algorithm() {
	created := URLPattern.create(URLPatternInput('/items/:id'), 'https://example.test', URLPatternOptions{})!
	constructed := URLPattern.new(URLPatternInput('/items/:id'), 'https://example.test', URLPatternOptions{})!
	assert created.protocol() == constructed.protocol()
	assert created.hostname() == constructed.hostname()
	assert created.pathname() == constructed.pathname()
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
	pattern := URLPattern.new(URLPatternInput('https://example.test/match'), none, URLPatternOptions{})!
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

fn test_upstream_pattern_compiler_regexp_and_modifiers() {
	regexp_pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		pathname: '/books/:id(\\d+)'
	}), none, URLPatternOptions{})!
	match_result := regexp_pattern.exec(URLPatternInput(URLPatternInit{
		pathname: '/books/1234'
	}), none)!
	assert match_result.matched
	assert match_result.result.pathname.groups['id'] == '1234'
	assert !regexp_pattern.test(URLPatternInput(URLPatternInit{
		pathname: '/books/not-a-number'
	}), none)!

	optional_pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		pathname: '/foo/:bar?'
	}), none, URLPatternOptions{})!
	assert optional_pattern.test(URLPatternInput(URLPatternInit{
		pathname: '/foo'
	}), none)!
	assert optional_pattern.test(URLPatternInput(URLPatternInit{
		pathname: '/foo/value'
	}), none)!
	assert !optional_pattern.test(URLPatternInput(URLPatternInit{
		pathname: '/foobar'
	}), none)!
}

fn test_upstream_init_processing_and_default_port() {
	pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		protocol: 'https'
		hostname: 'example.com'
		port: '443'
		pathname: ':file.html'
		base_url: 'https://example.com/'
	}), none, URLPatternOptions{})!
	assert pattern.port() == ''
	assert pattern.test(URLPatternInput('https://example.com/index.html'), none)!
	assert !pattern.test(URLPatternInput('https://example.com/index.txt'), none)!
}

fn test_exec_records_string_base_url_input() {
	pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		pathname: '/foo/bar'
	}), none, URLPatternOptions{})!
	result := pattern.exec(URLPatternInput('./foo/bar'), 'https://example.com')!
	assert result.matched
	assert result.result.inputs.len == 2
}

fn test_wpt_pathname_modifier_matrix() {
	cases := [
		['/foo/:bar?', '/foo', 'true'],
		['/foo/:bar?', '/foo/value', 'true'],
		['/foo/:bar?', '/foo/', 'false'],
		['/foo/:bar+', '/foo/value', 'true'],
		['/foo/:bar+', '/foo/value/more', 'true'],
		['/foo/:bar+', '/foo', 'false'],
		['/foo/:bar*', '/foo', 'true'],
		['/foo/:bar*', '/foo/value/more', 'true'],
		['/foo{/bar}?', '/foo', 'true'],
		['/foo{/bar}?', '/foo/bar', 'true'],
		['/foo{/bar}+', '/foo/bar/bar', 'true'],
		['/foo{/bar}+', '/foo', 'false'],
	]
	for case in cases {
		pattern := URLPattern.new(URLPatternInput(URLPatternInit{
			pathname: case[0]
		}), none, URLPatternOptions{})!
		matched := pattern.test(URLPatternInput(URLPatternInit{
			pathname: case[1]
		}), none)!
		assert matched == (case[2] == 'true'), '${case[0]} against ${case[1]}'
	}
}

fn test_wpt_canonicalization_cases() {
	dot_pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		pathname: '/foo/bar'
	}), none, URLPatternOptions{})!
	assert dot_pattern.test(URLPatternInput(URLPatternInit{
		pathname: '/foo/./bar'
	}), none)!

	unicode_pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		hostname: 'café.com'
		pathname: '/café'
		search: 'q=café'
		hash: 'café'
	}), none, URLPatternOptions{})!
	assert unicode_pattern.hostname() == 'xn--caf-dma.com'
	assert unicode_pattern.pathname() == '/caf%C3%A9'
	assert unicode_pattern.search() == 'q=caf%C3%A9'
	assert unicode_pattern.hash() == 'caf%C3%A9'
	assert unicode_pattern.test(URLPatternInput(URLPatternInit{
		hostname: 'café.com'
		pathname: '/café'
		search: 'q=café'
		hash: 'café'
	}), none)!
}

fn test_wpt_opaque_path_and_alternation() {
	pattern := URLPattern.new(URLPatternInput(URLPatternInit{
		protocol: 'about'
		pathname: '(blank|sourcedoc)'
	}), none, URLPatternOptions{})!
	assert pattern.has_reg_exp_groups()
	assert pattern.test(URLPatternInput('about:blank'), none)!
	assert pattern.test(URLPatternInput('about:sourcedoc'), none)!
	assert !pattern.test(URLPatternInput('about:other'), none)!
}

fn test_wpt_invalid_and_duplicate_patterns_throw() {
	URLPattern.new(URLPatternInput(URLPatternInit{
		pathname: '/(\\m)'
	}), none, URLPatternOptions{}) or {
		assert err.msg().contains('RegExp')
		URLPattern.new(URLPatternInput(URLPatternInit{
			pathname: '/:name/:name'
		}), none, URLPatternOptions{}) or {
			assert err.msg().contains('duplicate name')
			return
		}
		assert false
		return
	}
	assert false
}
