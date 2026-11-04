module url

fn url_input_filter_reference(raw string, trim_edges bool) []rune {
	mut points := raw.runes()
	if trim_edges {
		for points.len > 0 && u32(points[0]) <= 32 { points.delete(0) }
		for points.len > 0 && u32(points.last()) <= 32 { points.delete_last() }
	}
	return points.filter(it != `\t` && it != `\n` && it != `\r`)
}

fn test_url_input_reuse_preserves_full_parse_and_override_control_policies() {
	assert parser_processed_input('\x00\x01\t A\nB \r\x1f ') == [`A`, `B`]
	assert parser_processed_override_input('\x00\x01\t A\nB \r\x1f ') == [rune(0), 1, ` `,
		`A`, `B`, ` `, 31, ` `]
	assert parser_processed_input('a\x00\x01\x1f b') == [`a`, 0, 1, 31, ` `, `b`]
	for raw in ['', ' ', '\x00\x01\x20', '\t\n\r', 'https://example.test/a',
		'\x1f https:\n//exa\tmple.test/界/😀?a=é\r#末 \x00'] {
		assert parser_processed_input(raw) == url_input_filter_reference(raw, true)
		assert parser_processed_override_input(raw) == url_input_filter_reference(raw, false)
	}
}

fn test_url_input_reuse_matches_every_byte_at_edges_and_interior() {
	for value in 0 .. 256 {
		raw := [u8(value), `a`, u8(value), `b`, u8(value)].bytestr()
		assert parser_processed_input(raw) == url_input_filter_reference(raw, true)
		assert parser_processed_override_input(raw) == url_input_filter_reference(raw, false)
	}
}

fn test_url_input_reuse_preserves_unicode_and_existing_invalid_utf8_decoding() {
	for value in 0 .. 0x10000 {
		if value >= 0xd800 && value <= 0xdfff { continue }
		raw := '\x01\t ' + rune(value).str() + '\n x \r\x02'
		assert parser_processed_input(raw) == url_input_filter_reference(raw, true)
		assert parser_processed_override_input(raw) == url_input_filter_reference(raw, false)
	}
	for bytes in [[u8(0xff)], [u8(0xc0), 0x80], [u8(0xe0), 0x80, 0xa0],
		[u8(0xed), 0xa0, 0x80], [u8(0xe2), 0x28, 0xa1], [u8(0xf0), 0x9f, 0x98],
		[u8(0xf0), 0x9f, 0x98, 0x80], [u8(0xf4), 0x8f, 0xbf, 0xbf]] {
		raw := '\x00\t ' + bytes.bytestr() + '\n末 \x01'
		assert parser_processed_input(raw) == url_input_filter_reference(raw, true)
		assert parser_processed_override_input(raw) == url_input_filter_reference(raw, false)
	}
}

fn test_url_input_reuse_returns_independent_owned_arrays_and_preserves_url_setters() {
	raw := '\x00\t https://example.test/a\nb?x=é#末 \x1f'
	mut first := parser_processed_input(raw)
	expected := first.clone()
	first[0] = `X`
	assert parser_processed_input(raw) == expected
	assert raw.starts_with('\x00\t https://')
	record := parse(raw) or { panic('parse') }
	assert record.serialize(false) == 'https://example.test/ab?x=%C3%A9#%E6%9C%AB'
	assert record.with_path(' a\t?b#c ').serialize(false) ==
		'https://example.test/%20a%3Fb%23c%20?x=%C3%A9#%E6%9C%AB'
	assert record.with_port(' 80').port == none
}
