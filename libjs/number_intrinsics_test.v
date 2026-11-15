// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn number_intrinsics_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'number-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_default_realm_numbers_use_native_number_slots_and_radix_formatting() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert number_intrinsics_eval(mut vm, 'Number()===0&&Number("42")===42&&Number(42n)===42&&Number.prototype.valueOf()===0&&Object.getPrototypeOf(Object(42))===Number.prototype&&Object.getPrototypeOf(new Number(42))===Number.prototype&&new Number(42).valueOf()===42')!.as_bool()
	assert number_intrinsics_eval(mut vm, '(65535).toString(16)==="ffff"&&(0.5).toString(2)==="0.1"&&(42).toString()==="42"&&(1.25).toFixed(1)==="1.3"&&(1).toFixed(2)==="1.00"')!.as_bool()
	assert number_intrinsics_eval(mut vm, 'class N extends Number{}var n=new N(42);n instanceof N&&n instanceof Number&&n.valueOf()===42&&Number.parseInt===parseInt&&Number.parseFloat===parseFloat&&Number.parseInt("ff",16)===255')!.as_bool()
}

fn test_number_predicates_do_not_coerce_and_standard_constants_are_immutable() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert number_intrinsics_eval(mut vm, 'var conversions=0,o={valueOf(){conversions++;return 1}};!Number.isFinite(o)&&!Number.isNaN(o)&&!Number.isInteger(o)&&!Number.isSafeInteger(o)&&conversions===0&&Number.isFinite(42)&&Number.isNaN(NaN)&&Number.isInteger(42)&&!Number.isInteger(42.5)&&Number.isSafeInteger(9007199254740991)&&!Number.isSafeInteger(9007199254740992)&&Number.EPSILON===2**-52&&Number.MAX_SAFE_INTEGER===9007199254740991')!.as_bool()
	assert number_intrinsics_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(Number,"EPSILON"),errors=0;for(var call of [()=>Number.prototype.valueOf.call({}),()=>Number.prototype.toString.call(Object.create(Number.prototype)),()=>Number( Symbol() ),()=>new Number(Symbol()),()=>{(1).toString(1)}])try{call()}catch(e){if(e instanceof TypeError||e instanceof RangeError)errors++}!d.writable&&!d.enumerable&&!d.configurable&&errors===5')!.as_bool()
}

fn test_cached_numeric_identifier_helpers_use_the_number_prototype_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-number-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert number_intrinsics_eval(mut vm, 'function hex(n){return Math.floor(n).toString(16)}hex(65535.5)==="ffff"&&Number.isFinite(42)&&new Number("42").valueOf()===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
