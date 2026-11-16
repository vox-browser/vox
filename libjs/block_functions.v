// SPDX-License-Identifier: BSD-2-Clause
module libjs

// codegen.rs::emit_lexical_function_declaration_for_block. These mutable
// bindings belong to the entered block/case environment, never its enclosing
// var scope. Function objects are recreated whenever that environment is entered.
fn (mut generator BytecodeGenerator) initialize_lexical_functions(children []Statement) ! {
	for child in children {
		if child.kind.tag != .function_declaration { continue }
		name := child.kind.func_name or { return error('Missing block function name') }
		generator.emit(Instruction{op: .create_mutable_binding, identifier: generator.identifier(name.name)})
	}
	for child in children {
		if child.kind.tag != .function_declaration { continue }
		name := child.kind.func_name or { return error('Missing block function name') }
		function := generator.temporary()
		generator.emit(Instruction{op: .new_function, dst: function, identifier: child.kind.function_id.id})
		generator.emit(Instruction{op: .initialize_binding, identifier: generator.identifier(name.name), lhs: function})
		generator.initialized_functions << child.kind.function_id.id
	}
}
