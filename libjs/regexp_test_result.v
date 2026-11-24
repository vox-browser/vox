module libjs

$if test {
	__global regexp_test_results_disabled bool
	__global regexp_test_results_diagnostics bool
	__global regexp_test_results u64
	pub fn set_regexp_test_results_for_testing(enabled bool) {
		regexp_test_results_disabled = !enabled
	}
	pub fn diagnose_regexp_test_results_for_testing(enabled bool) u64 {
		previous := regexp_test_results
		regexp_test_results = 0
		regexp_test_results_diagnostics = enabled
		return previous
	}
}

fn use_regexp_test_results() bool {
	$if test {
		if regexp_test_results_disabled { return false }
	}
	return true
}

fn regexp_prototype_exec_test(mut vm VM) !Value {
	mut regex := regexp_receiver(mut vm)!
	text := vm.argument(0).to_primitive_string(mut vm)!
	return regex.builtin_exec_result(mut vm, text, false)
}

// Lookup still precedes dispatch on every invocation, so overrides, getters,
// proxies and reentrant lastIndex conversions retain their ordinary behavior.
fn regexp_exec_for_test(mut vm VM, object &Object, text &PrimitiveString) !Value {
	if !use_regexp_test_results() { return regexp_exec(mut vm, object, text) }
	exec := object.get(mut vm, PropertyName.from_str('exec'))!
	if exec.is_function() {
		mut function := exec.as_function()
		if mut function is NativeFunction {
			if function.intrinsic_regexp_exec {
				$if test {
					if regexp_test_results_diagnostics { regexp_test_results++ }
				}
				return function.call_in_frame(mut vm, Value.from_object(object), [Value.from_string(text)], regexp_prototype_exec_test)
			}
		}
		result := call(mut vm, exec, Value.from_object(object), [Value.from_string(text)])!
		if !result.is_object() && !result.is_null() {
			return vm.throw_error(.type_error, 'RegExp exec must return an object or null')
		}
		return result
	}
	mut regex := object.slots.regexp_object or { return vm.throw_error(.type_error, 'RegExp exec requires RegExp internal slots') }
	$if test {
		if regexp_test_results_diagnostics { regexp_test_results++ }
	}
	return regex.builtin_exec_result(mut vm, text, false)
}
