module libjs

import os
import rand

@[heap]
struct NativeUnwindLog {
mut:
	offsets []u32
}

fn native_test_script(mut vm VM, source string) !&Script {
	return Script.parse(source, vm.realm(), 'native-tier-test.js', unsafe { nil })
}

fn native_test_run(mut vm VM, source string) !Value {
	mut script := native_test_script(mut vm, source)!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn native_test_cache() string {
	return os.join_path(os.temp_dir(), 'vox-native-test-' + rand.uuid_v4())
}

fn test_native_code_preserves_dynamic_types_properties_calls_and_exceptions() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	native_test_run(mut vm, 'function add(a,b){return a+b} function read(o){return o.x} function invoke(f){return f()} function caught(f){try{return f()}catch(e){return e}} function truth(x){if(x)return 1;return 2} function num(x){return -x} add(1,2);read({x:1});invoke(function(){return 1});caught(function(){throw 7});truth(1);num(1)')!
	stats := vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	assert stats.compiled_executables > 5
	assert stats.fast_instructions > 0
	vm.diagnose_native_code(true)!
	assert native_test_run(mut vm, 'add("a","b")')!.as_string().str() == 'ab'
	assert native_test_run(mut vm, 'add(4n,5n)')!.as_bigint().big_integer.str() == '9'
	assert native_test_run(mut vm, 'var o={x:2};read(o);o.x="changed";read(o)')!.as_string().str() == 'changed'
	assert native_test_run(mut vm, 'invoke(function(){return "new function"})')!.as_string().str() == 'new function'
	assert native_test_run(mut vm, 'caught(function(){throw "changed"})')!.as_string().str() == 'changed'
	for source in ['truth("")===2', 'truth("x")===1', 'truth(0n)===2', 'truth(3n)===1', 'truth(NaN)===2',
		'truth({})===1', '1/num(0)===-Infinity', '1/num(-0)===Infinity',
		'add(Infinity,-Infinity)!==add(Infinity,-Infinity)'] {
		assert native_test_run(mut vm, source)!.to_boolean(), source
	}
	activity := vm.diagnose_native_code(false)!
	assert activity.entries > 0 && activity.fast_steps > 0 && activity.slow_steps > 0
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_native_loops_share_budgets_with_recursive_calls_and_restore_the_vm() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	native_test_run(mut vm, 'function loop(n){var x=0;while(n>0){x=x+n;n--}return x} function recurse(n){if(n===0)return 0;return recurse(n-1)+1} loop(5);recurse(5)')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	assert native_test_run(mut vm, 'loop(10)+recurse(10)')!.number == 65
	for source in ['loop(10000)', 'recurse(1000)'] {
		mut script := native_test_script(mut vm, source)!
		if _ := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100 }) {
			assert false, 'Expected shared budget exhaustion'
		} else {
			assert is_throw_completion(err)
			assert thrown_value(err).as_object().error_message() or { '' }.contains('budget')
		}
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
		assert !vm.instruction_budget_active
		assert native_test_run(mut vm, 'loop(3)')!.number == 6
	}
}

fn test_native_binary_cache_rebinds_values_in_a_fresh_vm() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut previous_hash := ''
	for index in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		// Same code layout, different heap strings and constants in each realm.
		mut script := native_test_script(mut vm, '"realm-${index}"')!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		stats := vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		assert stats.cache_hit == (index == 1)
		if index == 1 {
			assert stats.library_sha256 == previous_hash
		}
		previous_hash = stats.library_sha256
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		vm.use_native_code(false)!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		vm.use_native_code(true)!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		vm.close_native_code()!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
	}
}

fn test_failed_native_compilation_keeps_interpreter_execution_available() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	mut script := native_test_script(mut vm, '6*7')!
	assert vm.run(mut script)!.number == 42
	if _ := vm.compile_native_code(cache, '/usr/bin/false', 1) {
		assert false
	}
	assert vm.run(mut script)!.number == 42
	vm.close_native_code()!
}

fn test_native_and_interpreted_paths_exhaust_exactly_the_same_instruction_budget() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	mut script := native_test_script(mut vm, 'var n=3;while(n>0){n--} n')!
	assert vm.run(mut script)!.number == 0
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	for budget in 1 .. 65 {
		mut completed := []bool{}
		for enabled in [false, true] {
			vm.use_native_code(enabled)!
			if result := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: u64(budget) }) {
				assert result.number == 0
				completed << true
			} else {
				assert is_throw_completion(err)
				assert thrown_value(err).as_object().error_message() or { '' }.contains('budget')
				completed << false
			}
			assert vm.execution_context_stack().len == 1
			assert vm.interpreter_stack().depth() == 0
		}
		assert completed[0] == completed[1], 'Different budget boundary at ${budget}'
	}
}

fn test_native_errors_preserve_the_throwing_program_counter_during_unwind_jobs() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	executable := &Executable{
		registers_and_locals_count: 6
		constants:                  [js_null(), Value.from_string(vm.create_string_from_str('x'))]
		instructions:               [
			Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.constant(0) },
			Instruction{ op: .get_property, dst: Operand.register(5), lhs: Operand.register(5), rhs: Operand.constant(1) },
			Instruction{ op: .end, lhs: Operand.register(5) },
		]
		bytecode_length:            3
	}
	for native in [false, true] {
		if native { vm.compile_native_code(cache, '/usr/bin/clang', 1)! }
		mut frame := ExecutionContext.create(6, executable.constants, 0)
		frame.realm = vm.realm()
		vm.push_execution_context_checked(mut frame)!
		mut observed := &NativeUnwindLog{}
		vm.enqueue_promise_job(fn [mut observed, frame] () !Value {
			observed.offsets << frame.program_counter
			return js_undefined()
		}, none)
		if _ := vm.run_executable(mut frame, executable, 0, ExecutionLimits{}) {
			assert false
		} else {
			assert is_throw_completion(err)
		}
		assert frame.program_counter == 1
		assert observed.offsets == [u32(1)]
		vm.pop_execution_context()
	}
}

