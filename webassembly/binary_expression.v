// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

pub struct BinaryExpression {
pub mut:
	instructions          []BinaryInstruction
	stack_usage_hint      ?uint
	compiled_instructions BinaryCompiledInstructions
}

// Types.h::Expression::set_stack_usage_hint. A parsed expression has no known
// requirement; successful validation can publish an explicitly known zero.
pub fn (mut expression BinaryExpression) set_stack_usage_hint(value uint) {
	expression.stack_usage_hint = value
}

// Parser/Parser.cpp::Expression::parse. Structured operands retain actual
// instruction pointers; the outer end is replaced by the source synthetic
// expression-end instruction. Type/control validation is a later source pass.
fn parse_binary_expression(mut decoder Decoder) !BinaryExpression {
	return parse_binary_expression_with_hint(mut decoder, none)
}

fn parse_binary_expression_with_hint(mut decoder Decoder, size_hint ?uint) !BinaryExpression {
	mut stack := []int{}
	capacity := size_hint or { uint(0) }
	mut instructions := []BinaryInstruction{cap: int(capacity)}
	for {
		instruction := parse_binary_instruction(mut decoder)!
		ip := u32(instructions.len)
		match instruction.opcode {
			binary_op_block, binary_op_loop, binary_op_if_, binary_op_try_table {
				stack << instructions.len
			}
			binary_op_structured_end {
				if stack.len == 0 {
					instructions << BinaryInstruction{ opcode: binary_op_synthetic_end_expression }
					return BinaryExpression{ instructions: instructions }
				}
				entry := stack.pop()
				arguments := instructions[entry].arguments
				match arguments {
					BinaryStructuredArguments {
						mut patched := arguments
						patched.end_ip = ip + if arguments.else_ip != none {
							u32(1)
						} else {
							u32(0)
						}
						instructions[entry].arguments = patched
					}
					BinaryTryTableArguments {
						mut patched := arguments
						patched.end_ip = ip
						instructions[entry].arguments = patched
					}
					else { return error('CompileError: invalid structured instruction type') }
				}
			}
			binary_op_structured_else {
				if stack.len == 0 { return error('CompileError: unexpected else instruction') }
				entry := stack.last()
				arguments := instructions[entry].arguments
				if arguments is BinaryStructuredArguments {
					mut patched := arguments
					patched.else_ip = ip + 1
					instructions[entry].arguments = patched
				} else {
					return error('CompileError: invalid else instruction type')
				}
			}
			else {}
		}
		instructions << instruction
	}
	return error('CompileError: expression is missing its end instruction')
}
