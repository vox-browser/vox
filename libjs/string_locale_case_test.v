// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn string_locale_case_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'string-locale-case.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_string_locale_case_turkish_azerbaijani_lithuanian_and_greek_context() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert string_locale_case_eval(mut vm, '"iIİı".toLocaleUpperCase("tr")==="İIİI"&&"iIİı".toLocaleLowerCase("tr")==="iıiı"&&"I\u0307".toLocaleLowerCase("az")==="i"&&"I\u0301".toLocaleLowerCase("lt")==="i\u0307\u0301"&&"i\u0307".toLocaleUpperCase("lt")==="I"&&"Μαΐου".toLocaleUpperCase("el")==="ΜΑΪΟΥ"&&"ΟΣ".toLocaleLowerCase("en")==="ος"&&"ß".toLocaleUpperCase("de")==="SS"')!.as_bool()
}

fn test_string_locale_case_uses_only_first_language_and_realm_default() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert string_locale_case_eval(mut vm, '"i".toLocaleUpperCase(["zz-ZZ","tr"])==="I"&&"i".toLocaleUpperCase(["tr-TR","en"])==="İ"&&"i".toLocaleUpperCase(new Intl.Locale("tr"))==="İ"&&"I".toLocaleLowerCase("en-US-u-co-search")==="i"')!.as_bool()
	mut realm := unsafe { &Realm(vm.realm()) }; realm.intl_default_locale = 'tr-TR'
	assert string_locale_case_eval(mut vm, '"i".toLocaleUpperCase()==="İ"&&"I".toLocaleLowerCase([])==="ı"&&"i".toUpperCase()==="I"&&"I".toLowerCase()==="i"')!.as_bool()
}

fn test_string_locale_case_coerces_receiver_before_locale_list_even_for_unchanged_text() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert string_locale_case_eval(mut vm, 'var seen="",source={toString(){seen+="s";return "today"}},locales={get length(){seen+="l";return 1},get 0(){seen+="0";return "en"}};String.prototype.toLocaleUpperCase.call(source,locales)==="TODAY"&&seen==="sl0"&&(function(){var calls=0,marker={},same=false;try{"123".toLocaleUpperCase({get length(){calls++;throw marker}})}catch(e){same=e===marker}return same&&calls===1})()')!.as_bool()
	assert string_locale_case_eval(mut vm, 'var reads=0,bad=false;try{String.prototype.toLocaleLowerCase.call(null,{get length(){reads++;return 0}})}catch(e){bad=e instanceof TypeError}bad&&reads===0&&(function(){try{"ABC".toLocaleUpperCase(["en","not_a_tag"]);return false}catch(e){return e instanceof RangeError}})()')!.as_bool()
}

fn test_string_locale_case_preserves_utf16_surrogates_expansions_and_native_metadata() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert string_locale_case_eval(mut vm, '"\ud800ß\udfff".toLocaleUpperCase("en")==="\ud800SS\udfff"&&"𐐨".toLocaleUpperCase("en")==="𐐀"&&"İ".toLocaleLowerCase("en")==="i\u0307"&&String.prototype.toLocaleUpperCase.length===0&&String.prototype.toLocaleLowerCase.length===0&&!("prototype" in String.prototype.toLocaleUpperCase)')!.as_bool()
}

fn test_cached_string_locale_case_runs_without_compiler_on_revisit() {
	directory := os.join_path(os.temp_dir(), 'vox-locale-case-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert string_locale_case_eval(mut vm, 'function label(s,locale){return s.charAt(0).toLocaleUpperCase(locale)+s.slice(1)}label("today","en-US")==="Today"&&label("istanbul","tr")==="İstanbul"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
