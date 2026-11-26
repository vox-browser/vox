// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn replace_all_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'string-replace-all.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_replace_all_uses_non_overlapping_literal_matches_and_utf16_empty_search_positions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert replace_all_eval(mut vm, '"aaaaa".replaceAll("aa","x")==="xxa"&&"ab".replaceAll("","-")==="-a-b-"&&"".replaceAll("","x")==="x"&&"abc".replaceAll("z","x")==="abc"')!.as_bool()
	assert replace_all_eval(mut vm, 'var s="😀".replaceAll("","-");s.length===5&&s.charCodeAt(1)===0xd83d&&s.charCodeAt(3)===0xde00')!.as_bool()
	assert replace_all_eval(mut vm, '"aba".replaceAll("a","$$:$&:$1")==="$:a:$1b$:a:$1"&&"aba".replaceAll("a","$`-$\u0027")==="-babab-"')!.as_bool()
}

fn test_replace_all_functional_callbacks_get_original_positions_and_string_in_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert replace_all_eval(mut vm, 'var seen="";var result="aba".replaceAll("a",function(match,index,string){"use strict";if(this!==undefined||match!=="a"||string!=="aba")throw 1;seen+=index;return index});result==="0b2"&&seen==="02"')!.as_bool()
	assert replace_all_eval(mut vm, 'var called=0;"x".replaceAll("z",()=>{called++;return 1});called===0')!.as_bool()
}

fn test_replace_all_validates_global_flags_before_symbol_hook_and_receiver_conversion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert replace_all_eval(mut vm, 'var log="",receiver={toString(){log+="receiver;";throw 1}},pattern={get [Symbol.match](){log+="match;";return true},get flags(){log+="flags;";return "i"},get [Symbol.replace](){log+="method;";throw 2}},rejected=false;try{String.prototype.replaceAll.call(receiver,pattern,"x")}catch(e){rejected=e instanceof TypeError}rejected&&log==="match;flags;"')!.as_bool()
	assert replace_all_eval(mut vm, 'var receiver={toString(){throw 1}},replacement={},pattern={[Symbol.match]:false,get flags(){throw 2},[Symbol.replace](value,r){return value===receiver&&r===replacement&&this===pattern?42:0}};String.prototype.replaceAll.call(receiver,pattern,replacement)===42')!.as_bool()
	assert replace_all_eval(mut vm, '"a1 a22".replaceAll(/a([0-9]+)/g,"[$1]")==="[1] [22]"')!.as_bool()
}

fn test_replace_all_coercion_and_callback_errors_preserve_the_original_value() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert replace_all_eval(mut vm, 'var order="";String.prototype.replaceAll.call({toString(){order+="receiver;";return "aba"}},{toString(){order+="search;";return "a"}},{toString(){order+="replacement;";return "x"}})==="xbx"&&order==="receiver;search;replacement;"')!.as_bool()
	assert replace_all_eval(mut vm, 'var marker={},same=false;try{"aba".replaceAll("a",()=>{throw marker})}catch(e){same=e===marker}same')!.as_bool()
}

fn test_cached_replace_all_calls_use_native_code_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-replace-all-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert replace_all_eval(mut vm, 'function replace(){return "a-a".replaceAll("a",()=>"21")}replace()==="21-21"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
