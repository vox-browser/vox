module css

import math
import strconv

#include <fenv.h>
fn C.fegetround() int
fn C.fesetround(int) int

fn check_exact_fraction_consumer(spelling string, suffix string) f64 {
	prefix := 'β😀\n'
	mut tokenizer := Tokenizer.new(prefix + spelling + suffix)
	defer { tokenizer.input_arena.release() }
	for _ in prefix.runes_iterator() { _ = tokenizer.next_code_point() }
	actual := tokenizer.consume_a_number()
	expected := strconv.atof64(spelling) or { 0.0 }
	assert math.f64_bits(actual.value()) == math.f64_bits(expected), spelling
	assert actual.type_() == .number
	assert tokenizer.current_byte_offset() == prefix.len + spelling.len
	assert tokenizer.position.column == uint(spelling.len)
	return actual.value()
}

fn test_exact_fraction_consumer_keeps_dyadic_values_and_range_boundaries() {
	spellings := ['.5', '+.5', '-.5', '0.25', '0.75', '1.125', '-17.0625',
		'450359962737049.5', '0.0000002384185791015625',
		'-0.0000002384185791015625', '0001.25000', '-0.000']
	values := [f64(0.5), 0.5, -0.5, 0.25, 0.75, 1.125, -17.0625,
		450359962737049.5, f64(1) / 4194304, -f64(1) / 4194304, 1.25, -0.0]
	for i, spelling in spellings {
		assert math.f64_bits(check_exact_fraction_consumer(spelling, 'px')) == math.f64_bits(values[i])
	}
	for spelling in ['0.1', '-0.3', '1.23456789', '4503599627370495.5',
		'4503599627370496.5', '9007199254740992.0', '0.00000011920928955078125',
		'0.' + '0'.repeat(1024) + '1', '1.25e2', '-0.00E-9999'] {
		_ = check_exact_fraction_consumer(spelling, '%')
	}
	assert check_exact_fraction_consumer('1.25', 'e+') == 1.25
}

fn test_exact_fraction_consumer_matches_generated_binary_rationals() {
	mut fives := u64(1)
	for bits in 1 .. 11 {
		fives *= 5
		denominator := u64(1) << bits
		for numerator in 0 .. 256 {
			whole := u64(numerator) / denominator
			digits := '${(u64(numerator) % denominator) * fives}'
			spelling := '${whole}.' + '0'.repeat(bits - digits.len) + digits
			expected := f64(numerator) / f64(denominator)
			assert check_exact_fraction_consumer(spelling, ';') == expected
			assert check_exact_fraction_consumer('+' + spelling, ';') == expected
			assert math.f64_bits(check_exact_fraction_consumer('-' + spelling, ';')) == math.f64_bits(-expected)
		}
	}
}

fn test_exact_fraction_consumer_preserves_converter_results_in_all_rounding_modes() {
	saved := C.fegetround()
	defer { _ = C.fesetround(saved) }
	for mode in [int(C.FE_TONEAREST), int(C.FE_DOWNWARD), int(C.FE_UPWARD), int(C.FE_TOWARDZERO)] {
		assert C.fesetround(mode) == 0
		for spelling in ['0.5', '-0.5', '1.25', '-1.125', '-0.000',
			'0.0000002384185791015625', '0.1', '-0.3', '1.25e0',
			'9007199254740992.0', '0.00000011920928955078125'] {
			_ = check_exact_fraction_consumer(spelling, 'rem')
		}
	}
}

fn test_exact_fraction_public_tokens_keep_flags_source_and_owners() {
	spellings := ['.5px', '-0.00%', '+1.25', '0.1', '-2.5e1']
	tokens := Tokenizer.tokenize('β\n' + spellings.join(' '), 'utf-8')
	numeric := tokens.filter(it.type_ in [TokenType.number, .percentage, .dimension])
	assert numeric.len == spellings.len
	assert numeric.map(it.type_) == [TokenType.dimension, .percentage, .number, .number, .number]
	assert numeric[0].dimension_unit() == 'px'
	values := [f64(0.5), -0.0, 1.25, 0.1, -25]
	for _ in 0 .. 3 {
		gc_collect()
		for i, spelling in spellings {
			assert numeric[i].original_source_text() == spelling
			assert numeric[i].number_value_.type_() == .number
			assert math.f64_bits(numeric[i].number_value_.value()) == math.f64_bits(values[i])
		}
	}
}
