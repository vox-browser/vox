// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn intl_list_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'intl-list-format.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_intl_list_format_cldr_types_styles_and_empty_iterables() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_list_eval(mut vm, 'var f=new Intl.ListFormat("en-US");f.format(["a","b","c"])==="a, b, and c"&&f.format("abc")==="a, b, and c"&&f.format(["a","b"])==="a and b"&&f.format(["a"])==="a"&&f.format([])===""&&f.format() === ""&&f.formatToParts().length===0&&Object.prototype.toString.call(f)==="[object Intl.ListFormat]"')!.as_bool()
	assert intl_list_eval(mut vm, 'new Intl.ListFormat("en-US",{style:"short"}).format(["a","b"])==="a & b"&&new Intl.ListFormat("en-US",{style:"narrow"}).format(["a","b"])==="a, b"&&new Intl.ListFormat("en-US",{type:"disjunction"}).format(["a","b","c"])==="a, b, or c"&&new Intl.ListFormat("en-US",{type:"unit",style:"narrow"}).format(["1h","2m"])==="1h 2m"')!.as_bool()
}

fn test_intl_list_format_parts_preserve_utf16_and_original_element_positions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_list_eval(mut vm, r'var f=new Intl.ListFormat("en-US"),list=["\\ud800","😀","\\udc00"],p=f.formatToParts(list);p.map(x=>x.value).join("")===f.format(list)&&p.map(x=>x.type).join()==="element,literal,element,literal,element"&&p[0].value===list[0]&&p[2].value===list[1]&&p[4].value===list[2]&&Object.getPrototypeOf(p[0])===Object.prototype')!.as_bool()
	assert intl_list_eval(mut vm, 'var f=new Intl.ListFormat("en-US"),p=f.formatToParts(["",""]);p.length===3&&p[0].type==="element"&&p[0].value===""&&p[1].value===" and "&&p[2].type==="element"&&p[2].value===""')!.as_bool()
}

fn test_intl_list_format_iterator_type_errors_close_without_coercion_and_keep_original_completion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_list_eval(mut vm, 'var f=new Intl.ListFormat("en-US"),closed=0,reads=0,coerced=0,marker={},bad={toString(){coerced++;throw marker}},iterable={[Symbol.iterator](){return {next(){reads++;return {value:bad,done:false}},return(){closed++;throw marker}}}},caught=false;try{f.format(iterable)}catch(e){caught=e instanceof TypeError}caught&&closed===1&&reads===1&&coerced===0')!.as_bool()
	assert intl_list_eval(mut vm, 'var marker={},closed=0,same=false,list={[Symbol.iterator](){return {next(){return {done:false,get value(){throw marker}}},return(){closed++;return {}}}}};try{new Intl.ListFormat().format(list)}catch(e){same=e===marker}same&&closed===0')!.as_bool()
}

fn test_intl_list_format_contextual_spanish_and_hebrew_conjunctions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_list_eval(mut vm, 'var f=new Intl.ListFormat("es"),o=new Intl.ListFormat("es",{type:"disjunction"});f.format(["tos","hipo"])==="tos e hipo"&&f.format(["agua","hielo"])==="agua y hielo"&&f.format(["x","Italia"])==="x e Italia"&&o.format(["10","11"])==="10 u 11"&&o.format(["10","111"])==="10 o 111"')!.as_bool()
	assert intl_list_eval(mut vm, 'var f=new Intl.ListFormat("he");f.format(["א","A"])==="א ו-A"&&f.format(["א","ב"])==="א וב"')!.as_bool()
}

fn test_intl_list_format_options_branding_and_locale_negotiation() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_list_eval(mut vm, 'var seen="",options=new Proxy({type:"unit",style:"short"},{get(t,k,r){seen+=k+",";return Reflect.get(t,k,r)}}),f=new Intl.ListFormat("en-US-u-nu-arab",options),r=f.resolvedOptions();seen==="localeMatcher,type,style,"&&r.locale==="en-US"&&r.type==="unit"&&r.style==="short"&&Intl.ListFormat.supportedLocalesOf(["en-us","zz-ZZ"]).join()==="en-US"')!.as_bool()
	assert intl_list_eval(mut vm, 'var errors=0;for(var f of [()=>Intl.ListFormat(),()=>new Intl.ListFormat("en",null),()=>new Intl.ListFormat("en",1),()=>new Intl.ListFormat("en",{type:"bad"}),()=>Intl.ListFormat.prototype.format.call({},[]),()=>Intl.ListFormat.prototype.formatToParts.call({},[]),()=>new Intl.ListFormat().format([1])])try{f()}catch(e){if(e instanceof Error)errors++}errors===7&&Intl.ListFormat.length===0&&Intl.ListFormat.prototype.format.length===1')!.as_bool()
}

fn test_intl_list_format_large_lists_use_an_iterative_partition_and_shared_budget() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_list_eval(mut vm, 'var values=Array.from({length:1000},(_,i)=>"v"+i),f=new Intl.ListFormat("en-US"),text=f.format(values);text.startsWith("v0, v1,")&&text.endsWith(", and v999")&&f.formatToParts(values).filter(x=>x.type==="element").length===1000')!.as_bool()
	mut script := Script.parse('new Intl.ListFormat("en-US").format({[Symbol.iterator](){return {next(){return {done:false,value:"x"}}}}})', vm.realm(), 'intl-list-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 1000}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
}

fn test_cached_intl_list_formatter_executes_without_compiler_after_revisit() {
	directory := os.join_path(os.temp_dir(), 'vox-intl-list-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert intl_list_eval(mut vm, 'function label(values){return new Intl.ListFormat("en-US").formatToParts(values).map(x=>x.value).join("")}label(["a","b","c"])==="a, b, and c"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
