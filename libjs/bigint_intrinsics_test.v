// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand
import math.big
import platform

fn bigint_intrinsic_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'bigint-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_bigint_production_global_conversion_primitive_hints_and_errors() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert bigint_intrinsic_eval(mut vm, 'BigInt("9007199254740993123456789")===9007199254740993123456789n&&BigInt("0xff")===255n&&BigInt(true)===1n&&BigInt(-0)===0n&&BigInt(9007199254740992)===9007199254740992n&&BigInt(1n)===1n&&typeof BigInt("1")==="bigint"')!.as_bool()
	assert bigint_intrinsic_eval(mut vm, 'var hint="",n=BigInt({[Symbol.toPrimitive](h){hint=h;return "123"}}),errors=0;for(var call of [()=>BigInt(),()=>BigInt(null),()=>BigInt(Symbol()),()=>BigInt(1.5),()=>BigInt(Infinity),()=>BigInt(NaN),()=>BigInt("1.5"),()=>new BigInt(1)])try{call()}catch(e){if(e instanceof Error)errors++}n===123n&&hint==="number"&&errors===8')!.as_bool()
}

fn test_bigint_boxing_and_prototype_methods_use_real_native_slots() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert bigint_intrinsic_eval(mut vm, 'var b=Object(255n);Object.getPrototypeOf(b)===BigInt.prototype&&b.valueOf()===255n&&b.toString(16)==="ff"&&(255n).toString(2)==="11111111"&&Object.prototype.toString.call(b)==="[object BigInt]"&&Object.prototype.toString.call(1n)==="[object BigInt]"&&BigInt.length===1&&BigInt.prototype.toString.length===0')!.as_bool()
	assert bigint_intrinsic_eval(mut vm, 'var reads=0,count=0;for(var target of [BigInt.prototype,{},Object.create(Object(1n)),1])try{BigInt.prototype.toString.call(target,{valueOf(){reads++;return 16}})}catch(e){if(e instanceof TypeError)count++}count===4&&reads===0')!.as_bool()
}

fn test_bigint_width_methods_and_github_style_string_interpolation_are_exact() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert bigint_intrinsic_eval(mut vm, r'BigInt.asIntN(8,255n)===-1n&&BigInt.asUintN(8,-1n)===255n&&BigInt.asIntN(0,1n)===0n&&BigInt.asUintN(64,18446744073709551617n)===1n&&BigInt.asIntN.length===2&&BigInt.asUintN.length===2&&(function(v){return typeof v==="bigint"?`$bigint:${v}`:v})(900719925474099312345n)==="$bigint:900719925474099312345"')!.as_bool()
}

fn test_bigint_locale_formatting_retains_intrinsic_and_checks_brand_before_options() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert bigint_intrinsic_eval(mut vm, 'var n=123456789012345678901n,f=Intl.NumberFormat;Intl.NumberFormat=function(){throw 1};var ok=n.toLocaleString("en-US")==="123,456,789,012,345,678,901"&&Object(n).toLocaleString("de-DE")==="123.456.789.012.345.678.901";Intl.NumberFormat=f;var reads=0,bad=false;try{BigInt.prototype.toLocaleString.call({}, {get length(){reads++;throw 2}})}catch(e){bad=e instanceof TypeError}ok&&bad&&reads===0')!.as_bool()
}

fn test_bigint_cells_copy_temporary_magnitudes_and_wrappers_survive_arena_reset() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut arena := platform.new_arena('native BigInt arithmetic payload')
	entry := arena.enter()
	integer := big.integer_from_radix('900719925474099312345678901234567890', 10)!
	cell := BigInt.create(integer)
	wrapper := BigIntObject.create(vm.realm(), cell, vm.realm().bigint_prototype?)
	arena.leave(entry)
	assert !arena.contains(cell) && !arena.contains(wrapper) && !arena.contains(wrapper.object)
	arena.reset(); arena.release()
	assert cell.big_integer.str() == '900719925474099312345678901234567890'
	assert wrapper.bigint.big_integer.str() == cell.big_integer.str()
}

fn test_cached_bigint_native_constructors_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-bigint-intrinsic-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert bigint_intrinsic_eval(mut vm, r'function canonical(v){return typeof v==="bigint"?`$bigint:${v}`:v}canonical(BigInt("900719925474099312345"))==="$bigint:900719925474099312345"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
