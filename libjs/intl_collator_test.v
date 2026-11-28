// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand
import platform

fn intl_collator_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'intl-collator.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_intl_collator_and_locale_compare_sort_github_style_names_and_entry_keys() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'var names=[{name:"vlib"},{name:"README.md"},{name:"examples"},{name:"cmd"}],entries=[["z","last"],["A","upper"],["a","lower"]];names.sort((a,b)=>a.name.localeCompare(b.name));entries.sort(([a],[b])=>a.localeCompare(b));names.map(x=>x.name).join(",")==="cmd,examples,README.md,vlib"&&entries.map(x=>x[1]).join(",")==="lower,upper,last"&&Intl.Collator("en-US").compare("é","f")<0')!.as_bool()
}

fn test_intl_collator_sensitivity_case_first_numeric_and_shifted_punctuation() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'new Intl.Collator("en-US",{sensitivity:"base"}).compare("é","E")===0&&new Intl.Collator("en-US",{sensitivity:"accent"}).compare("a","A")===0&&new Intl.Collator("en-US",{sensitivity:"case"}).compare("ä","a")===0&&new Intl.Collator("en-US",{caseFirst:"upper"}).compare("A","a")<0&&new Intl.Collator("en-US",{caseFirst:"lower"}).compare("a","A")<0&&"file2".localeCompare("file10","en-US",{numeric:true})<0&&"a-b".localeCompare("ab","en-US",{ignorePunctuation:true})===0')!.as_bool()
	assert intl_collator_eval(mut vm, 'var c=new Intl.Collator("en-US",{numeric:true});c.compare("9007199254740992","9007199254740993")<0&&c.compare("file002","file٢")===0&&c.compare("9".repeat(300),"1"+"0".repeat(300))<0&&c.compare("0","0000")===0')!.as_bool()
}

fn test_intl_collator_bound_compare_identity_brand_metadata_and_coercion_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'var c=new Intl.Collator("en-US"),f=c.compare,seen="";f===c.compare&&f.name===""&&f.length===2&&!("prototype" in f)&&f.call(null,{toString(){seen+="a";return "a"}},{toString(){seen+="b";return "b"}})<0&&seen==="ab"&&Object.prototype.toString.call(c)==="[object Intl.Collator]"&&Intl.Collator.supportedLocalesOf.length===1')!.as_bool()
	assert intl_collator_eval(mut vm, 'var reads=0,bad=false;try{Object.getOwnPropertyDescriptor(Intl.Collator.prototype,"compare").get.call({})}catch(e){bad=e instanceof TypeError}bad&&(function(){try{Intl.Collator.prototype.resolvedOptions.call({get locale(){reads++;return "en"}})}catch(e){return e instanceof TypeError&&reads===0}})()&&(function(){var marker={},reads=0;try{new Intl.Collator().compare({toString(){throw marker}},{toString(){reads++;return "x"}})}catch(e){return e===marker&&reads===0}})()')!.as_bool()
}

fn test_locale_compare_converts_both_strings_before_locales_and_options_even_when_equal() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'var seen="",left={toString(){seen+="s";return "a"}},right={toString(){seen+="t";return "b"}},locales={get length(){seen+="l";return 1},get 0(){seen+="0";return "en-US"}},options={get usage(){seen+="u";return "sort"}};String.prototype.localeCompare.call(left,right,locales,options)<0&&seen==="stl0u"&&(function(){var marker={};try{"same".localeCompare("same","en",{get sensitivity(){throw marker}})}catch(e){return e===marker}})()')!.as_bool()
	assert intl_collator_eval(mut vm, 'var reads=0,bad=false;try{String.prototype.localeCompare.call(null,{toString(){reads++;return "x"}})}catch(e){bad=e instanceof TypeError}bad&&reads===0&&(function(){try{"x".localeCompare(Symbol(),{get length(){reads++;return 0}})}catch(e){return e instanceof TypeError&&reads===0}})()&&String.prototype.localeCompare.call(12,3)<0&&String.prototype.localeCompare.length===1')!.as_bool()
}

