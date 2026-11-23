module libjs

// Executable remains mutable. Reuse validation only when every byte that the
// validator inspects is unchanged, including nested call operands and handlers.
// This is an exact comparison, not a hash or an immutability assumption.
const validation_snapshot_limit = 64 * 1024

struct ValidationShape {
	arguments       u32
	registers       u32
	local_base      u32
	bytecode_length u32
	instructions    int
	constants       int
	locals          int
	identifiers     int
	functions       int
	class_fields    int
	classes         int
	handlers        int
}

struct ValidationArguments {
	instruction int
	bytes       []u8
}

@[heap]
struct ValidationSnapshot {
	shape        ValidationShape
	minimum_arguments u32
	validated_arguments u32
	instructions []u8
	handlers     []u8
	arguments    []ValidationArguments
}

pub struct ValidationActivity {
pub:
	hits   u64
	misses u64
}

$if test {
	__global validation_cache_disabled_for_test bool
	__global validation_cache_diagnostic_for_test bool
	__global validation_cache_hits_for_test u64
	__global validation_cache_misses_for_test u64
	pub fn set_validation_cache_for_testing(enabled bool) {
		validation_cache_disabled_for_test = !enabled
	}
	pub fn diagnose_validation_cache_for_testing(enabled bool) ValidationActivity {
		previous := ValidationActivity{validation_cache_hits_for_test, validation_cache_misses_for_test}
		validation_cache_hits_for_test = 0
		validation_cache_misses_for_test = 0
		validation_cache_diagnostic_for_test = enabled
		return previous
	}
}

fn (executable &Executable) validation_shape(arguments u32) ValidationShape {
	return ValidationShape{if use_validation_arity() { u32(0) } else { arguments }, executable.registers_and_locals_count, executable.local_index_base, executable.bytecode_length, executable.instructions.len, executable.constants.len, executable.local_variable_names.len, executable.identifier_table.len, if executable.parsed_source == unsafe { nil } {
		-1
	} else {
		executable.parsed_source.function_table.entries.len
	}, executable.class_field_initializers.len, executable.class_source_spans.len, executable.exception_handlers.len}
}

fn validation_bytes_equal(bytes []u8, data voidptr, count int) bool {
	return bytes.len == count && (count == 0 || unsafe { vmemcmp(bytes.data, data, count) } == 0)
}

fn validation_copy_bytes(data voidptr, count int) []u8 {
	mut bytes := []u8{len: count}
	if count > 0 { unsafe { vmemcpy(bytes.data, data, count) } }
	return bytes
}

fn (executable &Executable) reuse_validation(arguments u32) bool {
	$if test {
		if validation_cache_disabled_for_test { return false }
	}
	if snapshot := executable.validation_snapshot {
		if arguments >= snapshot.minimum_arguments
			&& u64(executable.registers_and_locals_count) + u64(executable.constants.len) + u64(arguments) <= 0xffffffff
			&& snapshot.shape == executable.validation_shape(arguments)
			&& validation_bytes_equal(snapshot.instructions, executable.instructions.data, executable.instructions.len * int(sizeof(Instruction)))
			&& validation_bytes_equal(snapshot.handlers, executable.exception_handlers.data, executable.exception_handlers.len * int(sizeof(ExceptionHandlers))) {
			mut same := true
			for entry in snapshot.arguments {
				current := &executable.instructions[entry.instruction].arguments
				if !validation_bytes_equal(entry.bytes, current.data, current.len * int(sizeof(Operand))) {
					same = false
					break
				}
			}
			if same {
				$if test {
					if validation_arity_diagnostics && use_validation_arity() && arguments != snapshot.validated_arguments { validation_arity_hits++ }
				}
				$if test {
					if validation_cache_diagnostic_for_test { validation_cache_hits_for_test++ }
				}
				return true
			}
		}
	}
	$if test {
		if validation_cache_diagnostic_for_test { validation_cache_misses_for_test++ }
	}
	return false
}

fn (executable &Executable) remember_validation(arguments u32) {
	$if test {
		if validation_cache_disabled_for_test { return }
	}
	mut owner := unsafe { &Executable(executable) }
	if owner.validation_successes < 2 { owner.validation_successes++ }
	if owner.validation_successes < 2 { return }
	mut size := executable.instructions.len * int(sizeof(Instruction)) + executable.exception_handlers.len * int(sizeof(ExceptionHandlers))
	if size > validation_snapshot_limit { return }
	mut entries := []ValidationArguments{}
	for index, instruction in executable.instructions {
		if instruction.arguments.len == 0 { continue }
		size += instruction.arguments.len * int(sizeof(Operand))
		if size > validation_snapshot_limit { return }
		entries << ValidationArguments{
			instruction: index
			bytes:       validation_copy_bytes(instruction.arguments.data, instruction.arguments.len * int(sizeof(Operand)))
		}
	}
	owner.validation_snapshot = &ValidationSnapshot{
		shape:        executable.validation_shape(arguments)
		minimum_arguments: executable.minimum_validation_arguments()
		validated_arguments: arguments
		instructions: validation_copy_bytes(executable.instructions.data, executable.instructions.len * int(sizeof(Instruction)))
		handlers:     validation_copy_bytes(executable.exception_handlers.data, executable.exception_handlers.len * int(sizeof(ExceptionHandlers)))
		arguments:    entries
	}
}
