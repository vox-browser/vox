// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn intl_locale_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'intl-locale.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_intl_canonical_locale_lists_use_checked_presence_before_coercion_and_dedupe() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_locale_eval(mut vm, 'var log="",list=new Proxy({0:"iw-il",2:"HE-IL",length:3},{has(t,k){log+="h"+k+";";return Reflect.has(t,k)},get(t,k,r){log+="g"+k+";";return Reflect.get(t,k,r)}});Intl.getCanonicalLocales(list).join() === "he-IL"&&log==="glength;h0;g0;h1;h2;g2;"&&Intl.getCanonicalLocales(42).length===0&&Intl.getCanonicalLocales().length===0')!.as_bool()
	assert intl_locale_eval(mut vm, 'var marker={},same=false;try{Intl.getCanonicalLocales([{toString(){throw marker}}])}catch(e){same=e===marker}var errors=0;for(var value of [null,[1],["en_US"],["en-a-abc-a-def"]])try{Intl.getCanonicalLocales(value)}catch(e){if(e instanceof Error)errors++}same&&errors===4')!.as_bool()
}

fn test_intl_locale_brand_keywords_aliases_and_original_locale_slots() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_locale_eval(mut vm, 'var l=new Intl.Locale("IW-il-u-nu-latn",{calendar:"gregory",hourCycle:"h23",numeric:true});l instanceof Intl.Locale&&l.toString()==="he-IL-u-ca-gregory-hc-h23-kn-nu-latn"&&l.baseName==="he-IL"&&l.language==="he"&&l.region==="IL"&&l.script===undefined&&l.calendar==="gregory"&&l.hourCycle==="h23"&&l.numeric&&l.numberingSystem==="latn"&&Object.prototype.toString.call(l)==="[object Intl.Locale]"')!.as_bool()
	assert intl_locale_eval(mut vm, 'var l=new Intl.Locale("en-US");l.toString=function(){throw 42};Intl.getCanonicalLocales(l)[0]==="en-US"&&new Intl.Locale(l).toString()==="en-US"&&Intl.Locale.length===1&&Intl.getCanonicalLocales.length===1')!.as_bool()
}

fn test_intl_locale_options_order_and_constructor_prototype_are_observable() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_locale_eval(mut vm, 'var log="",options=new Proxy({language:"sr",script:"Latn",region:"RS",numeric:false},{get(t,k,r){log+=k+",";return Reflect.get(t,k,r)}}),l=new Intl.Locale("en-US",options);l.toString()==="sr-Latn-RS-u-kn-false"&&log==="language,script,region,variants,calendar,collation,firstDayOfWeek,hourCycle,caseFirst,numeric,numberingSystem,"')!.as_bool()
	assert intl_locale_eval(mut vm, 'var errors=0;for(var f of [()=>Intl.Locale("en"),()=>new Intl.Locale(1),()=>new Intl.Locale("en",null),()=>Intl.Locale.prototype.toString.call({}),()=>new Intl.Locale("en",{region:"UnitedStates"}),()=>new Intl.Locale("en",{variants:"1901-1901"})])try{f()}catch(e){if(e instanceof Error)errors++}class L extends Intl.Locale{}var l=new L("en");errors===6&&l instanceof L&&l.toString()==="en"')!.as_bool()
}

fn test_intl_locale_maximize_minimize_preserve_extensions_and_return_new_intrinsics() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_locale_eval(mut vm, 'var l=new Intl.Locale("zh-TW-u-nu-hanidec"),max=l.maximize(),min=max.minimize();max!==l&&max.toString()==="zh-Hant-TW-u-nu-hanidec"&&min.toString()==="zh-TW-u-nu-hanidec"&&new Intl.Locale("en").maximize().toString()==="en-Latn-US"&&new Intl.Locale("en-Latn-US").minimize().toString()==="en"')!.as_bool()
}

fn test_cached_intl_locale_calls_execute_native_code_on_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-intl-locale-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert intl_locale_eval(mut vm, 'function locale(text){return new Intl.Locale(text).toString()}locale("EN-us")==="en-US"&&Intl.getCanonicalLocales(["iw-IL","he-IL"]).length===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
