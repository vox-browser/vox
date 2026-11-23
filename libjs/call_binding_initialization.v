module libjs

$if test {
	__global direct_call_bindings_disabled bool
	__global direct_call_bindings_diagnostics bool
	__global direct_call_bindings u64
	pub fn set_direct_call_bindings_for_testing(enabled bool) {
		direct_call_bindings_disabled = !enabled
	}
	pub fn diagnose_direct_call_bindings_for_testing(enabled bool) u64 {
		previous := direct_call_bindings
		direct_call_bindings = 0
		direct_call_bindings_diagnostics = enabled
		return previous
	}
}

fn use_direct_call_bindings() bool {
	$if test {
		if direct_call_bindings_disabled { return false }
	}
	return true
}

// Simple parameters have already been evaluated by the caller. Resolve the
// live binding once; duplicate parameter names still overwrite in list order.
fn (mut environment FunctionEnvironment) initialize_call_parameter(mut vm VM, name Utf16String, value Value) ! {
	index := environment.find_binding_index(name)
	if index >= 0 {
		if environment.bindings[index].initialized {
			environment.set_mutable_binding_direct(mut vm, index, value, false)!
		} else {
			environment.initialize_binding_direct(mut vm, index, value, .normal)!
		}
	} else {
		environment.create_mutable_binding(mut vm, name, false)!
		environment.initialize_binding_direct(mut vm, environment.bindings.len - 1, value, .normal)!
	}
	$if test {
		if direct_call_bindings_diagnostics { direct_call_bindings++ }
	}
}

fn (mut environment FunctionEnvironment) initialize_call_var(mut vm VM, name Utf16String) ! {
	if environment.find_binding_index(name) >= 0 { return }
	// There is no callback between appending this binding and initializing it.
	environment.create_mutable_binding(mut vm, name, false)!
	environment.initialize_binding_direct(mut vm, environment.bindings.len - 1, js_undefined(), .normal)!
	$if test {
		if direct_call_bindings_diagnostics { direct_call_bindings++ }
	}
}
