module querywire

import json2

fn assert_envelope_matches_json(input string, envelope CompactEnvelope) {
	expected := json2.decode[map[string]json2.Any](input) or { panic(err) }
	for name, actual in {'key': envelope.key, 'action': envelope.action, 'selector': envelope.selector} {
		value := expected[name] or { panic('missing oracle field') }
		if value is string { assert actual == value } else { assert false }
	}
}

fn test_compact_envelope_matches_general_json_for_printable_ascii() {
	for character in 0x20 .. 0x7f {
		if character == int(`"`) || character == int(`\\`) { continue }
		value := u8(character).ascii_str() + ' :{}[],/\''
		for input in ['{"key":"${value}","action":"querySelectorAll","selector":"main > a"}',
			'{"key":"__element_12","action":"${value}","selector":"[href=\'value\']"}',
			'{"key":"","action":"","selector":"${value}"}'] {
			envelope := parse_compact_envelope(input) or { panic('canonical envelope rejected') }
			assert_envelope_matches_json(input, envelope)
		}
	}
}

fn test_compact_envelope_returns_owned_strings() {
	input := '{"key":"__element_12","action":"querySelector","selector":"main a"}'.clone()
	envelope := parse_compact_envelope(input) or { panic('canonical envelope rejected') }
	unsafe { C.memset(input.str, `x`, uint(input.len)) }
	gc_collect()
	assert envelope.key == '__element_12'
	assert envelope.action == 'querySelector'
	assert envelope.selector == 'main a'
}

fn test_compact_envelope_defers_other_valid_json_to_the_general_decoder() {
	for input in [
		'{"selector":"a","action":"querySelector","key":""}',
		' {"key":"","action":"","selector":""}',
		'{"key":"", "action":"","selector":""}',
		'{"key":"","action":"","selector":""} ',
		r'{"key":"","action":"","selector":"[title=\"a\"]"}',
		r'{"key":"","action":"","selector":"\u0061"}',
		'{"key":"","action":"","selector":"Привет 🌍"}',
		'{"key":"","action":"","selector":"","snapshot":"{}","logCount":0}',
		'{"key":"old","action":"","selector":"","key":"new"}',
		'{"key":42,"action":null,"selector":false}',
		'{"key":"","action":"","selector":[]}', '{}', 'null', '[]',
	] {
		_ = json2.decode[json2.Any](input) or { panic(err) }
		assert parse_compact_envelope(input) == none
	}
}

fn test_compact_envelope_never_accepts_partial_or_malformed_json() {
	input := '{"key":"__element_1","action":"matches","selector":".a"}'
	for end in 0 .. input.len {
		assert parse_compact_envelope(input[..end]) == none
	}
	for index in 0 .. input.len {
		for byte in [u8(0), u8(10), u8(13), u8(255), `"`, `\\`, `{`, `}`, `:`, `,`] {
			mut changed := input.bytes()
			changed[index] = byte
			candidate := changed.bytestr()
			if envelope := parse_compact_envelope(candidate) {
				assert_envelope_matches_json(candidate, envelope)
			}
		}
	}
}
