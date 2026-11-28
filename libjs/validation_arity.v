module libjs

$if test {
	__global validation_arity_disabled bool
	__global validation_arity_diagnostics bool
	__global validation_arity_hits u64
	pub fn set_validation_arity_for_testing(enabled bool) { validation_arity_disabled = !enabled }
	pub fn diagnose_validation_arity_for_testing(enabled bool) u64 {
		previous := validation_arity_hits
		validation_arity_hits = 0
		validation_arity_diagnostics = enabled
		return previous
	}
}

fn use_validation_arity() bool {
	$if test {
		if validation_arity_disabled { return false }
	}
	return true
}

fn validation_argument_requirement(operand Operand) u32 {
	return if operand.raw >> 29 == u32(OperandType.argument) { operand.index() + 1 } else { u32(0) }
}

// Only argument operands depend on the arity. Their offsets remain unchanged
// as arguments are added. The frame's u32 layout-overflow check stays live.
// Call this only after successful validation and retain the exact byte snapshot.
fn (executable &Executable) minimum_validation_arguments() u32 {
	mut minimum := u32(0)
	for instruction in executable.instructions {
		for index in 0 .. instruction.input_count() {
			required := validation_argument_requirement(instruction.input_operand(index))
			if required > minimum { minimum = required }
		}
		if instruction.writes_operand() {
			required := validation_argument_requirement(instruction.dst)
			if required > minimum { minimum = required }
		}
		if instruction.op == .get_callee_and_this {
			required := validation_argument_requirement(instruction.rhs)
			if required > minimum { minimum = required }
		}
		if instruction.op in [.call, .construct, .super_construct, .copy_object_excluding_keys,
			.enter_class_private_environment] {
			for operand in instruction.arguments {
				required := validation_argument_requirement(operand)
				if required > minimum { minimum = required }
			}
		}
	}
	return minimum
}
