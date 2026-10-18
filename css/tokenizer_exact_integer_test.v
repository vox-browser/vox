module css

import math
import strconv

fn check_exact_integer_consumer(spelling string, suffix string, prefix string) {
	mut tokenizer := Tokenizer.new(prefix + spelling + suffix)
	defer { tokenizer.input_arena.release() }
	for _ in prefix.runes_iterator() { _ = tokenizer.next_code_point() }
	actual := tokenizer.consume_a_number()
	expected := strconv.atof64(spelling) or { 0.0 }
	assert math.f64_bits(actual.value()) == math.f64_bits(expected), spelling
	expected_type := if spelling.contains('.') || spelling.contains('e') || spelling.contains('E') {
		NumberType.number
	} else if spelling.starts_with('+') || spelling.starts_with('-') {
		NumberType.integer_with_explicit_sign
	} else { NumberType.integer }
	assert actual.type_() == expected_type, spelling
	assert tokenizer.current_byte_offset() == prefix.len + spelling.len
	assert tokenizer.position.column == usize(spelling.len)
}

fn test_exact_integer_consumer_preserves_signed_zero_and_binary64_boundary() {
	for digits in ['0', '1', '42', '0007', '9007199254740990', '9007199254740991',
		'9007199254740992', '9007199254740993', '9007199254740994',
		'18446744073709551615', '18446744073709551616'] {
		for sign in ['', '+', '-'] {
			for suffix in ['', 'px', '%', 'β😀'] {
				check_exact_integer_consumer(sign + digits, suffix, 'β😀\n')
			}
		}
	}
	mut tokenizer := Tokenizer.new('-0')
	defer { tokenizer.input_arena.release() }
	assert math.signbit(tokenizer.consume_a_number().value())
}

fn test_exact_integer_consumer_matches_converter_for_generated_integers() {
	mut state := u64(30)
	for _ in 0 .. 8192 {
		state = state * u64(6364136223846793005) + u64(1442695040888963407)
		digits := '${state % u64(9007199254740993)}'
		for sign in ['', '+', '-'] {
			check_exact_integer_consumer(sign + digits, ';', 'β😀\n')
		}
	}
}

fn test_exact_integer_consumer_keeps_fraction_exponent_and_long_integer_fallbacks() {
	for spelling in ['.5', '-.5', '+.5', '1.0000000000000001', '1e0', '-0e0',
		'+12.5E-2', '5e-324', '-5e-324', '1e309', '-1E+9999', '1e-9999',
		'9'.repeat(1024), '0'.repeat(1024) + '7', '-0'.repeat(1) + '0'.repeat(1024),
		'9007199254740993' + '0'.repeat(1024), '-0.' + '0'.repeat(1024) + '1e-9999'] {
		check_exact_integer_consumer(spelling, 'px', 'β😀\n')
	}
}

fn test_exact_integer_public_tokens_retain_source_and_values_across_collection() {
	spellings := ['0', '-0', '+0', '9007199254740992', '9007199254740993',
		'9'.repeat(100), '1.25e2', '-5e-324']
	tokens := Tokenizer.tokenize('β\n' + spellings.join(' ') + ' 17px -0%', 'utf-8')
	numeric := tokens.filter(it.type_ in [TokenType.number, .percentage, .dimension])
	assert numeric.len == spellings.len + 2
	for _ in 0 .. 3 {
		gc_collect()
		for i, spelling in spellings {
			expected := strconv.atof64(spelling) or { 0.0 }
			assert math.f64_bits(numeric[i].number_value_.value()) == math.f64_bits(expected)
			assert numeric[i].original_source_text() == spelling
		}
		assert numeric[spellings.len].dimension_unit() == 'px'
		assert numeric[spellings.len].number_value_.value() == 17
		assert numeric[spellings.len + 1].type_ == .percentage
		assert math.signbit(numeric[spellings.len + 1].number_value_.value())
	}
}
