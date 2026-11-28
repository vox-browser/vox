module libjs

@[heap]
struct CompilerValidationOwner {
	marker u8 = 1
}

struct CompilerValidation {
	owner        &CompilerValidationOwner
	shape        ValidationShape
	instructions voidptr
	handlers     voidptr
}

$if test {
	__global compiler_validation_disabled bool
	pub fn set_compiler_validation_for_testing(enabled bool) {
		compiler_validation_disabled = !enabled
	}
}

fn use_compiler_validation() bool {
	$if test {
		if compiler_validation_disabled { return false }
	}
	return true
}

// Explicit embedding ownership contract. While enabled, the embedder must not
// mutate compiler-finalized instruction streams, nested operands, handlers or
// validation-relevant layouts/tables. Disable while idle before making edits.
// The default VM retains exact mutable-input validation on every execution.
pub fn (mut vm VM) use_immutable_compiler_executables(enabled bool) ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot change compiled executable ownership during execution')
	}
	if !enabled {
		vm.compiler_validation_owner = none
	} else if vm.compiler_validation_owner == none {
		// Older executables retain their previous token. Disabling, editing and
		// re-enabling can never restore trust in those old compiled bodies.
		vm.compiler_validation_owner = &CompilerValidationOwner{}
	}
}

// Only the three compiler completion paths call this, immediately after a
// successful validate(0). Arbitrary embedding-created streams are never marked.
fn (vm &VM) remember_compiler_validation(executable &Executable) {
	owner_token := vm.compiler_validation_owner or { return }
	mut owner := unsafe { &Executable(executable) }
	owner.compiler_validation = CompilerValidation{
		owner:        owner_token
		shape:        executable.validation_shape(0)
		instructions: executable.instructions.data
		handlers:     executable.exception_handlers.data
	}
	// The shape covers every layout field the operand bases depend on.
	executable.operand_slots_for(executable.operand_bases())
}

// Returns whether the compiler's record vouched for the executable's layout,
// including the operand slots built with it.
fn (mut vm VM) validate_execution(executable &Executable, arguments u32) !bool {
	if use_compiler_validation() {
		if owner := vm.compiler_validation_owner {
			if validation := executable.compiler_validation {
				// Compiler finalization validates arity zero, so it cannot contain an
				// argument operand. Added arguments need only the live overflow check.
				// Keep inexpensive metadata/replacement guards even for owned code.
				if voidptr(validation.owner) == voidptr(owner)
					&& validation.shape == executable.validation_shape(0)
					&& validation.instructions == executable.instructions.data
					&& validation.handlers == executable.exception_handlers.data
					&& u64(executable.registers_and_locals_count) + u64(executable.constants.len) + u64(arguments) <= 0xffffffff {
					if mut tier := vm.native_tier {
						if tier.diagnostics { tier.activity.compiler_validation_hits++ }
					}
					return true
				}
			}
		}
	}
	executable.validate(arguments)!
	return false
}
