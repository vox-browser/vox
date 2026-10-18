module css

import strconv
import strings

fn compare_escape_integer_with_builder(source string, prefix string) u32 {
 mut actual := Tokenizer.new(prefix + '\\' + source)
 defer { actual.input_arena.release() }
 mut expected := Tokenizer.new(prefix + '\\' + source)
 defer { expected.input_arena.release() }
 for _ in prefix.runes_iterator() { assert actual.next_code_point() == expected.next_code_point() }
 assert actual.next_code_point() == `\\`
 assert expected.next_code_point() == `\\`
 value := actual.consume_escaped_code_point()
 assert value == expected.consume_escaped_builder_oracle()
 assert actual.index == expected.index
 assert actual.prev_index == expected.prev_index
 assert actual.position == expected.position
 assert actual.prev_position == expected.prev_position
 assert actual.current_byte_offset() == expected.current_byte_offset()
 for _ in 0 .. 4 {
  assert actual.next_code_point() == expected.next_code_point()
  assert actual.position == expected.position
  assert actual.prev_position == expected.prev_position
 }
 return value
}

fn escape_integer_hex(value u32, width int, uppercase bool) string {
 alphabet := if uppercase { '0123456789ABCDEF' } else { '0123456789abcdef' }
 mut text := strings.new_builder(width)
 for index in 0 .. width {
  shift := u32((width - index - 1) * 4)
  text.write_u8(alphabet[int((value >> shift) & 15)])
 }
 return text.str()
}

fn test_escape_integer_all_short_hex_spellings_match_builder_and_scalar_values() {
 for value in 0 .. 4096 {
  for uppercase in [false, true] {
   text := escape_integer_hex(u32(value), 3, uppercase)
   expected := if value == 0 { replacement_character } else { u32(value) }
   assert compare_escape_integer_with_builder(text + ';', 'β😀\n') == expected
  }
 }
 for width in 1 .. 7 {
  for value in [u32(0), 1, 9, 10, 15] {
   assert compare_escape_integer_with_builder(escape_integer_hex(value, width, false), '') == if value == 0 { replacement_character } else { value }
  }
 }
}

fn test_escape_integer_six_digit_limit_and_unicode_repair_boundaries() {
 for value in [u32(0), 1, 0x7f, 0x80, 0xd7ff, 0xd800, 0xdbff, 0xdc00,
  0xdfff, 0xe000, 0xffff, 0x10000, 0x10ffff, 0x110000, 0xffffff] {
  expected := if value == 0 || (value >= 0xd800 && value <= 0xdfff) || value > 0x10ffff { replacement_character } else { value }
  for uppercase in [false, true] {
   for suffix in ['', 'a;', '0;', 'β😀;'] {
    assert compare_escape_integer_with_builder(escape_integer_hex(value, 6, uppercase) + suffix, 'x\n') == expected
   }
  }
 }
}

fn test_escape_integer_consumes_exactly_one_optional_css_whitespace() {
 for text in ['a', '000061', 'D800', '110000'] {
  for whitespace in [' ', '\t', '\n', '  ', '\t\n', '\n\n', '\r', '\x0c'] {
   for suffix in ['', ';tail', 'β😀tail'] {
    _ = compare_escape_integer_with_builder(text + whitespace + suffix, 'β😀\n')
   }
  }
 }
 for text in ['', 'g', 'Z', '\n', '\t', 'β', '😀', '\\', ';', '\x00'] {
  _ = compare_escape_integer_with_builder(text, 'β😀\n')
 }
}

fn test_escape_integer_public_tokens_retain_owned_values_after_collection() {
 tokens := Tokenizer.tokenize('foo\\62 ar "\\1F600 \\000061" \\D800  2p\\78 ', 'utf-8')
 identifiers := tokens.filter(it.is(.ident))
 string_tokens := tokens.filter(it.is(.string))
 dimensions := tokens.filter(it.is(.dimension))
 assert identifiers.map(it.ident()) == ['foobar', '�']
 assert string_tokens.len == 1
 assert string_tokens[0].string_value() == '😀a'
 assert dimensions.len == 1
 assert dimensions[0].dimension_unit() == 'px'
 for _ in 0 .. 3 {
  gc_collect()
  assert identifiers[0].ident() == 'foobar'
  assert string_tokens[0].string_value() == '😀a'
  assert dimensions[0].dimension_unit() == 'px'
  assert identifiers[0].original_source_text() == 'foo\\62 ar'
 }
}

// Unchanged original builder/parser implementation, used only as an oracle.
fn (mut tokenizer Tokenizer) consume_escaped_builder_oracle() u32 {
	// This section describes how to consume an escaped code point.
	// It assumes that the U+005C REVERSE SOLIDUS (\) has already been consumed and that the next
	// input code point has already been verified to be part of a valid escape.
	// It will return a code point.

	// Consume the next input code point.
	input := tokenizer.next_code_point()

	// hex digit
	if is_hex_digit(input) {
		// Consume as many hex digits as possible, but no more than 5.
		// Note that this means 1-6 hex digits have been consumed in total.
		mut builder := strings.new_builder(6)
		append_code_point(mut builder, input)

		mut counter := 0
		for is_hex_digit(tokenizer.peek_code_point(0)) && counter < 5 {
			counter++
			append_code_point(mut builder, tokenizer.next_code_point())
		}

		// If the next input code point is whitespace, consume it as well.
		if is_whitespace(tokenizer.peek_code_point(0)) {
			_ = tokenizer.next_code_point()
		}

		// Interpret the hex digits as a hexadecimal number.
		unhexed := u32(strconv.parse_uint(builder.str(), 16, 32) or { 0 })
		// If this number is zero, or is for a surrogate, or is greater than the maximum allowed
		// code point, return U+FFFD REPLACEMENT CHARACTER.
		if unhexed == 0 || is_unicode_surrogate(unhexed)
			|| is_greater_than_maximum_allowed_code_point(unhexed) {
			return replacement_character
		}

		// Otherwise, return the code point with that value.
		return unhexed
	}

	// EOF
	if is_eof(input) {
		// This is a parse error. Return U+FFFD REPLACEMENT CHARACTER.
		log_parse_error()
		return replacement_character
	}

	// anything else
	// Return the current input code point.
	return input
}
