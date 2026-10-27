module css

import math
import strings

// Retain the former builder algorithm as a compatibility oracle, including
// exact consumption state and binary64 results. Explicit cases below also
// establish expected values, flags and public token boundaries independently.
fn (mut tokenizer Tokenizer) consume_number_builder_oracle() Number {
	// This section describes how to consume a number from a stream of code points.
	// It returns a numeric value, and a type which is either "integer" or "number".
	//
	// Note: This algorithm does not do the verification of the first few code points
	// that are necessary to ensure a number can be obtained from the stream. Ensure
	// that the stream starts with a number before calling this algorithm.

	// Execute the following steps in order:

	// 1. Initially set type to "integer". Let repr be the empty string.
	mut repr := strings.new_builder(16)
	mut type_ := NumberType.integer

	// 2. If the next input code point is U+002B PLUS SIGN (+) or U+002D HYPHEN-MINUS (-),
	// consume it and append it to repr.
	mut has_explicit_sign := false
	next_input := tokenizer.peek_code_point(0)
	if is_plus_sign(next_input) || is_hyphen_minus(next_input) {
		has_explicit_sign = true
		append_code_point(mut repr, tokenizer.next_code_point())
	}

	// 3. While the next input code point is a digit, consume it and append it to repr.
	for {
		digits := tokenizer.peek_code_point(0)
		if !is_digit(digits) {
			break
		}

		append_code_point(mut repr, tokenizer.next_code_point())
	}

	// 4. If the next 2 input code points are U+002E FULL STOP (.) followed by a digit, then:
	maybe_number := tokenizer.peek_twin()
	if is_full_stop(maybe_number.first) && is_digit(maybe_number.second) {
		// 1. Consume them.
		// 2. Append them to repr.
		append_code_point(mut repr, tokenizer.next_code_point())
		append_code_point(mut repr, tokenizer.next_code_point())

		// 3. Set type to "number".
		type_ = .number

		// 4. While the next input code point is a digit, consume it and append it to repr.
		for {
			digit := tokenizer.peek_code_point(0)
			if !is_digit(digit) {
				break
			}

			append_code_point(mut repr, tokenizer.next_code_point())
		}
	}

	// 5. If the next 2 or 3 input code points are U+0045 LATIN CAPITAL LETTER E (E) or
	// U+0065 LATIN SMALL LETTER E (e), optionally followed by U+002D HYPHEN-MINUS (-)
	// or U+002B PLUS SIGN (+), followed by a digit, then:
	maybe_exp := tokenizer.peek_triplet()
	if (is_upper_e(maybe_exp.first) || is_e(maybe_exp.first))
		&& (((is_plus_sign(maybe_exp.second) || is_hyphen_minus(maybe_exp.second))
		&& is_digit(maybe_exp.third)) || is_digit(maybe_exp.second)) {
		// 1. Consume them.
		// 2. Append them to repr.
		if is_plus_sign(maybe_exp.second) || is_hyphen_minus(maybe_exp.second) {
			if is_digit(maybe_exp.third) {
				append_code_point(mut repr, tokenizer.next_code_point())
				append_code_point(mut repr, tokenizer.next_code_point())
				append_code_point(mut repr, tokenizer.next_code_point())
			}
		} else if is_digit(maybe_exp.second) {
			append_code_point(mut repr, tokenizer.next_code_point())
			append_code_point(mut repr, tokenizer.next_code_point())
		}

		// 3. Set type to "number".
		type_ = .number

		// 4. While the next input code point is a digit, consume it and append it to repr.
		for {
			digits := tokenizer.peek_code_point(0)
			if !is_digit(digits) {
				break
			}

			append_code_point(mut repr, tokenizer.next_code_point())
		}
	}

	// 6. Convert repr to a number, and set the value to the returned value.
	value := tokenizer.convert_a_string_to_a_number(repr.str())

	// 7. Return value and type.
	if type_ == .integer && has_explicit_sign {
		return Number.with_type(.integer_with_explicit_sign, value)
	}
	return Number.with_type(type_, value)
}

