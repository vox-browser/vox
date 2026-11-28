module libjs

import encoding.base64
import os
import platform

$if test {
	// Fresh-process, single-threaded diagnostic. Timed cohorts leave the path
	// unset. Native diagnostics delimit the post-initialization interval.
	const executable_profile_path = os.getenv('VOX_LIBJS_TEST_EXECUTABLE_PROFILE')
	__global executable_profile_seen map[voidptr]bool
	__global executable_profile_failed bool

	fn (vm &VM) profile_executable_for_testing(executable &Executable, frame &ExecutionContext) {
		if executable_profile_path == '' || executable_profile_failed { return }
		tier := vm.native_tier or { return }
		if !tier.diagnostics { return }
		address := voidptr(executable)
		mut output := ''
		if address !in executable_profile_seen {
			persistent := platform.enter_persistent()
			executable_profile_seen[address] = true
			platform.leave_persistent(persistent)
			mut parameters := []string{}
			mut function_flags := 'script'
			if function := frame.function {
				if function is ECMAScriptFunction {
					unobservable := if scope := function.data.body.kind.scope {
						function.arguments_are_unobservable(scope)
					} else {
						false
					}
					function_flags = '${function.data.kind}:${function.data.is_arrow_function}:${function.data.is_strict_mode}:${unobservable}'
					for index, binding in function.register_bindings {
						if index >= 64 { break }
						parameters << '${binding.slot}:${binding.parameter_index}'
					}
				}
			}
			mut instructions := []string{}
			for index, instruction in executable.instructions {
				if index >= 16 { break }
				instructions << '${instruction.op}:${instruction.dst.raw}:${instruction.lhs.raw}:${instruction.rhs.raw}'
			}
			mut constants := []string{}
			for index, value in executable.constants {
				if index >= 64 { break }
				constants << value.tag.str()
			}
			filename := if source := executable.source_code { source.filename.str() } else { '' }
			output = 'M\t${u64(uint(address))}\t${base64.encode_str(executable.native_cache_scope)}\t${base64.encode_str(executable.name.str())}\t${executable.registers_and_locals_count}\t${executable.local_index_base}\t${parameters.join(',')}\t${constants.join(',')}\t${instructions.join(';')}\t${base64.encode_str(filename)}\t${function_flags}\n'
		}
		output += 'C\t${u64(uint(address))}\n'
		mut file := os.open_append(executable_profile_path) or {
			executable_profile_failed = true
			eprintln('Executable profile open failed: ${err.msg()}')
			return
		}
		file.write_string(output) or {
			executable_profile_failed = true
			eprintln('Executable profile write failed: ${err.msg()}')
		}
		file.close()
	}
}
