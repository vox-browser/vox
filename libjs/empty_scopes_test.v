module libjs

fn empty_scope_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'empty-scopes.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_empty_scope_elision_preserves_lexical_shadowing_catch_finally_and_closures() {
	defer { set_empty_scope_elision_for_testing(true) }
	for enabled in [false, true] {
		set_empty_scope_elision_for_testing(enabled)
		for source in [
			'function f(n){var a=0;while(n-->0){if(n>=0){a+=7}}return a}f(6)',
			'function f(){var x=42;{let x=0;x++}return x}f()',
			'function f(){var g;{let x=42;g=()=>x}return g()}f()',
			'function f(){var x=0;try{{x=40;throw 1}}catch(e){{x+=e}}finally{{x++}}return x}f()',
			'function f(){var x=0;outer:while(true){{x=42;break outer}}return x}f()',
			'function f(){var x=0;try{{return 40}}finally{{return 42}}}f()',
			'function f(){var x=42;{class X {value(){return x}}return new X().value()}}f()',
			'function f(){var x=42;{return ()=>x}}f()()',
		] {
			mut vm := VM.create()
			create_simple_execution_context(mut vm)
			assert empty_scope_eval(mut vm, source)!.number == 42, source
			assert vm.interpreter_stack().depth() == 0 && vm.execution_context_stack().len == 1
		}
	}
}

fn test_empty_blocks_emit_native_noops_but_lexical_blocks_retain_environments() {
	set_empty_scope_elision_for_testing(true)
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	diagnose_empty_scopes_for_testing(true)
	mut script := Script.parse('var x=0;{x=1}{let x=2;x++}x', vm.realm(), 'scope-code.js', unsafe { nil })!
	executable := script.compile(mut vm)!
	assert executable.instructions.any(it.op == .nop)
	assert executable.instructions.any(it.op == .enter_scope)
	assert vm.run(mut script)!.number == 1
	activity := diagnose_empty_scopes_for_testing(false)
	assert activity.elided > 0 && activity.retained > 0
}

fn test_empty_scope_noops_preserve_loop_instruction_budget_and_cleanup() {
	defer { set_empty_scope_elision_for_testing(true) }
	for budget in 1 .. 70 {
		mut completed := []bool{}
		for enabled in [false, true] {
			set_empty_scope_elision_for_testing(enabled)
			mut vm := VM.create()
			create_simple_execution_context(mut vm)
			mut script := Script.parse('var n=0;while(n<3){n++}n', vm.realm(), 'scope-budget.js', unsafe { nil })!
			if value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: u64(budget) }) {
				assert value.number == 3
				completed << true
			} else {
				assert is_throw_completion(err)
				assert thrown_value(err).as_object().error_message()?.contains('budget')
				completed << false
			}
			assert vm.interpreter_stack().depth() == 0 && vm.execution_context_stack().len == 1
		}
		assert completed[0] == completed[1], 'budget ${budget}'
	}
}
