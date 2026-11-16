// SPDX-License-Identifier: BSD-2-Clause
module libjs

// codegen.rs::generate_switch_statement. Selection tests precede every case
// body; a matching case falls through without evaluating later tests. Default
// is entered only after every selection test has failed.
fn (mut generator BytecodeGenerator) switch_statement(mut vm VM, statement &Statement) ! {
	data := statement.kind.switch_data or { return error('Missing switch statement') }
	generator.clear_completion()
	discriminant := generator.expression(mut vm, &data.discriminant)!
	mut children := []Statement{}
	for clause in data.cases { children << clause.scope.children }
	if !generator.strict && children.any(it.kind.tag == .function_declaration) {
		return generator.unsupported('Annex B switch function declarations')
	}
	generator.emit(Instruction{op: .enter_scope})
	generator.scope_depth++
	generator.lexical_declarations(children, false)!
	// Strict case-block functions are lexical declarations, initialized before
	// case expressions run. They do not create a surrounding var binding.
	generator.initialize_lexical_functions(children)!
	mut tests := []u32{len: data.cases.len, init: u32(0xffffffff)}
	mut default_case := -1
	for index, clause in data.cases {
		if test := clause.test {
			candidate := generator.expression(mut vm, &test)!
			equal := generator.temporary()
			generator.emit(Instruction{op: .strict_equals, dst: equal, lhs: discriminant, rhs: candidate})
			tests[index] = generator.emit(Instruction{op: .jump_if_true, lhs: equal})
		} else { default_case = index }
	}
	no_match := generator.emit(Instruction{op: .jump})
	generator.loops << BytecodeLoop{scope_depth: generator.scope_depth, is_iteration: false}
	for index, clause in data.cases {
		if tests[index] != 0xffffffff { generator.patch(tests[index]) }
		if index == default_case { generator.patch(no_match) }
		for child in clause.scope.children { generator.statement(mut vm, &child)! }
	}
	context := generator.loops.pop()
	if default_case < 0 { generator.patch(no_match) }
	for jump in context.breaks { generator.patch(jump) }
	generator.scope_depth--
	generator.emit(Instruction{op: .leave_scope})
}
