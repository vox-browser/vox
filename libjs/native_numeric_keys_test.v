module libjs

import os
import rand

@[heap]
struct NumericKeyHost {
mut:
	keys []PropertyName
	value Value
}

fn (host &NumericKeyHost) own_property_keys() []PropertyName {
	return [PropertyName.from_number(0)]
}

fn (host &NumericKeyHost) get_own_property(key PropertyName) ?PropertyDescriptor {
	mut owner := unsafe { &NumericKeyHost(host) }
	owner.keys << key
	if !key.is_number() || key.number != 0 { return none }
	return PropertyDescriptor{value: owner.value, enumerable: true, configurable: false}
}

fn numeric_key_run(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'native-numeric-keys.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_native_numeric_keys_preserve_boundary_spelling_proxy_keys_and_getters() {
	set_native_indices_for_testing(false)
	defer {
		set_native_indices_for_testing(true)
		set_native_numeric_keys_for_testing(true)
	}
	cache := os.join_path(os.temp_dir(), 'vox-native-numeric-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	numeric_key_run(mut vm, 'function read(o,k){return o[k]}function safe(o,k){try{return read(o,k)}catch(e){return e}}read({0:42},0);safe({0:42},0)')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	mut counts := []NativeCodeActivity{}
	for enabled in [false, true] {
		set_native_numeric_keys_for_testing(enabled)
		vm.diagnose_native_code(true)!
		for source in [
			'var o={0:42,1:7,4294967294:8,"4294967295":9,"-1":10,"1.5":11,"NaN":12,"Infinity":13};read(o,-0)===42&&read(o,1)===7&&read(o,4294967294)===8&&read(o,4294967295)===9&&read(o,-1)===10&&read(o,1.5)===11&&read(o,NaN)===12&&read(o,Infinity)===13',
			'var log="";var p=new Proxy({0:42,4294967294:7},{get(t,k,r){log+=typeof k+":"+k+";";return Reflect.get(t,k,r)}});read(p,-0)===42&&read(p,4294967294)===7&&log==="string:0;string:4294967294;"',
			'var p={get 0(){return this.n}};var o=Object.create(p);o.n=42;read(o,0)===42',
			'var n=0;var o={get 0(){n++;return read({1:42},1)}};read(o,0)===42&&n===1',
			'safe({get 0(){throw 7}},0)===7',
			'var n=0;var key={toString(){n++;return "0"}};read({0:42},key)===42&&n===1&&(safe(null,key),n===1)',
			'var s=Symbol();var o={};o[s]=42;read(o,s)===42&&read({0:42},0n)===42',
			'read(new Uint8Array([42]),0)===42&&read(new String("abc"),1)==="b"&&read("abc",1)==="b"',
			'(function(x){return read(arguments,0)})(42)===42',
		] { assert numeric_key_run(mut vm, source)!.to_boolean(), source }
		activity := vm.diagnose_native_code(false)!
		assert (activity.native_numeric_key_reads > 0) == enabled
		counts << activity
	}
	assert counts[0].entries == counts[1].entries
	assert counts[0].fast_steps == counts[1].fast_steps
	assert counts[0].slow_steps == counts[1].slow_steps
	assert counts[0].direct_slow_steps == counts[1].direct_slow_steps
}

fn test_native_numeric_keys_preserve_exact_budget_and_fresh_vm_cache_reuse() {
	defer { set_native_numeric_keys_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-native-numeric-budget-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut results := [][]string{}
	for mode in 0 .. 3 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function read(o,k){return o[k]}function use(){try{return read({get 0(){return read({1:42},1)}},0)}finally{}}use()', vm.realm(), 'numeric-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 42
		stats := vm.compile_native_code(cache, if mode == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (mode != 0)
		vm.use_native_code(mode != 0)!
		set_native_numeric_keys_for_testing(mode == 2)
		mut samples := []string{}
		for budget in 1 .. 120 {
			if value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) {
				samples << value.str()
			} else {
				assert is_throw_completion(err)
				samples << thrown_value(err).as_object().error_message() or { '' }
			}
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
			assert vm.interpreter_stack().native_depth == 0 && !vm.instruction_budget_active
		}
		results << samples
		vm.close_native_code()!
	}
	assert results[0] == results[1] && results[1] == results[2]
}

fn test_native_numeric_keys_preserve_live_host_provider_override_and_order() {
	defer { set_native_numeric_keys_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-native-numeric-host-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut provider := &NumericKeyHost{value: Value.from_i32(42)}
	mut object := Object.create(vm.realm(), none)
	object.define_direct_property(PropertyName.from_number(0), Value.from_i32(1000), attribute_configurable)
	object.host_properties = HostProperties(provider)
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('numericHost'), Value.from_object(object), attribute_configurable)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	numeric_key_run(mut vm, 'function read(o,k){return o[k]}read(numericHost,0)')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	mut logs := [][]PropertyName{}
	for enabled in [false, true] {
		set_native_numeric_keys_for_testing(enabled)
		provider.keys = []PropertyName{}
		provider.value = Value.from_i32(42)
		vm.diagnose_native_code(true)!
		assert numeric_key_run(mut vm, 'read(numericHost,-0)')!.number == 42
		provider.value = Value.from_i32(43)
		assert numeric_key_run(mut vm, 'read(numericHost,0)')!.number == 43
		activity := vm.diagnose_native_code(false)!
		assert (activity.native_numeric_key_reads > 0) == enabled
		assert provider.keys.len > 0
		logs << provider.keys.clone()
	}
	assert logs[0].len == logs[1].len
	for index, key in logs[0] { assert key.equals(logs[1][index]) }
}
