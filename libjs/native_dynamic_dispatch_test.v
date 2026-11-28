module libjs

import os
import rand

fn dynamic_test_cache() string { return os.join_path(os.temp_dir(), 'vox-dynamic-test-' + rand.uuid_v4()) }
fn dynamic_test_script(mut vm VM, source string) !&Script {
	return Script.parse(source, vm.realm(), 'dynamic-dispatch-test.js', unsafe { nil })
}
fn dynamic_test_run(mut vm VM, source string) !Value {
	mut script := dynamic_test_script(mut vm, source)!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_native_dynamic_handlers_share_conversion_throw_call_and_constructor_semantics() {
	cache := dynamic_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	dynamic_test_run(mut vm, 'function read(o,k){return o[k]} function invoke(o,f,a){return f.call(o,a)} function make(f,a){return new f(a)} function kind(){return typeof neverDeclared} function fail(o,k){try{return read(o,k)}catch(e){return e.message}} function C(a){this.x=a} read({x:1},"x");invoke({},function(a){return a},1);make(C,1);kind();fail({x:1},"x")')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	for enabled in [false, true] {
		set_native_dynamic_dispatch_for_testing(enabled)
		set_compact_reference_reads_for_testing(enabled)
		vm.diagnose_native_code(true)!
		for source in [
			'read("abc",1)==="b" && read("abc","length")===3',
			'var calls=0;var key={toString(){calls++;return "x"}};read({get x(){calls++;return 42}},key)===42&&calls===2',
			'var calls=0;var key={toString(){calls++;throw 7}};fail(null,key);calls===0',
			'fail({get x(){throw new Error("getter")}},"x")==="getter"',
			'invoke({x:40},function(a){return this.x+a},2)===42',
			'make(C,42).x===42 && kind()==="undefined"',
			'var held;invoke({},function(a){held=arguments;return a},42);held[0]===42',
		] { assert dynamic_test_run(mut vm, source)!.to_boolean(), source }
		activity := vm.diagnose_native_code(false)!
		assert activity.entries > 0 && activity.slow_steps > 0
		assert (activity.direct_slow_steps > 0) == enabled
		assert (activity.compact_reference_reads > 0) == enabled
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
	set_native_dynamic_dispatch_for_testing(true)
	set_compact_reference_reads_for_testing(true)
}

fn test_native_dynamic_handler_dispatch_keeps_exact_budget_and_unwinding() {
	cache := dynamic_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	mut script := dynamic_test_script(mut vm, 'function read(o){return o.x} function use(f,o){try{return f(o)}finally{}} use(read,{x:42})')!
	assert vm.run(mut script)!.number == 42
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	for budget in 1 .. 100 {
		mut results := []string{}
		for enabled in [false, true] {
			set_native_dynamic_dispatch_for_testing(enabled)
			value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) or {
				assert is_throw_completion(err)
				assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
				results << thrown_value(err).as_object().error_message() or { '' }
				continue
			}
			results << value.str()
		}
		assert results[0] == results[1], 'budget ${budget}: ${results}'
	}
	set_native_dynamic_dispatch_for_testing(true)
	set_compact_reference_reads_for_testing(true)
}

fn test_dynamic_dispatch_checks_actual_frame_storage_after_operand_layout_validation() {
	mut frame := ExecutionContext{values: [Value.from_i32(1)]}
	assert frame.checked_dispatch_value(0)!.number == 1
	frame.store_dispatch_value(0, Value.from_i32(42))!
	assert frame.values[0].number == 42
	for index in [u32(1), 0xffffffff] {
		if _ := frame.checked_dispatch_value(index) { assert false }
		if _ := frame.store_dispatch_value(index, js_undefined()) { assert false }
	}
	frame.values = []Value{}
	if _ := frame.checked_dispatch_value(0) { assert false }
	if _ := frame.store_dispatch_value(0, js_undefined()) { assert false }
}

fn test_compact_binding_reads_preserve_with_proxy_receiver_and_tdz() {
	mut vm := VM.create()
	mut frame := create_simple_execution_context(mut vm)
	outer := frame.lexical_environment
	global := vm.realm().global_object_record()
	proxy := dynamic_test_run(mut vm, 'var readLog="";var readTarget={x:42,f:function(){return this.x}};new Proxy(readTarget,{has(t,k){readLog+="h:"+(typeof k==="symbol"?"symbol":k)+";";return Reflect.has(t,k)},get(t,k,r){readLog+="g:"+(typeof k==="symbol"?"symbol":k)+";";return Reflect.get(t,k,r)}})')!.as_object()
	for with_environment in [false, true] {
		frame.lexical_environment = Environment(ObjectEnvironment.create(proxy, with_environment, outer))
		global.set(mut vm, PropertyName.from_str('readLog'), Value.from_string(vm.empty_string()), .yes)!
		reference := vm.resolve_binding(utf16_string('f'), false, none)!
		baseline := reference.get_value(mut vm)!
		baseline_log := global.get(mut vm, PropertyName.from_str('readLog'))!.as_string().str()
		global.set(mut vm, PropertyName.from_str('readLog'), Value.from_string(vm.empty_string()), .yes)!
		value, receiver := vm.resolve_compact_read(utf16_string('f'), false, true, false)!
		assert value.cell == baseline.cell
		assert global.get(mut vm, PropertyName.from_str('readLog'))!.as_string().str() == baseline_log
		assert receiver.is_object() == with_environment
		if with_environment { assert voidptr(receiver.as_object()) == voidptr(proxy) }
	}
	mut lexical := DeclarativeEnvironment.create(outer)
	lexical.create_mutable_binding(mut vm, utf16_string('late'), false)!
	frame.lexical_environment = Environment(lexical)
	if _, _ := vm.resolve_compact_read(utf16_string('late'), false, false, true) { assert false }
	else { assert thrown_value(err).as_object().error_kind()? == .reference_error }
	missing, receiver := vm.resolve_compact_read(utf16_string('missing'), false, false, true)!
	assert missing.is_undefined() && receiver.is_undefined()
	if _, _ := vm.resolve_compact_read(utf16_string('missing'), false, true, false) { assert false }
	else { assert thrown_value(err).as_object().error_kind()? == .reference_error }
	frame.lexical_environment = outer
}
