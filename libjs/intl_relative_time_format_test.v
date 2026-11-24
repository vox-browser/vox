// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand
import platform

fn intl_relative_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'intl-relative-time-format.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_intl_relative_time_format_numeric_always_auto_and_signed_zero() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_relative_eval(mut vm, 'var f=new Intl.RelativeTimeFormat("en-US"),a=new Intl.RelativeTimeFormat("en-US",{numeric:"auto"});f.format(-1,"day")==="1 day ago"&&f.format(2,"days")==="in 2 days"&&f.format(-0,"second")==="0 seconds ago"&&f.format(0,"second")==="in 0 seconds"&&a.format(-1,"day")==="yesterday"&&a.format(0,"day")==="today"&&a.format(1,"day")==="tomorrow"&&a.format(-0,"day")==="today"&&a.format(0,"second")==="now"')!.as_bool()
}

fn test_intl_relative_time_format_cldr_styles_and_non_english_plurals() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_relative_eval(mut vm, 'new Intl.RelativeTimeFormat("en-US",{style:"short"}).format(-2,"year")==="2 yr. ago"&&new Intl.RelativeTimeFormat("en-US",{style:"narrow"}).format(2,"day")==="in 2d"&&new Intl.RelativeTimeFormat("ru").format(-21,"day")==="21 день назад"&&new Intl.RelativeTimeFormat("ru").format(-22,"day")==="22 дня назад"&&new Intl.RelativeTimeFormat("ru").format(-12,"day")==="12 дней назад"&&new Intl.RelativeTimeFormat("fr",{numeric:"auto"}).format(-2,"day")==="avant-hier"')!.as_bool()
}

fn test_intl_relative_time_format_number_parts_have_units_and_auto_literals_do_not() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_relative_eval(mut vm, 'var f=new Intl.RelativeTimeFormat("en-US"),p=f.formatToParts(-1234.5,"days");p.map(x=>x.value).join("")===f.format(-1234.5,"days")&&p.map(x=>x.type).join(",")==="integer,group,integer,decimal,fraction,literal"&&p.filter(x=>x.type!=="literal").every(x=>x.unit==="day")&&!p[p.length-1].hasOwnProperty("unit")&&(function(){var a=new Intl.RelativeTimeFormat("en-US",{numeric:"auto"}).formatToParts(-1,"day");return a.length===1&&a[0].type==="literal"&&a[0].value==="yesterday"&&!a[0].hasOwnProperty("unit")})()')!.as_bool()
}

fn test_intl_relative_time_format_conversions_brand_checks_and_abrupt_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_relative_eval(mut vm, 'var f=new Intl.RelativeTimeFormat("en-US"),seen="",marker={},same=false;try{f.format(NaN,{toString(){seen+="u";throw marker}})}catch(e){same=e===marker}same&&seen==="u"&&(function(){var reads=0;try{Intl.RelativeTimeFormat.prototype.format.call({}, {valueOf(){reads++;return 1}},"day")}catch(e){return e instanceof TypeError&&reads===0}})()&&(function(){var seen="";return f.format({valueOf(){seen+="v";return -1}},{toString(){seen+="u";return "days"}})==="1 day ago"&&seen==="vu"})()')!.as_bool()
	assert intl_relative_eval(mut vm, 'var f=new Intl.RelativeTimeFormat(),count=0;for(var v of [NaN,Infinity,-Infinity])try{f.format(v,"day")}catch(e){if(e instanceof RangeError)count++}for(var u of ["DAY","fortnight","dayss",undefined])try{f.format(1,u)}catch(e){if(e instanceof RangeError)count++}count===7&&(function(){try{f.format(1n,"day");return false}catch(e){return e instanceof TypeError}})()')!.as_bool()
}

fn test_intl_relative_time_format_options_subclasses_and_intrinsic_number_formatter() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_relative_eval(mut vm, 'class R extends Intl.RelativeTimeFormat{}var f=new R("en-US-u-nu-arab"),o=f.resolvedOptions();f instanceof R&&o.numberingSystem==="arab"&&o.locale==="en-US-u-nu-arab"&&f.format(-12,"day")==="١٢ days ago"&&Intl.RelativeTimeFormat.supportedLocalesOf(["en-us","zz-ZZ"]).join()==="en-US"&&Object.prototype.toString.call(f)==="[object Intl.RelativeTimeFormat]"&&Intl.RelativeTimeFormat.prototype.format.length===2')!.as_bool()
	assert intl_relative_eval(mut vm, 'var ctor=Intl.NumberFormat;Intl.NumberFormat=function(){throw 1};var result=new Intl.RelativeTimeFormat("en-US").format(-1,"day");Intl.NumberFormat=ctor;result==="1 day ago"&&(function(){try{Intl.RelativeTimeFormat();return false}catch(e){return e instanceof TypeError}})()')!.as_bool()
}

fn test_intl_relative_time_formatter_retention_across_temporary_arena_reset() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut arena := platform.new_arena('native relative time formatter')
	entry := arena.enter()
	intl_relative_eval(mut vm, 'var relative=new Intl.RelativeTimeFormat("en-US",{numeric:"auto"})')!
	arena.leave(entry)
	value := vm.global_object().get(mut vm, PropertyName.from_str('relative'))!
	assert !arena.contains(value.as_object()) && !arena.contains(value.as_object().slots.intl_relative_time_format?)
	arena.reset(); arena.release()
	assert intl_relative_eval(mut vm, 'relative.format(-1,"day")==="yesterday"&&relative.format(-2,"day")==="2 days ago"')!.as_bool()
}

fn test_cached_relative_time_formatter_executes_without_compiler_on_revisit() {
	directory := os.join_path(os.temp_dir(), 'vox-intl-relative-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert intl_relative_eval(mut vm, 'function relative(n){return new Intl.RelativeTimeFormat("en-US",{numeric:"auto"}).format(n,"day")}relative(-1)==="yesterday"&&relative(-2)==="2 days ago"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
