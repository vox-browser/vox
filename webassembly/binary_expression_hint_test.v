// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

fn test_source_expression_hint_distinguishes_unvalidated_from_validated_zero() {
	mut decoder := Decoder{ bytes: [u8(0x0b)] }
	mut expression := parse_binary_expression(mut decoder)!
	assert expression.stack_usage_hint == none
	mut validator := &BinaryInstructionValidator{}
	result := validator.validate_expression(mut expression, [])!
	assert result.is_constant && result.result_types.len == 0
	assert expression.stack_usage_hint? == uint(0)
}

fn test_source_expression_capacity_hint_does_not_publish_a_stack_requirement() {
	for capacity in [uint(0), 32] {
		mut decoder := Decoder{ bytes: [u8(0x41), 7, 0x0b] }
		expression := parse_binary_expression_with_hint(mut decoder, capacity)!
		assert expression.instructions.len == 2
		assert expression.stack_usage_hint == none
	}
	mut empty := BinaryExpression{}
	assert empty.stack_usage_hint == none
	empty.set_stack_usage_hint(uint(0))
	assert empty.stack_usage_hint? == uint(0)
	large := uint(u64(1) << 40)
	empty.set_stack_usage_hint(large)
	assert empty.stack_usage_hint? == large
}

fn test_source_failed_expression_validation_leaves_optional_stack_hint_untouched() {
	for previous in [?uint(none), ?uint(uint(131))] {
		mut decoder := Decoder{ bytes: [u8(0x0b)] }
		mut expression := parse_binary_expression(mut decoder)!
		expression.stack_usage_hint = previous
		mut validator := &BinaryInstructionValidator{}
		if _ := validator.validate_expression(mut expression, [BinaryValueType{ kind: .i64 }]) {
			assert false
		} else {
			assert err.msg().contains('expected <any> but got <nothing>')
		}
		assert expression.stack_usage_hint == previous
	}
}
