module url

fn authority_encoding_reference(points []rune, start int, end int) string {
	mut result := ''
	for i := start; i < end; i++ { result += points[i].str() }
	return result
}

fn test_authority_encoding_matches_every_unicode_code_point_and_invalid_runes() {
	mut points := [rune(0)]
	for value in 0 .. 0x110000 {
		points[0] = rune(value)
		actual := parser_runes_to_string(points, 0, 1)
		assert actual == rune(value).str(), '${value}'
	}
	for value in [rune(0x110000), rune(0x7fffffff), rune(u32(0xffffffff))] {
		points[0] = value
		assert parser_runes_to_string(points, 0, 1) == value.str()
	}
}

fn test_authority_encoding_preserves_subranges_nulls_and_independent_bytes() {
	mut points := 'prefix\x00é界😀user:pass@[2001:db8::1]:8443'.runes()
	for start in 0 .. points.len + 1 {
		for end in start .. points.len + 1 {
			assert parser_runes_to_string(points, start, end) ==
				authority_encoding_reference(points, start, end)
		}
	}
	assert parser_runes_to_string(points, 4, 3) == ''
	owned := parser_runes_to_string(points, 6, points.len)
	points[6] = `X`
	assert owned == '\x00é界😀user:pass@[2001:db8::1]:8443'
	assert parser_runes_to_string([], 0, 0) == ''
}

fn test_authority_encoding_preserves_authority_parsing_and_rejections() {
	cases := {
		'https://user:pass@faß.de:443/a/../b?q=x y#f z':
			'https://user:pass@xn--fa-hia.de/b?q=x%20y#f%20z'
		'https://user:pass@[2001:db8::1]:8443/a':
			'https://user:pass@[2001:db8::1]:8443/a'
		'https://測試:8443/': 'https://xn--g6w251d:8443/'
		'http://0x7f.1/': 'http://127.0.0.1/'
		'https://example.test:443/': 'https://example.test/'
	}
	for input, expected in cases {
		assert parse(input)?.serialize(false) == expected
	}
	for input in ['https://[bad]/', 'https://example.test:65536/',
		'https://xn--a/', 'https://exa\x00mple.test/'] {
		assert parse(input) == none
	}
}
