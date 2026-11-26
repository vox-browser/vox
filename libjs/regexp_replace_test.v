// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn regexp_replace_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-replace.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_regexp_replacement_uses_actual_pattern_captures_and_substitution_tokens() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert regexp_replace_eval(mut vm, '"one two one".replace(/one/g,"three")==="three two three"&&"abc".replace(/(b)/,"[$1][$&][$$][$`][$\x27]")==="a[b][b][$][a][c]c"&&"x".replace(/(?<part>x)/,"$<part>!")==="x!"&&"ab".replace(/(x)?b/,"$1!")==="a!"')!.as_bool()
	assert regexp_replace_eval(mut vm, '"abc".replace(/z/,"x")==="abc"&&"😀".replace(/(?:)/gu,"_")==="_😀_"&&"ab".replace(/(?:)/g,"_")==="_a_b_"')!.as_bool()
	assert regexp_replace_eval(mut vm, 'var re=/a/g;re.lastIndex=99;"aa".replace(re,"b")==="bb"&&re.lastIndex===0')!.as_bool()
}

fn test_regexp_functional_replacement_collects_matches_before_callbacks_and_preserves_groups() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert regexp_replace_eval(mut vm, 'var order="",re=/a/g,native=re.exec;re.exec=function(s){order+="e";return native.call(this,s)};var result="aba".replace(re,function(m,index,text){"use strict";if(this!==undefined||m!=="a"||text!=="aba")throw 1;order+="r";return index});result==="0b2"&&order==="eeerr"')!.as_bool()
	assert regexp_replace_eval(mut vm, 'var seen=false;"ab".replace(/(?<first>a)(x)?/,function(m,a,x,index,text,groups){seen=m==="a"&&a==="a"&&x===undefined&&index===0&&text==="ab"&&groups.first==="a";return "X"})==="Xb"&&seen')!.as_bool()
}

fn test_regexp_replace_observes_generic_exec_getters_flags_and_backwards_positions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert regexp_replace_eval(mut vm, 'var order="",calls=0,rx={get flags(){order+="f";return "g"},exec(){order+="e";return calls++===0?{0:"a",index:0,length:1}:null}},replacement={toString(){order+="s";return "X"}};RegExp.prototype[Symbol.replace].call(rx,"abc",replacement)==="Xbc"&&order==="sfee"&&rx.lastIndex===0')!.as_bool()
	assert regexp_replace_eval(mut vm, 'var calls=0,replaced=0,rx={flags:"g",exec(){return calls++===0?{0:"b",index:1,length:1}:calls===2?{0:"a",index:0,length:1}:null}};RegExp.prototype[Symbol.replace].call(rx,"abc",()=>{replaced++;return "X"})==="aXc"&&replaced===2')!.as_bool()
}

fn test_regexp_replace_preserves_conversion_and_callback_exceptions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert regexp_replace_eval(mut vm, 'var marker={},same=0;for(var call of [()=>"a".replace(/a/,{toString(){throw marker}}),()=>"a".replace(/a/,()=>{throw marker}),()=>RegExp.prototype[Symbol.replace].call({get flags(){throw marker}},"a","")])try{call()}catch(e){if(e===marker)same++}var type=false;try{RegExp.prototype[Symbol.replace].call({},"a","")}catch(e){type=e instanceof TypeError}same===3&&type&&"a".replace(/a/,"b")==="b"')!.as_bool()
}

fn test_cached_turbo_style_regexp_replacement_runs_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-regexp-replace-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert regexp_replace_eval(mut vm, 'function css(s){return s.replace(/^\\n/,"").replace(/\\n/g,"")}css("\\nbody{\\ncolor:red}")==="body{color:red}"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