fn test_native_primitive_lowering_handles_number_edges_and_utf16_order() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	native_test_run(mut vm, 'function calc(a,b=0){return [a%b,a**b,~a,a&b,a|b,a^b,a<<b,a>>b,a>>>b]} function compare(a,b){return [a<b,a<=b,a>b,a>=b]} calc(1,2);compare("x","y")')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	for source in [
		'calc(-4294967297.75,33).slice(2).join() === "0,33,-1,-34,-2,-1,2147483647"',
		'calc(Infinity,Infinity).slice(2).join() === "-1,0,0,0,0,0,0"',
		'calc(4294967295,-32).slice(2).join() === "0,-32,-1,31,-1,-1,4294967295"',
		'Object.is(calc(-6,3)[0],-0) && Object.is(calc(-0,7)[0],-0) && calc(7,Infinity)[0] === 7',
		'Number.isNaN(calc(1,NaN)[1]) && Number.isNaN(calc(-1,Infinity)[1]) && calc(NaN)[1] === 1',
		'Object.is(calc(-0,3)[1],-0) && calc(-0,-3)[1] === -Infinity && calc(-Infinity,0.5)[1] === Infinity',
		r'compare("\uD800\uDC00","\uE000").join() === "true,true,false,false"',
		r'compare("\u00FF","\u0100").join() === "true,true,false,false"',
		r'compare("\uD800","\uD800x").join() === "true,true,false,false"',
		'compare("", "").join() === "false,true,false,true"',
		'compare(NaN,1).join() === "false,false,false,false" && compare("12",2)[2]',
	] {
		for enabled in [false, true] {
			vm.use_native_code(enabled)!
			assert native_test_run(mut vm, source)!.to_boolean(), source
		}
	}
}

fn test_native_primitive_lowering_reuses_binary_and_keeps_dynamic_hooks() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	source := r'function calc(a=2,b=3){return a%b + (a<<b)} function key(k){return {[k]:`${k}`}} function spread({n}){return n} function flip(a){return ~a} calc();key("x");spread({n:1});flip(1)'
	for reopened in [false, true] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(cache, if reopened { '/usr/bin/false' } else { '/usr/bin/clang' })!
		native_test_run(mut vm, source)!
		stats := vm.flush_native_code_cache()!
		if reopened {
			assert stats.cache_hits == 5 && stats.cache_misses == 0 && stats.compiler_invocations == 0
			assert stats.compiled_instructions == 0 && stats.fast_instructions == 0
		} else {
			assert stats.fast_instructions > 0 && stats.compiled_instructions > stats.fast_instructions
		}
		vm.diagnose_native_code(true)!
		for source_check in [
			'calc()===18 && calc(9)===72 && calc(9,undefined)===72 && calc(7,2,99)===29',
			'var log="",a={valueOf(){log+="a";return 7}},b={valueOf(){log+="b";return 2}};calc(a,b)===29&&log==="abab"',
			'var log="",k={toString(){log+="k";return "x"}};key(k).x==="x"&&log==="kk"',
			'flip(2n)===-3n && (function(){try{calc(2n,1)}catch(e){return e instanceof TypeError}})()',
			'(function(){try{spread(null)}catch(e){return e instanceof TypeError}})()',
		] { assert native_test_run(mut vm, source_check)!.to_boolean(), source_check }
		activity := vm.diagnose_native_code(false)!
		assert activity.entries > 0 && activity.fast_steps > 0 && activity.slow_steps > 0
		vm.close_native_code()!
	}
}

fn test_native_argument_load_uses_the_live_frame_layout_and_budget() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	executable := &Executable{
		registers_and_locals_count: 6
		constants: [Value.from_i32(17), Value.from_i32(18)]
		instructions: [
			Instruction{op: .get_argument, dst: Operand.register(5), identifier: 1},
			Instruction{op: .end, lhs: Operand.register(5)},
		]
		bytecode_length: 2
	}
	for native in [false, true] {
		if native {
			stats := vm.compile_native_code(cache, '/usr/bin/clang', 1)!
			assert stats.fast_instructions == 2
			vm.diagnose_native_code(true)!
		}
		for count in 0 .. 4 {
			mut frame := ExecutionContext.create(6, executable.constants, u32(count))
			frame.realm = vm.realm()
			for index in 0 .. count { frame.set_argument(u32(index), Value.from_i32(i32(index + 40))) }
			vm.push_execution_context_checked(mut frame)!
			value := vm.run_executable(mut frame, executable, 0, ExecutionLimits{max_instructions: 2})!
			expected := if count < 2 { js_undefined() } else { Value.from_i32(41) }
			assert same_value(value, expected)
			vm.pop_execution_context()
		}
	}
	activity := vm.diagnose_native_code(false)!
	assert activity.entries == 4 && activity.fast_steps == 8 && activity.slow_steps == 0
}
