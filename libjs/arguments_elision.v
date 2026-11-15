module libjs

pub struct ArgumentAllocationActivity {
pub:
	created u64
	elided  u64
}

$if test {
	__global argument_elision_disabled_for_test bool
	__global argument_allocation_diagnostic_for_test bool
	__global argument_objects_created_for_test u64
	__global argument_objects_elided_for_test u64

	pub fn set_argument_elision_for_testing(enabled bool) {
		argument_elision_disabled_for_test = !enabled
	}

	pub fn diagnose_argument_allocation_for_testing(enabled bool) ArgumentAllocationActivity {
		previous := ArgumentAllocationActivity{argument_objects_created_for_test, argument_objects_elided_for_test}
		argument_objects_created_for_test = 0
		argument_objects_elided_for_test = 0
		argument_allocation_diagnostic_for_test = enabled
		return previous
	}
}

fn (function &ECMAScriptFunction) elide_unobserved_arguments(scope &ScopeData) bool {
	$if test {
		if argument_elision_disabled_for_test { return false }
	}
	// Only parser-owned functions have reliable parsing insights. Preserve the
	// conservative binding for embedders that construct function records by hand.
	// Arrow captures and parameter initializers contribute to the owning
	// function's insights; eval and explicit scope access also forbid elision.
	if function.source.parsed_source == unsafe { nil }
		|| function.data.parsing_insights.might_need_arguments_object
		|| function.data.parsing_insights.contains_direct_call_to_eval
		|| scope.contains_direct_call_to_eval || scope.contains_access_to_arguments_object {
		return false
	}
	$if test {
		if argument_allocation_diagnostic_for_test { argument_objects_elided_for_test++ }
	}
	return true
}
