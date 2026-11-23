module libjs

import os

// Same-binary control: copy every local read and statement completion again.
const copy_local_reads = os.getenv('VOX_LIBJS_COPY_LOCAL_READS') != ''

// codegen.rs returns an uncaptured local's operand instead of copying it into a
// register. A register binding is never captured by a closure, eval or with, so
// only assignments and updates evaluated by this function's own bytecode can
// change it. Each caller below consumes the operand before evaluating anything
// that might_contain_assignment() admits, preserving left-to-right reads.

// codegen.rs::might_contain_assignment_expression, extended to calls: a callee
// runs other functions' code, which cannot reach this frame's register bindings.
fn might_contain_assignment(expression &Expression) bool {
	kind := expression.kind
	return match kind.tag {
		.numeric_literal, .string_literal, .boolean_literal, .null_literal, .identifier_expr,
		.this_expr, .function_expr {
			false
		}
		.unary {
			operand := kind.operand or { return true }
			might_contain_assignment(operand)
		}
		.binary, .logical {
			lhs := kind.lhs or { return true }
			rhs := kind.rhs or { return true }
			might_contain_assignment(lhs) || might_contain_assignment(rhs)
		}
		.member {
			object := kind.object or { return true }
			if object.kind.tag == .super_expr { return true }
			if might_contain_assignment(object) { return true }
			if !kind.computed { return false }
			property := kind.property or { return true }
			might_contain_assignment(property)
		}
		.call, .new_expr {
			data := kind.call_data or { return true }
			if data.callee.kind.tag == .super_expr || might_contain_assignment(&data.callee) {
				return true
			}
			arguments_might_contain_assignment(data.arguments, 0)
		}
		else {
			true
		}
	}
}

fn arguments_might_contain_assignment(arguments []CallArgument, start int) bool {
	for index in start .. arguments.len {
		if arguments[index].is_spread || might_contain_assignment(&arguments[index].value) {
			return true
		}
	}
	return false
}

// A function body's statement completions are unobservable.
fn (generator &BytecodeGenerator) drops_completions() bool {
	return generator.function_body && !copy_local_reads
}

// A local read in place by the next instruction.
fn (mut generator BytecodeGenerator) in_place_register(expression &Expression) ?Operand {
	if copy_local_reads { return none }
	return generator.expression_register(expression)
}

// The value of an expression whose operand the next instruction consumes.
fn (mut generator BytecodeGenerator) immediate_value(mut vm VM, expression &Expression) !Operand {
	if local := generator.in_place_register(expression) { return local }
	return generator.expression(mut vm, expression)
}

// An operand read before `later` is evaluated, then consumed afterwards.
fn (mut generator BytecodeGenerator) value_before(mut vm VM, expression &Expression, later &Expression) !Operand {
	if !might_contain_assignment(later) {
		return generator.immediate_value(mut vm, expression)
	}
	return generator.expression(mut vm, expression)
}

// A temporary register written by the expression that produced it. Nothing
// else writes it before the enclosing expression consumes it.
fn (generator &BytecodeGenerator) is_expression_temporary(operand Operand) bool {
	if copy_local_reads { return false }
	kind := operand.operand_type() or { return false }
	return kind == .register && operand.index() >= reserved_register_count
}
