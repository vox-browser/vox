// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct ConditionalTail {
	start Position
	test Expression
	consequent Expression
}

// expressions.rs parses right-associative conditional alternatives recursively.
// Minified resource maps use hundreds of alternatives without syntactic grouping.
// Keep those alternatives on an explicit work list, retaining the normal guarded
// parser for consequents, grouping and assignment right-hand sides.
fn (mut parser Parser) parse_conditional_tail(lhs Expression, forbidden ForbiddenTokens) Expression {
	mut tails := []ConditionalTail{}
	mut test := lhs
	mut alternate := Expression{}
	for {
		start := parser.position()
		parser.consume_token(.question_mark)
		consequent := parser.parse_assignment_expression()
		parser.consume_token(.colon)
		tails << ConditionalTail{start, test, consequent}
		if parser.done() {
			alternate = parser.expression(parser.position(), ExpressionKind.error())
			break
		}
		// The ordinary parser retains parenthesized assignment-target metadata.
		// Do not split that expression across two precedence-climbing calls.
		if parser.match_token(.paren_open) {
			alternate = parser.parse_expression(precedence_assignment, .right, forbidden)
			break
		}
		alternate_start := parser.position()
		alternate = parser.parse_expression(operator_precedence(.question_mark) + 1, .right, forbidden)
		if parser.match_token(.question_mark) && !parser.done() {
			test = alternate
			continue
		}
		alternate = parser.continue_parse_expression(alternate_start, alternate,
			precedence_assignment, .right, forbidden)
		break
	}
	for index := tails.len - 1; index >= 0; index-- {
		tail := tails[index]
		alternate = parser.expression(tail.start, ExpressionKind{
			tag: .conditional
			test: &Expression{...tail.test}
			consequent: &Expression{...tail.consequent}
			alternate_expr: &Expression{...alternate}
		})
	}
	return alternate
}

// Emit the same branches as codegen.rs without recursively walking a long
// alternate spine. The result register is shared by the mutually exclusive arms.
fn (mut generator BytecodeGenerator) conditional_tail(mut vm VM, expression &Expression) !Operand {
	previous_range := generator.range
	defer { generator.range = previous_range }
	dst := generator.temporary()
	mut current := expression
	mut ends := []u32{}
	for current.kind.tag == .conditional {
		generator.range = current.range
		test := generator.expression(mut vm, current.kind.test or { return error('Missing conditional test') })!
		otherwise := generator.emit(Instruction{op: .jump_if_false, lhs: test})
		value := generator.expression(mut vm, current.kind.consequent or { return error('Missing consequent') })!
		generator.emit(Instruction{op: .mov, dst: dst, lhs: value})
		ends << generator.emit(Instruction{op: .jump})
		generator.patch(otherwise)
		current = current.kind.alternate_expr or { return error('Missing alternate') }
	}
	value := generator.expression(mut vm, current)!
	generator.emit(Instruction{op: .mov, dst: dst, lhs: value})
	for end in ends { generator.patch(end) }
	return dst
}
