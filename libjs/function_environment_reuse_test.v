module libjs

fn environment_reuse_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'environment-reuse.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_empty_function_environment_reuse_clears_old_references_and_reports_roots() {
	set_function_environment_reuse_for_testing(true)
	mut stack := InterpreterStack.new()
	mut first := stack.allocate_reusable(5, [], 0)?
	mut environment := FunctionEnvironment.create(none)
	environment.this_value = Value.from_i32(42)
	environment.new_target = Value.from_i32(43)
	first.cached_call_environment = environment
	first.call_environment = environment
	stack.deallocate(0)
	second := stack.allocate_reusable(5, [], 0)?
	assert voidptr(second.cached_call_environment?) == voidptr(environment)
	assert second.call_environment == none
	assert environment.outer == none && environment.function_object == none
	assert environment.this_value.is_undefined() && environment.new_target.is_undefined()
	mut roots := HeapRoots{}
	second.visit_roots(mut roots)
	assert roots.contains(voidptr(environment))
	stack.deallocate(0)
}

fn test_function_environment_reuse_executes_and_preserves_escaping_this_closures() {
	for enabled in [false, true] {
		set_function_environment_reuse_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		assert environment_reuse_eval(mut vm, 'function plus(a){return a+1}plus(40);plus(41);plus(42)')!.number == 43
		activity := vm.diagnose_native_code(false)!
		assert (activity.function_environments_reused > 0) == enabled
		assert environment_reuse_eval(mut vm, 'function outer(){return ()=>this.n}var a=outer.call({n:41}),b=outer.call({n:42});a()===41&&b()===42')!.as_bool()
		assert environment_reuse_eval(mut vm, 'function local(n){let x=n;return ()=>x}var c=local(41),d=local(42);c()===41&&d()===42')!.as_bool()
		assert vm.interpreter_stack().depth() == 0
	}
	set_function_environment_reuse_for_testing(true)
}

@[heap]
struct SavedCallEnvironments {
mut:
	environments []Environment
}

fn test_environment_and_native_frame_exposure_keep_original_this_bindings_after_return() {
	for mode in 0 .. 6 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut saved := &SavedCallEnvironments{}
		capture := NativeFunction.create(mut vm,vm.realm(),vm.realm().function_prototype,fn [mode,mut saved] (mut vm VM) !Value {
			mut environment := ?Environment(none)
			if mode == 0 { environment = vm.lexical_environment() }
			else if mode == 1 { environment = vm.variable_environment() }
			else if mode == 2 { environment = vm.running_execution_context().lexical_environment }
			else if mode == 3 { environment = vm.current_context().copy().lexical_environment }
			else if mode == 4 {
				mut roots := HeapRoots{}
				vm.current_context().visit_roots(mut roots)
				environment = vm.current_context().lexical_environment
			} else {
				vm.resolve_binding(utf16_string('capture'),false,none)!
				environment = vm.current_context().lexical_environment
			}
			saved.environments << environment or { return error('missing environment') }
			return js_undefined()
		},0,PropertyName.from_str('capture'),none)
		mut global := vm.global_object()
		global.define_direct_property(PropertyName.from_str('capture'),Value.from_object(capture.object),7)
		assert environment_reuse_eval(mut vm,'function run(){capture();return 0}run.call({n:41});run.call({n:42})')!.number == 0
		assert saved.environments.len == 2
		assert environment_identity(saved.environments[0]) != environment_identity(saved.environments[1])
		for index, environment in saved.environments {
			value := environment.get_this_binding(mut vm)!
			assert value.as_object().get(mut vm,PropertyName.from_str('n'))!.number == 41 + index
		}
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_child_context_scopes_protect_their_callers_empty_environment() {
 mut vm:=VM.create()
 mut caller:=create_simple_execution_context(mut vm)
 environment:=FunctionEnvironment.create(caller.lexical_environment)
 caller.lexical_environment=Environment(environment)
 caller.call_environment=environment
 scope:=DeclarativeEnvironment.create(caller.lexical_environment)
 mut child:=ExecutionContext.create(0,[],0)
 child.lexical_environment=Environment(scope)
 vm.push_execution_context(mut child)
 assert environment.call_reuse_exposed
 vm.pop_execution_context()
}