fn compare_number_span_with_builder(source string, prefix string) {
	mut actual := Tokenizer.new(prefix + source)
	defer { actual.input_arena.release() }
	mut expected := Tokenizer.new(prefix + source)
	defer { expected.input_arena.release() }
	for _ in prefix.runes_iterator() {
		assert actual.next_code_point() == expected.next_code_point()
	}
	a := actual.consume_a_number()
	b := expected.consume_number_builder_oracle()
	assert math.f64_bits(a.value()) == math.f64_bits(b.value())
	assert a.type_() == b.type_()
	assert actual.index == expected.index
	assert actual.prev_index == expected.prev_index
	assert actual.position == expected.position
	assert actual.prev_position == expected.prev_position
	assert actual.peek_code_point(0) == expected.peek_code_point(0)
	assert actual.current_byte_offset() == expected.current_byte_offset()
}

fn test_number_span_preserves_values_sign_flags_and_decimal_exponents() {
	spellings := ['0', '+0', '-0', '12', '-12', '+12', '.5', '-.5', '+.5',
		'12.5', '+12.5e2', '-12.5E-2', '0001', '1E+3']
	values := [f64(0), 0, -0.0, 12, -12, 12, 0.5, -0.5, 0.5, 12.5, 1250, -0.125, 1, 1000]
	flags := [NumberType.integer, .integer_with_explicit_sign, .integer_with_explicit_sign,
		.integer, .integer_with_explicit_sign, .integer_with_explicit_sign,
		.number, .number, .number, .number, .number, .number, .integer, .number]
	for i, spelling in spellings {
		mut tokenizer := Tokenizer.new(spelling)
		defer { tokenizer.input_arena.release() }
		number := tokenizer.consume_a_number()
		assert number.value() == values[i]
		assert number.type_() == flags[i]
		assert tokenizer.peek_code_point(0) == tokenizer_eof
		assert tokenizer.position.column == uint(spelling.len)
		compare_number_span_with_builder(spelling, '')
	}
	mut negative_zero := Tokenizer.new('-0')
	defer { negative_zero.input_arena.release() }
	assert math.signbit(negative_zero.consume_a_number().value())
}

fn test_number_span_matches_builder_across_boundaries_and_unicode_offsets() {
	for sign in ['', '+', '-'] {
		for whole in ['0', '12', '0007'] {
			for fraction in ['', '.5', '.0000000000000001'] {
				for exponent in ['', 'e0', 'E+2', 'e-3', 'e+', 'E-', 'e', '.2'] {
					for suffix in ['', 'px', '%', 'β', '😀', '\n'] {
						for prefix in ['', 'β😀\n'] {
							compare_number_span_with_builder(sign + whole + fraction + exponent + suffix, prefix)
						}
					}
				}
			}
		}
	}
	for spelling in ['5e-324', '-5e-324', '1e309', '-1E+9999', '1e-9999',
		'9'.repeat(1024), '-0.' + '0'.repeat(1024) + '1e-9999'] {
		compare_number_span_with_builder(spelling, 'β😀\n')
	}
}

fn test_number_span_keeps_public_numeric_token_boundaries_and_source_owners() {
	tokens := Tokenizer.tokenize('/* discarded */'.repeat(1024) + 'β\n-0 12% +2.5e2px 1e+ β .25em', 'utf-8')
	numeric := tokens.filter(it.type_ in [TokenType.number, .percentage, .dimension])
	assert numeric.len == 5
	assert numeric.map(it.type_) == [TokenType.number, .percentage, .dimension, .dimension, .dimension]
	assert numeric.map(it.original_source_text()) == ['-0', '12%', '+2.5e2px', '1e', '.25em']
	assert numeric[0].start_position().line == 1 && numeric[0].start_position().column == 0
	assert numeric[0].end_position().line == 1 && numeric[0].end_position().column == 2
	assert numeric[2].dimension_unit() == 'px'
	assert numeric[3].dimension_unit() == 'e'
	assert numeric[4].dimension_unit() == 'em'
	assert tokens.filter(it.type_ == .delim && it.value == '+').len == 1
	for _ in 0 .. 3 {
		gc_collect()
		assert math.signbit(numeric[0].number_value_.value())
		for i, value in [f64(0), 12, 250, 1, 0.25] {
			assert numeric[i].number_value_.value() == value
			text := numeric[i].original_source_text()
			assert unsafe { text.str[text.len] } == 0
		}
	}
}

fn test_number_span_preserves_private_consumer_empty_and_sign_only_behavior() {
	for source in ['', '+', '-', '.', 'β', 'e+3'] {
		compare_number_span_with_builder(source, '')
	}
}
