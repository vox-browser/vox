module libjs

import os
import rand

fn elision_eval(mut vm VM, text string) !Value {
	mut script := Script.parse(text, vm.realm(), 'argument-elision.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn elision_binding_needed(value Value) bool {
	mut function := value.as_object().callable or { panic('Missing callable') }
	if mut function is ECMAScriptFunction { return function.needs_arguments_binding() }
	panic('Expected ECMAScript function')
}

fn test_unused_arguments_skip_allocation_but_control_keeps_the_same_result() {
	for enabled in [false, true] {
		set_argument_elision_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		diagnose_argument_allocation_for_testing(true)
		assert elision_eval(mut vm, 'function add(a,b){return a+b}add(20,22)')!.number == 42
		stats := diagnose_argument_allocation_for_testing(false)
		assert stats.created == u64(if enabled { 0 } else { 1 })
		assert stats.elided == u64(if enabled { 1 } else { 0 })
	}
	set_argument_elision_for_testing(true)
}

fn test_argument_elision_preserves_strict_sloppy_arrow_and_default_parameter_captures() {
	for source in [
		'function f(a){return ()=>arguments[0]}f(42)()',
		'function f(a){"use strict";return ()=>()=>arguments[0]}f(42)()()',
		'function f(a=()=>arguments){return a}f(undefined,42)()[1]',
		'function f(a){arguments[0]=42;return a}f(1)',
		'function f(a){"use strict";arguments[0]=1;return a}f(42)',
		'function f(a){var arguments;return arguments[0]}f(42)',
		'function f(a){function g(){return arguments[0]}return g(a)}f(42)',
		'function Box(a){this.value=arguments[0]}new Box(42).value',
	] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert elision_eval(mut vm, source)!.number == 42, source
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
}

fn test_eval_and_parserless_function_records_keep_conservative_arguments_binding() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['(function(){return eval("arguments")})', '(function(){return arguments})',
		'(function(){return ()=>arguments})'] {
		assert elision_binding_needed(elision_eval(mut vm, source)!)
	}
	value := elision_eval(mut vm, '(function(a){return a})')!
	assert !elision_binding_needed(value)
	mut function := value.as_object().callable or { panic('Missing callable') }
	if mut function is ECMAScriptFunction {
		mut source := unsafe { &Executable(function.source) }
		parsed := source.parsed_source
		source.parsed_source = unsafe { nil }
		assert function.needs_arguments_binding()
		source.parsed_source = parsed
	}
}

fn test_generator_and_async_calls_elide_only_their_unused_arguments_objects() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	diagnose_argument_allocation_for_testing(true)
	assert elision_eval(mut vm, 'function* gen(a){yield a}gen(42).next().value')!.number == 42
	assert elision_eval(mut vm, 'var result=0;async function f(a){return a}f(42).then(v=>result=v)')!.is_object()
	assert elision_eval(mut vm, 'result')!.number == 42
	stats := diagnose_argument_allocation_for_testing(false)
	assert stats.created == 0 && stats.elided >= 2
}

fn test_native_cache_revisit_preserves_arguments_captures_and_elision() {
	directory := os.join_path(os.temp_dir(), 'vox-arguments-elision-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		diagnose_argument_allocation_for_testing(true)
		assert elision_eval(mut vm, 'function pure(a){return a*2}function capture(a){return ()=>arguments[0]}pure(capture(21)())')!.number == 42
		activity := diagnose_argument_allocation_for_testing(false)
		assert activity.elided > 0 && activity.created > 0
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.compiler_invocations == 0 && stats.cache_misses == 0 && stats.cache_hits >= 3
		}
		vm.close_native_code()!
	}
}

fn test_argument_elision_preserves_exact_budget_boundaries_and_frame_cleanup() {
	defer { set_argument_elision_for_testing(true) }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function total(n){var sum=0;while(n>0){sum+=n;n--}return sum}total(6)', vm.realm(), 'elision-budget.js', unsafe { nil })!
	for budget in 1 .. 100 {
		mut completed := []bool{}
		for enabled in [false, true] {
			set_argument_elision_for_testing(enabled)
			if value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: u64(budget) }) {
				assert value.number == 21
				completed << true
			} else {
				assert is_throw_completion(err)
				assert thrown_value(err).as_object().error_message()?.contains('budget')
				completed << false
			}
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
			assert !vm.instruction_budget_active
		}
		assert completed[0] == completed[1], 'Budget ${budget}'
	}
}
