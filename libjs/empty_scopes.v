module libjs

pub struct EmptyScopeActivity {
pub:
	elided   u64
	retained u64
}

$if test {
	__global empty_scopes_disabled_for_test bool
	__global empty_scopes_diagnostic_for_test bool
	__global empty_scopes_elided_for_test u64
	__global empty_scopes_retained_for_test u64
	pub fn set_empty_scope_elision_for_testing(enabled bool) {
		empty_scopes_disabled_for_test = !enabled
	}
	// Compilation counts; native activity separately verifies executed no-ops.
	pub fn diagnose_empty_scopes_for_testing(enabled bool) EmptyScopeActivity {
		previous := EmptyScopeActivity{empty_scopes_elided_for_test, empty_scopes_retained_for_test}
		empty_scopes_elided_for_test = 0
		empty_scopes_retained_for_test = 0
		empty_scopes_diagnostic_for_test = enabled
		return previous
	}
}

// A block whose let/const bindings all live in registers needs no environment.
fn elide_empty_block(scope &ScopeData, lexicals_in_registers bool) bool {
	mut eligible := !scope.contains_direct_call_to_eval && scope.annexb_function_names.len == 0
	for child in scope.children {
		if child.kind.tag == .class_declaration || child.function_declaration_for_labelled_item() != none
			|| (child.kind.tag == .variable_declaration && child.kind.decl_kind != .var_kind
			&& !lexicals_in_registers) {
			eligible = false
			break
		}
	}
	$if test {
		if empty_scopes_disabled_for_test { eligible = false }
		if empty_scopes_diagnostic_for_test {
			if eligible { empty_scopes_elided_for_test++ } else { empty_scopes_retained_for_test++ }
		}
	}
	return eligible
}
