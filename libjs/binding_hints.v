module libjs

import platform

// A get_binding whose identifier no direct eval can shadow (scope analysis
// leaves is_inside_scope_with_eval unset) sees the same chain of declarative
// environments on every execution: static nesting fixes their order and
// their binding lists. The instruction carries this mark in `target` and
// remembers where it found the binding (environment hops and binding index).
// A later read walks that many environments and checks the binding's name
// at that index; a `with` object, the global environment or a mismatch take
// the ordinary lookup, which only records chains of declarative environments.
const static_binding_scope = u32(1)
// An identifier declared in no enclosing scope (and no eval) resolves in the
// realm's global environment: its lexical declarations, then the global
// object. Such reads start there instead of walking every environment.
const global_binding_scope = u32(2)
const no_binding_hint = u32(0xffffffff)
const binding_hint_index_mask = u32(0xffffff)

@[inline]
fn (executable &Executable) binding_hint(pc u32) &u32 {
	if executable.binding_hints.len != executable.instructions.len { executable.allocate_binding_hints() }
	// run_executable() dispatches only instructions inside the stream.
	return unsafe { &u32(executable.binding_hints.data) + pc }
}

fn (executable &Executable) allocate_binding_hints() {
	persistent := platform.enter_persistent()
	mut owner := unsafe { &Executable(executable) }
	owner.binding_hints = []u32{len: executable.instructions.len, init: no_binding_hint}
	platform.leave_persistent(persistent)
}

@[inline]
fn record_binding_coordinate(coordinate &u32, declarative_path bool, hops u32, index int) {
	if coordinate == unsafe { nil } || !declarative_path || hops > 254 || index < 0
		|| u32(index) > binding_hint_index_mask {
		return
	}
	unsafe {
		*coordinate = (hops << 24) | u32(index)
	}
}

@[direct_array_access]
fn (environment &DeclarativeEnvironment) hinted_binding_matches(index int, name &Utf16String) bool {
	if index < 0 || index >= environment.bindings.len { return false }
	// Deleted bindings keep their slots (declarative_environment.v).
	if environment.bindings[index].deleted { return false }
	binding_name := unsafe { &environment.bindings[index].name }
	if binding_name.data.len != name.data.len { return false }
	if binding_name.data.data == name.data.data { return true }
	if !utf16_equals(binding_name.data, name.data) { return false }
	// Equal code units: let the binding share the identifier's storage so the
	// next check from this site matches by pointer. Plain code-unit strings
	// only; the name's value is unchanged.
	if binding_name.storage_ == unsafe { nil } && name.storage_ == unsafe { nil } {
		unsafe {
			mut owner := &DeclarativeEnvironment(environment)
			owner.bindings[index].name = *name
		}
	}
	return true
}

// The running realm's global environment, which ends every scope chain.
fn (vm &VM) running_global_environment() ?Environment {
	realm := vm.current_context().realm or { return none }
	global := realm.global_environment or { return none }
	return Environment(global)
}

// The environment `hops` outer links above the running lexical environment.
fn (vm &VM) hinted_binding_environment(coordinate u32) ?Environment {
	if coordinate == no_binding_hint { return none }
	mut environment := vm.current_context().lexical_environment or { return none }
	for _ in 0 .. coordinate >> 24 {
		environment = environment.outer_environment() or { return none }
	}
	return environment
}
