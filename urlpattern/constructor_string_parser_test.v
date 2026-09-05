module urlpattern

fn assert_constructor_components(input string, protocol ?string, hostname ?string, port ?string, pathname ?string, search ?string, hash ?string) {
	result := parse_constructor_string(input) or { panic(err) }
	assert_optional_constructor_component(result.protocol, protocol)
	assert_optional_constructor_component(result.hostname, hostname)
	assert_optional_constructor_component(result.port, port)
	assert_optional_constructor_component(result.pathname, pathname)
	assert_optional_constructor_component(result.search, search)
	assert_optional_constructor_component(result.hash, hash)
}

fn assert_optional_constructor_component(actual ?string, expected ?string) {
	if actual_value := actual {
		expected_value := expected or {
			assert false
			return
		}
		assert actual_value == expected_value
	} else if _ := expected {
		assert false
	}
}

// Cases translated from Tests/LibURL/TestURLPatternConstructorStringParser.cpp.
fn test_constructor_string_parser_upstream_cases() {
	assert_constructor_components('http://www.serenityos.org', 'http', 'www.serenityos.org', '', none, none, none)
	assert_constructor_components('/books/(\\d+)', none, none, none, '/books/(\\d+)', none, none)
	assert_constructor_components('https://example.com/2022/feb/*', 'https', 'example.com', '', '/2022/feb/*', none, none)
	assert_constructor_components('https://cdn-*.example.com/*.jpg', 'https', 'cdn-*.example.com', '', '/*.jpg', none, none)
	assert_constructor_components('https://example.com/#foo', 'https', 'example.com', '', '/', '', 'foo')
	assert_constructor_components('https://example.com/?q=*&v=?&hmm={}&umm=()', 'https', 'example.com', '', '/', 'q=*&v=?&hmm={}&umm=()', none)
	assert_constructor_components('https://{sub.}?example.com/foo', 'https', '{sub.}?example.com', '', '/foo', none, none)
	assert_constructor_components('http://[\\:\\:1]:8080', 'http', '[\\:\\:1]', '8080', none, none, none)
	assert_constructor_components('data\\:foobar', 'data', '', '', 'foobar', none, none)
	assert_constructor_components('foo://bar', 'foo', 'bar', '', none, none, none)
	assert_constructor_components('http://[:address]/', 'http', '[:address]', '', '/', none, none)
}
