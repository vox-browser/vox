// SPDX-License-Identifier: BSD-2-Clause
module libjs

@[heap]
struct ConditionalExpressionData {
	test       Expression
	consequent Expression
mut:
	alternate Expression
}

struct ConditionalTail {
	start Position
	branches &ConditionalExpressionData
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
		// The temporary list keeps only the location and the eventual owner.
		tails << ConditionalTail{start, &ConditionalExpressionData{test: test, consequent: consequent}}
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
		mut branches := tail.branches
		branches.alternate = alternate
		alternate = parser.expression(tail.start, ExpressionKind{
			tag:              .conditional
			conditional_data: branches
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
	// The input and its retained children outlive this local traversal.
	mut current := unsafe { expression }
	mut ends := []u32{}
	for current.kind.tag == .conditional {
		generator.range = current.range
		branches := current.kind.conditional_data or { return error('Missing conditional branches') }
		test := generator.immediate_value(mut vm, &branches.test)!
		otherwise := generator.emit(Instruction{op: .jump_if_false, lhs: test})
		value := generator.immediate_value(mut vm, &branches.consequent)!
		generator.emit(Instruction{op: .mov, dst: dst, lhs: value})
		ends << generator.emit(Instruction{op: .jump})
		generator.patch(otherwise)
		current = &branches.alternate
	}
	value := generator.immediate_value(mut vm, current)!
	generator.emit(Instruction{op: .mov, dst: dst, lhs: value})
	for end in ends { generator.patch(end) }
	return dst
}
