// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn (mut generator BytecodeGenerator) copy_annex_b_function(declaration &Statement) ! {
	name := declaration.kind.func_name or { return error('Missing Annex B function name') }
	value := generator.temporary()
	identifier := generator.identifier(name.name)
	generator.emit(Instruction{op: .get_binding, dst: value, identifier: identifier})
	generator.emit(Instruction{op: .set_variable, lhs: value, identifier: identifier, annex_b: true})
}

// codegen.rs::emit_lexical_function_declaration_for_block. These mutable
// bindings belong to the entered block/case environment, never its enclosing
// var scope. Function objects are recreated whenever that environment is entered.
fn (mut generator BytecodeGenerator) initialize_lexical_functions(children []Statement) ! {
	mut names := []Utf16String{}
	child_items := children
	for child_index in 0 .. child_items.len {
		child := unsafe { &child_items[child_index] }
		declaration := child.function_declaration_for_labelled_item() or { continue }
		name := declaration.kind.func_name or { return error('Missing block function name') }
		if names.any(it == name.name) { continue }
		names << name.name
		generator.emit(Instruction{op: .create_mutable_binding, identifier: generator.identifier(name.name)})
	}
	mut initialized := []Utf16String{}
	for index := children.len - 1; index >= 0; index-- {
		declaration := children[index].function_declaration_for_labelled_item() or { continue }
		generator.initialized_functions.set(u64(declaration.kind.function_id.id), 0)
		name := declaration.kind.func_name or { return error('Missing block function name') }
		if initialized.any(it == name.name) { continue }
		initialized << name.name
		function := generator.temporary()
		generator.emit(Instruction{op: .new_function, dst: function, identifier: declaration.kind.function_id.id})
		generator.emit(Instruction{op: .initialize_binding, identifier: generator.identifier(name.name), lhs: function})
	}
}
