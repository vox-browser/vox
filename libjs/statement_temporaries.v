module libjs

$if test {
	__global statement_temporary_reuse_disabled bool
	pub fn set_statement_temporary_reuse_for_testing(enabled bool) {
		statement_temporary_reuse_disabled = !enabled
	}
}

// Only complete script/function body statements have this boundary. Locals,
// reserved completion registers and declaration/parameter setup stay below
// base. Nested blocks, loop bodies, finally bodies and expression evaluation
// keep their ordinary allocation, including temporaries held across a nested
// statement or a suspension. No instruction/PC/source-map entry is removed.
fn (mut generator BytecodeGenerator) body_statements(mut vm VM, statements []Statement) ! {
	$if test {
		if statement_temporary_reuse_disabled {
			for statement in statements { generator.statement(mut vm, &statement)! }
			return
		}
	}
	base := generator.executable.registers_and_locals_count
	mut maximum := base
	for statement in statements {
		generator.executable.registers_and_locals_count = base
		generator.statement(mut vm, &statement)!
		if generator.executable.registers_and_locals_count > maximum {
			maximum = generator.executable.registers_and_locals_count
		}
	}
	generator.executable.registers_and_locals_count = maximum
}
