// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Call/New and optional calls share ArgumentListEvaluation. The callee and
// Reference receiver have already been retained before arguments are evaluated.
// Spread reuses ordered iterator bytecode, preserving the original abrupt
// completion and the native tier's shared execution budget.
fn (mut generator BytecodeGenerator) emit_call_arguments(mut vm VM, destination Operand, callee Operand, receiver Operand, arguments []CallArgument, construct bool) ! {
	if arguments.any(it.is_spread) {
		array := generator.arguments_array(mut vm, arguments)!
		generator.emit(Instruction{op: if construct { OpCode.construct_with_array } else { OpCode.call_with_array }, dst: destination, lhs: callee, rhs: receiver, src: array})
		return
	}
	mut operands := []Operand{cap: arguments.len}
	// codegen.rs copies local arguments so later arguments cannot change them.
	for index, argument in arguments {
		operands << if arguments_might_contain_assignment(arguments, index + 1) {
			generator.expression(mut vm, &argument.value)!
		} else {
			generator.immediate_value(mut vm, &argument.value)!
		}
	}
	generator.emit(Instruction{op: if construct { OpCode.construct } else { OpCode.call }, dst: destination, lhs: callee, rhs: receiver, arguments: operands})
}
