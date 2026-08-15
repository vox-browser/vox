module http

fn values_of(name string, value string) ?[]string {
	return Header{ name: name, value: value }.extract_header_values()
}

fn test_token_list_header_parses_tokens() {
	assert values_of('Access-Control-Allow-Methods', 'GET, POST')? == ['GET', 'POST']
	assert values_of('Access-Control-Expose-Headers', 'X-Foo, X-Bar')? == ['X-Foo', 'X-Bar']
	// Whitespace is trimmed and empty parts are dropped.
	assert values_of('Access-Control-Allow-Headers', '  X-Foo , X-Bar ')? == ['X-Foo', 'X-Bar']
	assert values_of('Access-Control-Allow-Headers', 'X-Foo,,X-Bar')? == ['X-Foo', 'X-Bar']
}

fn test_token_list_header_allows_empty() {
	// A token-list (#field-name) header may parse to an empty list.
	assert values_of('Access-Control-Allow-Headers', '')? == []string{}
	assert values_of('Access-Control-Allow-Methods', '   ')? == []string{}
}

fn test_token_list_header_rejects_non_token() {
	// A part that is not a valid header name is a failure.
	assert values_of('Access-Control-Allow-Headers', 'X-Foo, bad header') == none
	assert values_of('Access-Control-Allow-Methods', 'GET, x:y') == none
}

fn test_one_or_more_field_name_headers_require_a_token() {
	// The 1#field-name headers need at least one token.
	assert values_of('Access-Control-Request-Headers', 'X-Foo, X-Bar')? == ['X-Foo', 'X-Bar']
	assert values_of('Accept-Ranges', 'bytes')? == ['bytes']
	// An empty or whitespace-only value is a failure.
	assert values_of('Access-Control-Request-Headers', '') == none
	assert values_of('Accept-Ranges', '  ') == none
}

fn test_other_header_returns_raw_value() {
	// Any other header yields a single value: the raw value, even if it contains commas.
	assert values_of('Content-Type', 'text/html; charset=utf-8')? == ['text/html; charset=utf-8']
	assert values_of('X-Custom', 'a, b')? == ['a, b']
}

fn test_name_match_is_case_insensitive() {
	assert values_of('access-control-allow-methods', 'GET')? == ['GET']
	assert values_of('ACCEPT-RANGES', 'bytes')? == ['bytes']
}
