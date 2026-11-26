// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn regexp_search_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-search.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_regexp_search_finds_matches_and_restores_original_last_index() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_search_eval(mut vm, 'var r=/a/g;r.lastIndex=17;"ba".search(r)===1&&r.lastIndex===17&&"xx".search(r)===-1&&r.lastIndex===17&&"abc".search("b")===1&&"abc".search()===0')!.as_bool()
	assert regexp_search_eval(mut vm, 'var r=/a/g;r.lastIndex=-0;"a".search(r)===0&&Object.is(r.lastIndex,-0)')!.as_bool()
	assert regexp_search_eval(mut vm, 'var r=/a/;Object.defineProperty(r,"lastIndex",{writable:false});"a".search(r)===0')!.as_bool()
}

fn test_regexp_search_restores_before_result_index_getter_and_returns_raw_value() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_search_eval(mut vm, 'var log="",last=7,marker={},r={get lastIndex(){return last},set lastIndex(v){last=v;log+="set"+v+";"},exec(s){log+="exec;";last=3;return {get index(){if(last!==7)throw 1;log+="index;";return marker}}}};RegExp.prototype[Symbol.search].call(r,"abc")===marker&&log==="set0;exec;set7;index;"')!.as_bool()
}

fn test_regexp_search_does_not_restore_after_abrupt_exec_and_preserves_error_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_search_eval(mut vm, 'var marker={},r={lastIndex:7,exec(){this.lastIndex=2;throw marker}},same=false;try{RegExp.prototype[Symbol.search].call(r,"a")}catch(e){same=e===marker}same&&r.lastIndex===2')!.as_bool()
}

fn test_string_search_delegates_original_receiver_before_coercion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_search_eval(mut vm, 'var receiver={toString(){throw 1}},pattern={[Symbol.search](value){return this===pattern&&value===receiver?42:0}};String.prototype.search.call(receiver,pattern)===42')!.as_bool()
	assert regexp_search_eval(mut vm, 'var marker={},same=false,receiver={toString(){throw 1}},pattern={get [Symbol.search](){throw marker}};try{String.prototype.search.call(receiver,pattern)}catch(e){same=e===marker}same')!.as_bool()
}
