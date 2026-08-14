// Copyright (c) 2023, Jonatan Klemets <jonatan.r.klemets@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Tests/LibWeb/TestNumbers.cpp.
module html

fn test_parse_integer() {
	assert parse_integer('') == none
	assert parse_integer('123')? == 123
	assert parse_integer(' 456')? == 456
	assert parse_integer('789 ')? == 789
	assert parse_integer('   22   ')? == 22
	assert parse_integer(' \n\t31\t\t\n\n')? == 31
	assert parse_integer('765foo')? == 765
	assert parse_integer('3;')? == 3
	assert parse_integer('foo765') == none
	assert parse_integer('1')? == 1
	assert parse_integer('+2')? == 2
	assert parse_integer('-3')? == -3
}

fn test_parse_non_negative_integer() {
	assert parse_non_negative_integer('') == none
	assert parse_non_negative_integer('123')? == 123
	assert parse_non_negative_integer(' 456')? == 456
	assert parse_non_negative_integer('789 ')? == 789
	assert parse_non_negative_integer('   22   ')? == 22
	assert parse_non_negative_integer(' \n\t31\t\t\n\n')? == 31
	assert parse_non_negative_integer('765foo')? == 765
	assert parse_non_negative_integer('3;')? == 3
	assert parse_non_negative_integer('foo765') == none
	assert parse_non_negative_integer('1')? == 1
	assert parse_non_negative_integer('+2')? == 2
	assert parse_non_negative_integer('-3') == none
}

fn test_is_valid_floating_point_number() {
	assert is_valid_floating_point_number('11')
	assert is_valid_floating_point_number('11.12')
	assert is_valid_floating_point_number('-11111')
	assert is_valid_floating_point_number('-11111.123')
	assert is_valid_floating_point_number('1e2')
	assert is_valid_floating_point_number('1E2')
	assert is_valid_floating_point_number('1e+2')
	assert !is_valid_floating_point_number('1d+2')
	assert !is_valid_floating_point_number('foobar')
	assert is_valid_floating_point_number('.1')
	assert !is_valid_floating_point_number('1.')
	assert is_valid_floating_point_number('-0')
	assert !is_valid_floating_point_number('Infinity')
	assert !is_valid_floating_point_number('-Infinity')
	assert !is_valid_floating_point_number('NaN')
	assert is_valid_floating_point_number('9007199254740993')
	assert !is_valid_floating_point_number('1e')
	assert !is_valid_floating_point_number('+1')
	assert !is_valid_floating_point_number('+')
	assert !is_valid_floating_point_number('-')
	assert !is_valid_floating_point_number('\t1')
	assert !is_valid_floating_point_number('\n1')
	assert !is_valid_floating_point_number('\x0c1')
	assert !is_valid_floating_point_number('\r1')
	assert !is_valid_floating_point_number(' 1')
	assert !is_valid_floating_point_number('1trailing junk')
}

fn test_parse_floating_point_number() {
	assert parse_floating_point_number('') == none
	assert parse_floating_point_number('  -12.5e2junk')? == -1250.0
	assert parse_floating_point_number('.25')? == 0.25
	assert parse_floating_point_number('1.')? == 1.0
	assert parse_floating_point_number('1e')? == 1.0
	assert parse_floating_point_number('-0')? == 0.0
	assert parse_floating_point_number('1e309') == none
}

fn test_convert_non_negative_integer_to_string() {
	assert convert_non_negative_integer_to_string(42)! == '42'
	if _ := convert_non_negative_integer_to_string(-1) {
		assert false
	} else {
		assert err.msg() == 'The attribute is limited to only non-negative numbers'
	}
}
