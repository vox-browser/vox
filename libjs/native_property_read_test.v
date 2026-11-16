module libjs

import os
import rand

fn property_native_run(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'native-property.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_native_property_plans_keep_live_keys_receivers_exotics_and_unwinding() {
	defer { set_native_property_reads_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-property-native-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	property_native_run(mut vm, 'function read(o,k){return o[k]}function fail(o,k){try{return read(o,k)}catch(e){return e}finally{done++}}var done=0;read({x:1},"x");fail({x:1},"x")')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	mut activities := []NativeCodeActivity{}
	for enabled in [false, true] {
		set_native_property_reads_for_testing(enabled)
		vm.diagnose_native_code(true)!
		for source in [
			'var o={x:1};read(o,"x")===1&&(o.x=42,read(o,"x")===42)',
			'var p={get x(){return this.y}};var o=Object.create(p);o.y=42;read(o,"x")===42',
			'var s=Symbol();var o={};o[s]=42;read(o,s)===42',
			'var log="";var key={toString(){log+="k";return "x"}};var o={get x(){log+="g";return 42}};read(o,key)===42&&log==="kg"',
			'var n=0;var key={toString(){n++;throw 7}};fail(null,key);n===0&&fail({},key)===7&&n===1',
			'var before=done;fail({get x(){throw 42}},"x")===42&&done===before+1',
			'var o={x:42};var p=new Proxy(o,{get(t,k,r){return Reflect.get(t,k,r)}});read(p,"x")===42',
			'read("😀x",0)==="\\ud83d"&&read("abc","length")===3&&read([1,42],1)===42',
			'var a=new Uint8Array(2);a[1]=42;read(a,1)===42',
			'var o={get x(){return read({y:42},"y")}};read(o,"x")===42',
		] { assert property_native_run(mut vm, source)!.to_boolean(), source }
		activity := vm.diagnose_native_code(false)!
		assert (activity.specialized_property_steps > 0) == enabled
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
		assert vm.interpreter_stack().native_depth == 0
		activities << activity
	}
	assert activities[0].fast_steps == activities[1].fast_steps
	assert activities[0].slow_steps == activities[1].slow_steps
	assert activities[0].direct_slow_steps == activities[1].direct_slow_steps
}

fn test_native_property_plan_preserves_exact_budget() {
	defer { set_native_property_reads_for_testing(true) }
	mut results_by_mode := [][]string{}
	for mode in 0 .. 3 {
		set_native_property_reads_for_testing(mode == 2)
		cache := os.join_path(os.temp_dir(), 'vox-property-budget-' + rand.uuid_v4())
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function read(o,k){return o[k]}function use(o){try{return read(o,"x")}finally{}}use({get x(){return read({y:42},"y")}})', vm.realm(), 'property-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 42
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		vm.use_native_code(mode != 0)!
		mut results := []string{}
		for budget in 1 .. 120 {
			if value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) {
				results << value.str()
			} else {
				assert is_throw_completion(err)
				results << thrown_value(err).as_object().error_message() or { '' }
			}
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
			assert vm.interpreter_stack().native_depth == 0 && !vm.instruction_budget_active
		}
		results_by_mode << results
		vm.close_native_code()!
		os.rmdir_all(cache)!
	}
	assert results_by_mode[0] == results_by_mode[1] && results_by_mode[1] == results_by_mode[2]
}

fn test_native_property_plan_rejects_argument_and_invalid_write_slots() {
	executable := &Executable{registers_and_locals_count: 8, constants: [Value.from_i32(1)]}
	valid := Instruction{op: .get_property, lhs: Operand.register(1), rhs: Operand.constant(0), dst: Operand.register(2)}
	assert native_property_plan(valid, executable, 0)? != ''
	for instruction in [
		Instruction{...valid, lhs: Operand.argument(0)},
		Instruction{...valid, dst: Operand.constant(0)},
		Instruction{...valid, lhs: Operand.register(8)},
	] {
		if _ := native_property_plan(instruction, executable, 0) { assert false }
	}
}

fn test_native_property_library_reopens_with_current_vm_and_no_compiler() {
	cache := os.join_path(os.temp_dir(), 'vox-property-reopen-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	for index in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		assert property_native_run(mut vm, 'function read(o){return o.x}read({x:42})')!.number == 42
		stats := vm.compile_native_code(cache, if index == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (index == 1)
		vm.diagnose_native_code(true)!
		assert property_native_run(mut vm, 'read({x:"realm-' + index.str() + '"})')!.as_string().str() == 'realm-${index}'
		assert vm.diagnose_native_code(false)!.specialized_property_steps > 0
		assert vm.interpreter_stack().native_calls[0].property_read_step == unsafe { nil }
		vm.close_native_code()!
	}
}

fn test_native_property_plan_checks_live_storage_and_post_getter_destination() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut executable := &Executable{
		registers_and_locals_count: 8
		instructions: [Instruction{op: .get_property, lhs: Operand.register(4), rhs: Operand.register(5), dst: Operand.register(6)}]
		bytecode_length: 1
	}
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('x'), fn [mut executable] (mut vm VM) !Value {
		executable.instructions[0] = Instruction{...executable.instructions[0], dst: Operand.register(7)}
		return Value.from_i32(42)
	}, unsafe { nil }, attribute_configurable, none)
	mut frame := ExecutionContext.create(8, []Value{}, 0)
	frame.realm = vm.realm()
	frame.executable = executable
	frame.values[4] = Value.from_object(object)
	frame.values[5] = Value.from_string(vm.create_string_from_str('x'))
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	mut invocation := NativeInvocation{vm: vm, executable: executable}
	plan := [u32(0), 4, 5, 6, Operand.register(4).raw, Operand.register(5).raw, Operand.register(6).raw, 8, 0, 0, 0]
	assert native_property_step(voidptr(&invocation), plan.data) == 1
	assert frame.values[7].number == 42
	assert frame.values[6].is_undefined()
	// A changed raw destination must use the generic handler before charging.
	frame.values[7] = Value{}
	assert native_property_step(voidptr(&invocation), plan.data) == 1
	assert frame.values[7].number == 42
	// Layout-valid operands still require actual backing storage checks.
	frame.values = []Value{len: 4, init: Value{}}
	assert native_property_step(voidptr(&invocation), plan.data) == 0xffffffff
	assert invocation.failure?.msg().contains('frame value index')
	invocation.failure = none
	frame.values = []Value{len: 8, init: js_special_empty_value()}
	assert native_property_step(voidptr(&invocation), plan.data) == 0xffffffff
	assert thrown_value(invocation.failure?).as_object().error_message()?.contains('uninitialized operand')
}
