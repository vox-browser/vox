module libjs

import platform

// Declarative names are unique; deletion retains a slot. Remember successful
// positions only, and reread the live name/deleted bit before using a hint.
// Values, absence and outer-environment resolution are never cached.
// Hints hold at most one position per name found, so only large scopes reach
// the bound. Bundled modules keep hundreds of functions in one factory scope;
// inner closures that read more than 64 of those names cleared a 64-entry
// table on nearly every insertion and fell back to scanning the whole scope.
const binding_lookup_hint_minimum = 16
const binding_lookup_hint_limit = 4096

@[heap]
struct BindingLookupHints {
mut:
	positions map[u64]int
}

pub struct BindingLookupActivity {
pub:
	hits   u64
	misses u64
}

$if test {
	__global binding_lookup_hints_disabled bool
	__global binding_lookup_diagnostics bool
	__global binding_lookup_hits u64
	__global binding_lookup_misses u64
	pub fn set_binding_lookup_hints_for_testing(enabled bool) {
		binding_lookup_hints_disabled = !enabled
	}
	pub fn diagnose_binding_lookup_for_testing(enabled bool) BindingLookupActivity {
		previous := BindingLookupActivity{binding_lookup_hits, binding_lookup_misses}
		binding_lookup_hits = 0
		binding_lookup_misses = 0
		binding_lookup_diagnostics = enabled
		return previous
	}
}

$if test {
	__global binding_lookup_hint_limit_for_test int
	pub fn set_binding_lookup_hint_limit_for_testing(limit int) { binding_lookup_hint_limit_for_test = limit }
}

fn binding_lookup_limit() int {
	$if test { if binding_lookup_hint_limit_for_test > 0 { return binding_lookup_hint_limit_for_test } }
	return binding_lookup_hint_limit
}

fn binding_lookup_hash(name Utf16String) u64 {
	mut hash := u64(14695981039346656037)
	for unit in name.data { hash = (hash ^ u64(unit)) * 1099511628211 }
	return hash
}

fn (environment &DeclarativeEnvironment) find_binding_index_with_hints(name Utf16String) int {
	hash := binding_lookup_hash(name)
	if hints := environment.binding_lookup_hints {
		if index := hints.positions[hash] {
			if index >= 0 && index < environment.bindings.len {
				binding := &environment.bindings[index]
				if !binding.deleted && binding.name == name {
					$if test {
						if binding_lookup_diagnostics { binding_lookup_hits++ }
					}
					return index
				}
			}
		}
	}
	$if test {
		if binding_lookup_diagnostics { binding_lookup_misses++ }
	}
	index := environment.find_binding_index_linear(name)
	if index < 0 { return index }
	// A public/native caller may enter with a temporary arena while the lexical
	// environment survives. Both the table and any resized backing store belong
	// to persistent storage.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &DeclarativeEnvironment(environment) }
	mut hints := owner.binding_lookup_hints or {
		created := &BindingLookupHints{}
		owner.binding_lookup_hints = created
		created
	}
	if hints.positions.len >= binding_lookup_limit() { hints.positions.clear() }
	hints.positions[hash] = index
	return index
}
