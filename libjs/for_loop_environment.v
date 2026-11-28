module libjs

// CreatePerIterationEnvironment copies let bindings before the first test and
// before each update. Closures keep the preceding environment and its values.
fn (mut generator BytecodeGenerator) copy_for_iteration_bindings(names []Utf16String) {
	if names.len == 0 { return }
	mut values := []Operand{}
	for name in names {
		value := generator.temporary()
		generator.emit(Instruction{op: .get_binding, dst: value, identifier: generator.identifier(name)})
		values << value
	}
	generator.emit(Instruction{op: .leave_scope})
	generator.emit(Instruction{op: .enter_scope})
	for index, name in names {
		identifier := generator.identifier(name)
		generator.emit(Instruction{op: .create_mutable_binding, identifier: identifier})
		generator.emit(Instruction{op: .initialize_binding, identifier: identifier, lhs: values[index]})
	}
}
