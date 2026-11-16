module libjs

import os
import rand

fn binding_read_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'binding-reads.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_fast_global_binding_reads_observe_replacement_accessors_and_lexical_shadowing() {
	for enabled in [false, true] {
		set_fast_binding_reads_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		directory := os.join_path(os.temp_dir(), 'vox-bindings-' + rand.uuid_v4())
		defer { vm.close_native_code() or {}; os.rmdir_all(directory) or {} }
		assert binding_read_eval(mut vm, 'Object.defineProperty(globalThis,"liveBinding",{value:41,writable:true,configurable:true});function read(){return liveBinding}read()')!.number == 41
		vm.compile_native_code(directory, '/usr/bin/clang', 1)!
		vm.diagnose_native_code(true)!
		assert binding_read_eval(mut vm, 'liveBinding=42;read()')!.number == 42
		activity := vm.diagnose_native_code(false)!
		assert activity.entries > 0
		assert (activity.own_global_binding_reads > 0) == enabled
		assert (activity.empty_binding_environments_skipped > 0) == enabled
		assert binding_read_eval(mut vm, 'var seen=0;Object.defineProperty(globalThis,"liveBinding",{get(){seen++;return 43},configurable:true});read()===43&&seen===1')!.as_bool()
		assert binding_read_eval(mut vm, 'delete globalThis.liveBinding;var missing=false;try{read()}catch(e){missing=e instanceof ReferenceError}missing')!.as_bool()
		assert binding_read_eval(mut vm, 'let liveBinding=44;read()')!.number == 44
	}
	set_fast_binding_reads_for_testing(true)
}

fn test_fast_binding_reads_preserve_inherited_proxy_lookup_order_and_with_receivers() {
	mut logs := []string{}
	for enabled in [false, true] {
		set_fast_binding_reads_for_testing(enabled)
		mut vm := VM.create()
		mut frame := create_simple_execution_context(mut vm)
		assert binding_read_eval(mut vm, 'var trapLog="";var inherited=new Proxy({target:42},{has(t,k){trapLog+="h";return Reflect.has(t,k)},get(t,k,r){trapLog+="g";return Reflect.get(t,k,r)}});Object.setPrototypeOf(globalThis,inherited);function read(){return target}read()')!.number == 42
		logs << vm.global_object().get(mut vm, PropertyName.from_str('trapLog'))!.as_string().str()
		proxy := binding_read_eval(mut vm, 'new Proxy({target:43},{has(t,k){return Reflect.has(t,k)},get(t,k,r){return Reflect.get(t,k,r)}})')!.as_object()
		outer := frame.lexical_environment
		frame.lexical_environment = Environment(ObjectEnvironment.create(proxy, true, outer))
		value, receiver := vm.resolve_compact_read(utf16_string('target'), false, true, false)!
		assert value.number == 43 && voidptr(receiver.as_object()) == voidptr(proxy)
		frame.lexical_environment = outer
	}
	assert logs[0] == logs[1] && logs[0].contains('h') && logs[0].contains('g')
	set_fast_binding_reads_for_testing(true)
}

fn test_fast_global_binding_reads_leave_proxy_and_array_global_records_exotic() {
	mut logs := []string{}
	for enabled in [false, true] {
		set_fast_binding_reads_for_testing(enabled)
		mut vm := VM.create()
		mut frame := create_simple_execution_context(mut vm)
		original := frame.lexical_environment
		global := vm.global_object()
		proxy := binding_read_eval(mut vm, 'var ownTrapLog="";new Proxy({target:42},{has(t,k){ownTrapLog+="h";return Reflect.has(t,k)},get(t,k,r){ownTrapLog+="g";return Reflect.get(t,k,r)}})')!.as_object()
		frame.lexical_environment = Environment(GlobalEnvironment.create(proxy, proxy))
		value, receiver := vm.resolve_compact_read(utf16_string('target'), false, true, false)!
		assert value.number == 42 && receiver.is_undefined()
		logs << global.get(mut vm, PropertyName.from_str('ownTrapLog'))!.as_string().str()
		frame.lexical_environment = original
		array := binding_read_eval(mut vm, '[1,2]')!.as_object()
		frame.lexical_environment = Environment(GlobalEnvironment.create(array, array))
		length, _ := vm.resolve_compact_read(utf16_string('length'), true, false, false)!
		assert length.number == 2
		frame.lexical_environment = original
	}
	assert logs[0] == logs[1] && logs[0] == 'hg'
	set_fast_binding_reads_for_testing(true)
}
