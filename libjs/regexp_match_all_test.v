// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn match_all_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-match-all.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_match_all_is_lazy_copies_last_index_and_keeps_capture_and_iterator_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert match_all_eval(mut vm, 'var r=/(?<letter>a)(b)?/dg;r.lastIndex=1;var it="a ab a".matchAll(r),a=it.next(),b=it.next(),c=it.next();!a.done&&a.value[0]==="ab"&&a.value.groups.letter==="a"&&a.value.index===2&&a.value.indices[0][1]===4&&!b.done&&b.value[0]==="a"&&b.value.index===5&&c.done&&r.lastIndex===1&&it[Symbol.iterator]()===it&&Object.prototype.toString.call(it)==="[object RegExp String Iterator]"')!.as_bool()
	assert match_all_eval(mut vm, 'var calls=0;class R extends RegExp{exec(s){calls++;return super.exec(s)}}var r=new R("a","g"),it="aba".matchAll(r),before=calls,a=[...it];before===0&&calls===3&&a.length===2&&r.lastIndex===0')!.as_bool()
	assert match_all_eval(mut vm, 'var a=[..."aba".matchAll("a")];a.length===2&&a[0].index===0&&a[1].index===2')!.as_bool()
}

fn test_match_all_observes_species_flags_construction_and_last_index_in_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert match_all_eval(mut vm, 'var log="",saved=-1,calls=0,matcher={set lastIndex(v){log+="set;";saved=v},exec(s){calls++;return null}},rx={get constructor(){log+="constructor;";return {get [Symbol.species](){log+="species;";return Species}}},get flags(){log+="flags;";return {toString(){log+="flags-string;";return "g"}}},get lastIndex(){log+="index;";return 2.9}};function Species(pattern,flags){if(pattern!==rx||flags!=="g")throw 1;log+="construct;";return matcher}var it=RegExp.prototype[Symbol.matchAll].call(rx,{toString(){log+="text;";return "abc"}}),before=calls,first=it.next(),last=it.next();log==="text;constructor;species;flags;flags-string;construct;index;set;"&&saved===2&&before===0&&calls===1&&first.done&&last.done')!.as_bool()
}

fn test_string_match_all_validates_flags_before_method_and_receiver_conversion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert match_all_eval(mut vm, 'var log="",receiver={toString(){log+="receiver;";throw 1}},pattern={get [Symbol.match](){log+="match;";return true},get flags(){log+="flags;";return "i"},get [Symbol.matchAll](){log+="method;";throw 2}},rejected=false;try{String.prototype.matchAll.call(receiver,pattern)}catch(e){rejected=e instanceof TypeError}rejected&&log==="match;flags;"')!.as_bool()
	assert match_all_eval(mut vm, 'var receiver={toString(){throw 1}},pattern={get [Symbol.match](){return false},get flags(){throw 2},[Symbol.matchAll](value){return this===pattern&&value===receiver?42:0}};String.prototype.matchAll.call(receiver,pattern)===42')!.as_bool()
	for source in ['"abc".matchAll(/a/)', 'String.prototype.matchAll.call(null,/a/g)', 'String.prototype.matchAll.call("abc",{[Symbol.match]:true,flags:null})'] {
		match_all_eval(mut vm, source) or {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			continue
		}
		assert false, source
	}
}

fn test_match_all_unicode_empty_matches_advance_by_code_points_and_non_global_yields_once() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert match_all_eval(mut vm, 'var unicode=[..."😀".matchAll(/(?:)/gu)],units=[..."😀".matchAll(/(?:)/g)];unicode.length===2&&unicode[0].index===0&&unicode[1].index===2&&units.length===3&&units[1].index===1')!.as_bool()
	assert match_all_eval(mut vm, 'var it=/a/[Symbol.matchAll]("aba");var a=it.next(),b=it.next();!a.done&&a.value.index===0&&b.done&&b.value===undefined')!.as_bool()
}

fn test_match_all_exec_results_keep_identity_and_abrupt_next_can_retry() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert match_all_eval(mut vm, 'var marker={},calls=0,result={0:"a",index:0},matcher={exec(){calls++;if(calls===1)throw marker;if(calls===2)return result;return null}},rx={flags:"g",constructor:{[Symbol.species]:function(){return matcher}}};var it=RegExp.prototype[Symbol.matchAll].call(rx,"a"),same=false;try{it.next()}catch(e){same=e===marker}var a=it.next(),b=it.next();same&&a.value===result&&!a.done&&b.done&&calls===3')!.as_bool()
	assert match_all_eval(mut vm, 'var rejected=false;try{Object.getPrototypeOf("a".matchAll(/a/g)).next.call({})}catch(e){rejected=e instanceof TypeError}rejected')!.as_bool()
}

fn test_cached_match_all_iteration_runs_with_native_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-match-all-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert match_all_eval(mut vm, 'function total(){var sum=0;for(var match of "20 22".matchAll(/[0-9]+/g))sum+=Number(match[0]);return sum}total()===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
