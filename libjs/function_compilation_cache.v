// SPDX-License-Identifier: BSD-2-Clause
module libjs

// SharedFunctionInstanceData owns compiled function bodies upstream. This port
// keeps realm-local bodies beside the realm-neutral frontend, so constants and
// register layouts never leak across realms or source-location owners.
struct FunctionExecutableCacheEntry {
	source_code       &SourceCode
	starting_line     u32
	name              Utf16String
	registers_enabled bool
	executable        &Executable
	register_bindings []FunctionRegisterBinding
}

pub struct FunctionCompilationActivity {
pub mut:
	compiled u64
	reused   u64
	entries  u64
}

pub fn (realm &Realm) function_compilation_stats() FunctionCompilationActivity {
	return realm.function_compilation_activity
}

fn register_compilation_enabled() bool {
	$if test {
		return !register_bindings_disabled_for_test
	}
	return true
}

fn (function &ECMAScriptFunction) can_share_function_compilation() bool {
	// Field initializers embed their instance-specific property key in the
	// anonymous function's name operand, including unique Symbols.
	return function.field_initializer_name == none && function.data.body.kind.tag != .class_field_initializer
}

fn (function &ECMAScriptFunction) cached_function_compilation() ?FunctionExecutableCacheEntry {
	if !function.can_share_function_compilation() { return none }
	code := function.source.source_code or { return none }
	name := function.name_for_call_stack()
	for entry in function.realm_.function_executable_cache[voidptr(function.data)] {
		if voidptr(entry.source_code) == voidptr(code) && entry.starting_line == function.source.starting_line
			&& entry.name == name && entry.registers_enabled == register_compilation_enabled() {
			mut realm := unsafe { &Realm(function.realm_) }
			realm.function_compilation_activity.reused++
			return entry
		}
	}
	return none
}

fn (function &ECMAScriptFunction) remember_function_compilation(executable &Executable) {
	mut realm := unsafe { &Realm(function.realm_) }
	realm.function_compilation_activity.compiled++
	if !function.can_share_function_compilation() { return }
	code := function.source.source_code or { return }
	realm.function_executable_cache[voidptr(function.data)] << FunctionExecutableCacheEntry{
		source_code:       code
		starting_line:     function.source.starting_line
		name:              function.name_for_call_stack()
		registers_enabled: register_compilation_enabled()
		executable:        executable
		register_bindings: function.register_bindings
	}
	realm.function_compilation_activity.entries++
}
