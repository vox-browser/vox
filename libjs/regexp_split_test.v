// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn regexp_split_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-split.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_regexp_split_handles_regex_separators_captures_limits_and_original_state() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_split_eval(mut vm, 'var r=/[,;]+/g;r.lastIndex=17;"a,,b;c".split(r).join(":")==="a:b:c"&&r.lastIndex===17&&"a,b,c".split(/,/,2).join(":")==="a:b"&&"a,b".split(/,/,0).length===0')!.as_bool()
	assert regexp_split_eval(mut vm, 'var a="a-b".split(/(-)/);a.length===3&&a[0]==="a"&&a[1]==="-"&&a[2]==="b"')!.as_bool()
	assert regexp_split_eval(mut vm, 'var a="ab".split(/(x)?b/);a.length===3&&a[0]==="a"&&a[1]===undefined&&a[2]===""')!.as_bool()
}

fn test_regexp_split_empty_matches_advance_with_unicode_and_keep_empty_input_semantics() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_split_eval(mut vm, '"".split(/(?:)/).length===0&&"".split(/x/).length===1&&"".split(/x/)[0]===""&&"ab".split(/(?:)/).join(":")==="a:b"')!.as_bool()
	assert regexp_split_eval(mut vm, 'var unicode="😀".split(/(?:)/u),units="😀".split(/(?:)/);unicode.length===1&&unicode[0]==="😀"&&units.length===2&&units[0].charCodeAt(0)===0xd83d&&units[1].charCodeAt(0)===0xde00')!.as_bool()
}

fn test_regexp_split_constructs_sticky_species_before_limit_coercion_without_exec_at_zero() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_split_eval(mut vm, 'var log="",calls=0,matcher={exec(){calls++;return null}},rx={get constructor(){log+="constructor;";return {[Symbol.species]:Species}},get flags(){log+="flags;";return "g"},get lastIndex(){throw 9}};function Species(pattern,flags){if(pattern!==rx||flags!=="gy")throw 1;log+="construct;";return matcher}var out=RegExp.prototype[Symbol.split].call(rx,{toString(){log+="text;";return "abc"}},{valueOf(){log+="limit;";return 0}});out.length===0&&calls===0&&log==="text;constructor;flags;construct;limit;"')!.as_bool()
}

fn test_regexp_split_preserves_raw_captures_and_limit_short_circuits_length_getters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_split_eval(mut vm, 'var marker={},last=0,matcher={get lastIndex(){return last},set lastIndex(v){last=v},exec(){if(last===0)return null;last=2;return {length:2,1:marker}}},rx={flags:"",constructor:{[Symbol.species]:function(){return matcher}}};var out=RegExp.prototype[Symbol.split].call(rx,"ab",2);out.length===2&&out[0]==="a"&&out[1]===marker')!.as_bool()
	assert regexp_split_eval(mut vm, 'var reads=0;matcher.exec=function(){if(last===0)return null;last=2;return {get length(){reads++;throw 1}}};var out=RegExp.prototype[Symbol.split].call(rx,"ab",1);out.length===1&&out[0]==="a"&&reads===0')!.as_bool()
}

fn test_regexp_split_uses_subclass_exec_and_preserves_callback_errors() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_split_eval(mut vm, 'var sawSticky=false;class R extends RegExp{exec(s){sawSticky=this.sticky;return super.exec(s)}}var r=new R(",");"a,b".split(r).join(":")==="a:b"&&sawSticky&&!r.sticky')!.as_bool()
	assert regexp_split_eval(mut vm, 'var marker={},same=false,rx={flags:"",constructor:{[Symbol.species]:function(){return {lastIndex:0,exec(){throw marker}}}}};try{RegExp.prototype[Symbol.split].call(rx,"a")}catch(e){same=e===marker}same')!.as_bool()
}

fn test_cached_regexp_split_runs_from_native_code_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-regexp-split-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert regexp_split_eval(mut vm, 'function total(){return "20,22".split(/,/).reduce((a,b)=>a+Number(b),0)}total()===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