fn test_intl_collator_options_are_read_once_in_spec_order_and_validate_types() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'var seen="",o=new Proxy({},{get(t,k,r){seen+=k+",";return Reflect.get(t,k,r)}});new Intl.Collator("en-US",o);seen==="usage,localeMatcher,collation,numeric,caseFirst,sensitivity,ignorePunctuation,"&&(function(){var errors=0;for(var o of [null,{usage:"bad"},{localeMatcher:"bad"},{collation:"bad_type"},{caseFirst:"UPPER"},{sensitivity:"bad"}])try{new Intl.Collator("en-US",o)}catch(e){if(e instanceof TypeError||e instanceof RangeError)errors++}return errors===6})()')!.as_bool()
	assert intl_collator_eval(mut vm, 'new Intl.Collator("en-US",{numeric:"false"}).resolvedOptions().numeric===true&&new Intl.Collator("en-US",{ignorePunctuation:1}).resolvedOptions().ignorePunctuation===true&&new Intl.Collator("en-US",{collation:"phonebk"}).resolvedOptions().collation==="default"')!.as_bool()
}

fn test_intl_collator_locale_negotiation_extensions_and_subclass_prototype() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'class C extends Intl.Collator{}var c=new C("en-US-u-kf-upper-kn"),o=c.resolvedOptions();c instanceof C&&o.locale==="en-US-u-kf-upper-kn"&&o.caseFirst==="upper"&&o.numeric===true&&o.collation==="default"&&new Intl.Collator("en-US-u-kf-upper-kn",{numeric:false,caseFirst:"lower"}).resolvedOptions().locale==="en-US"&&Intl.Collator.supportedLocalesOf(["en-us","de-DE","en-gb"]).join()==="en-US,en-GB"&&new Intl.Collator("de-DE").resolvedOptions().locale==="en-US"')!.as_bool()
	assert intl_collator_eval(mut vm, 'Object.keys(new Intl.Collator().resolvedOptions()).join(",")==="locale,usage,sensitivity,ignorePunctuation,collation,numeric,caseFirst"&&new Intl.Collator("en-US",{usage:"search"}).resolvedOptions().usage==="search"')!.as_bool()
}

fn test_locale_compare_retains_default_intrinsic_and_observes_realm_locale_changes() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'var c=Intl.Collator;Intl.Collator=function(){throw 1};var good="a".localeCompare("b")<0&&"a".localeCompare("b","en-US",{sensitivity:"base"})<0;Intl.Collator=c;good')!.as_bool()
	mut realm := unsafe { &Realm(vm.realm()) }
	first := realm.intl_default_collator?
	realm.intl_default_locale = 'en-GB'
	assert intl_collator_eval(mut vm, '"a".localeCompare("b")<0')!.as_bool()
	second := realm.intl_default_collator?
	assert voidptr(first) != voidptr(second) && second.locale == 'en-GB'
}

fn test_intl_collator_bound_compare_and_cached_default_survive_temporary_arena_reset() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut arena := platform.new_arena('native Collator and bound compare')
	entry := arena.enter()
	intl_collator_eval(mut vm, 'var collator=new Intl.Collator("en-US",{numeric:true}),compare=collator.compare;"a".localeCompare("b")')!
	arena.leave(entry)
	object := vm.global_object().get(mut vm, PropertyName.from_str('collator'))!.as_object()
	assert !arena.contains(object) && !arena.contains(object.slots.intl_collator?)
	assert !arena.contains(vm.realm().intl_default_collator?)
	bound := vm.global_object().get(mut vm, PropertyName.from_str('compare'))!.as_object()
	assert !arena.contains(bound)
	arena.reset(); arena.release()
	assert intl_collator_eval(mut vm, 'compare("file2","file10")<0&&collator.compare===compare&&"a".localeCompare("b")<0')!.as_bool()
}

fn test_intl_collator_native_normalization_work_obeys_the_vm_budget() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut script := Script.parse('("x"+"\u0301\u0327".repeat(4000)).localeCompare("z")', vm.realm(), 'collation-native-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 20000}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
}

fn test_locale_compare_preserves_escaped_lone_surrogates_through_native_bound_calls() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collator_eval(mut vm, 'var c=new Intl.Collator("en-US");c.compare("\\ud800","\\ud801")<0&&"\\ud800".localeCompare("\\ud801")<0&&c.compare("é","e\\u0301")===0')!.as_bool()
}

fn test_cached_github_style_locale_compare_executes_without_compiler_on_revisit() {
	directory := os.join_path(os.temp_dir(), 'vox-intl-collation-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert intl_collator_eval(mut vm, 'function names(values){return values.slice().sort((a,b)=>a.name.localeCompare(b.name)).map(x=>x.name).join(",")}names([{name:"vlib"},{name:"examples"},{name:"cmd"}])==="cmd,examples,vlib"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
