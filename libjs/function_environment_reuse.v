module libjs

$if test {
	__global function_environment_reuse_disabled bool
	pub fn set_function_environment_reuse_for_testing(enabled bool) {
		function_environment_reuse_disabled = !enabled
	}
}

fn use_function_environment_reuse() bool {
	$if test { if function_environment_reuse_disabled { return false } }
	return true
}

// Native frames inherit this marker independently of their own cached record.
// Exposing a native frame therefore also protects its caller's environment.
fn expose_function_environment(environment &FunctionEnvironment) {
	mut owner := unsafe { &FunctionEnvironment(environment) }
	owner.call_reuse_exposed = true
}

fn expose_call_environment(context &ExecutionContext) {
	if environment := context.call_environment { expose_function_environment(environment) }
}

fn (vm &VM) expose_current_call_environment() {
	if context := vm.running_execution_context_ { expose_call_environment(context) }
}

fn (vm &VM) inherit_call_environment(mut context ExecutionContext) {
	if context.call_environment != none { return }
	if caller := vm.running_execution_context_ {
		if environment := caller.call_environment {
			if caller_lexical := caller.lexical_environment {
				if callee_lexical := context.lexical_environment {
					if same_environment(caller_lexical, callee_lexical) { context.call_environment = environment; return }
				}
			}
			// A child/replaced/custom lexical scope may retain this environment.
			// Protect it without invoking additional virtual outer-scope hooks.
			expose_function_environment(environment)
		}
	}
}

fn (mut vm VM) obtain_call_environment(mut context ExecutionContext, outer ?Environment) &FunctionEnvironment {
	if use_function_environment_reuse() {
		if cached := context.cached_call_environment {
			if !cached.call_reuse_exposed && cached.bindings.len == 0 {
				mut environment := unsafe { &FunctionEnvironment(cached) }
				environment.outer = outer
				context.call_environment = environment
				if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.function_environments_reused++ } }
				return environment
			}
		}
	}
	environment := FunctionEnvironment.create(outer)
	context.cached_call_environment = environment
	context.call_environment = environment
	if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.function_environments_allocated++ } }
	return environment
}

fn (context &ExecutionContext) can_recycle_call_environment() bool {
	if !use_function_environment_reuse() { return false }
	if cached := context.cached_call_environment { return !cached.call_reuse_exposed && cached.bindings.len == 0 }
	return false
}

fn (context &ExecutionContext) recycled_context_bytes() uint {
	return frame_size_in_bytes(u64(context.values.cap)) + if context.cached_call_environment != none { uint(sizeof(FunctionEnvironment)) } else { uint(0) }
}

fn (context &ExecutionContext) recycle_call_environment() ?&FunctionEnvironment {
	if !use_function_environment_reuse() { return none }
	if cached := context.cached_call_environment {
		if !cached.call_reuse_exposed && cached.bindings.len == 0 {
			mut environment := unsafe { &FunctionEnvironment(cached) }
			// Drop every old realm/function/this/outer reference before pooling.
			unsafe { *environment = FunctionEnvironment{kind: .function, declarative: true} }
			return environment
		}
	}
	return none
}
