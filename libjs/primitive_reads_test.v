module libjs

import os
import rand

fn primitive_reads_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'primitive-reads.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_direct_primitive_reads_preserve_virtual_properties_methods_and_receiver() {
	defer { set_primitive_reads_for_testing(true) }
	for enabled in [false, true] {
		set_primitive_reads_for_testing(enabled)
		for source in [
			'"abc".length===3&&"abc"[1]==="b"&&"abc".split("").join("")==="abc"',
			'Object.defineProperty(String.prototype,"probe",{get:function(){"use strict";return typeof this+":"+this}});"abc".probe==="string:abc"',
			'Object.defineProperty(Number.prototype,"probe",{get:function(){"use strict";return typeof this+":"+this}});(42).probe==="number:42"',
			'Object.defineProperty(Boolean.prototype,"probe",{get:function(){"use strict";return this===true}});true.probe',
			'Object.defineProperty(Symbol.prototype,"probe",{get:function(){"use strict";return typeof this==="symbol"}});Symbol("x").probe',
			'Object.defineProperty(BigInt.prototype,"probe",{get:function(){"use strict";return this===42n}});(42n).probe',
			'Object.defineProperty(String.prototype,"probe",{get:function(){return typeof this==="object"&&this.valueOf()==="x"}});"x".probe',
			'String.prototype[9]=42;"abc"[9]===42&&"abc"[0]==="a"',
			'Object.setPrototypeOf(String.prototype,new Proxy({probe:42},{get(t,k,r){return typeof r==="string"?Reflect.get(t,k,r):0}}));"x".probe===42',
			'var marker={};Object.defineProperty(String.prototype,"probe",{get(){throw marker}});var caught=false;try{"x".probe}catch(e){caught=e===marker}caught',
		] {
			assert primitive_reads_eval(source)!.as_bool(), source
		}
	}
}

fn test_primitive_read_diagnostics_prove_wrapper_elision() {
	defer { set_primitive_reads_for_testing(true) }
	for enabled in [false, true] {
		set_primitive_reads_for_testing(enabled)
		diagnose_primitive_reads_for_testing(true)
		assert primitive_reads_eval('"a b".split(" ").join("-")==="a-b"')!.as_bool()
		activity := diagnose_primitive_reads_for_testing(false)
		if enabled {
			assert activity.direct > 0 && activity.boxed == 0
		} else {
			assert activity.boxed > 0 && activity.direct == 0
		}
	}
}

fn test_primitive_reference_preserves_explicit_receiver_and_running_realm() {
	mut vm := VM.create()
	local := create_simple_execution_context(mut vm)
	local_parent := vm.realm().string_prototype or { panic('String prototype') }
	mut parent := local_parent
	parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('probe'), fn (mut vm VM) !Value {
		return vm.this_value()
	}, unsafe { nil }, 0, none)
	text := Value.from_string(vm.create_string_from_str('x'))
	override := Value.from_object(Object.create(vm.realm(), none))
	assert same_value(Reference.for_value(text, PropertyName.from_str('probe'), override, false).get_value(mut vm)!, override)
	foreign := create_simple_execution_context(mut vm)
	assert voidptr(local.realm?) != voidptr(foreign.realm?)
	assert Reference.for_value(text, PropertyName.from_str('probe'), none, false).get_value(mut vm)!.is_undefined()
	vm.pop_execution_context()
	assert same_value(Reference.for_value(text, PropertyName.from_str('probe'), none, false).get_value(mut vm)!, text)
}

fn test_native_cache_reuses_primitive_reads_with_fresh_realms_and_no_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-primitive-reads-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		diagnose_primitive_reads_for_testing(true)
		mut script := Script.parse('function f(s){return s.split(" ").join("-")}f("a b")', vm.realm(), 'primitive-native.js', unsafe { nil })!
		assert vm.run(mut script)!.as_string().str() == 'a-b'
		activity := diagnose_primitive_reads_for_testing(false)
		assert activity.direct > 0 && activity.boxed == 0
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.compiler_invocations == 0 && stats.cache_misses == 0 && stats.cache_hits == 2
		}
		vm.close_native_code()!
	}
}

fn test_internal_values_keep_the_general_reference_error_path() {
	defer { set_primitive_reads_for_testing(true) }
	for enabled in [false, true] {
		set_primitive_reads_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		for value in [Value.from_accessor(Accessor.create(none, none, none)), js_special_empty_value()] {
			if _ := Reference.for_value(value, PropertyName.from_str('x'), none, false).get_value(mut vm) {
				assert false
			} else {
				assert is_throw_completion(err) && thrown_value(err).as_object().error_kind()? == .internal_error
			}
		}
	}
}
