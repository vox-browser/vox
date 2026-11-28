// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import os
import rand
import platform

fn test_binary_string_base64_roundtrip_all_latin1_units_and_embedded_nulls() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var binary="";for(var i=0;i<256;i++)binary+=String.fromCharCode(i);var encoded=btoa(binary),decoded=atob(encoded);decoded===binary&&decoded.length===256&&decoded.charCodeAt(0)===0&&decoded.charCodeAt(255)===255&&btoa("\\x00éÿ")==="AOn/"&&atob("AOn/")==="\\x00éÿ"&&btoa("")===""&&atob("")===""')!.as_bool()
}

fn test_binary_string_forgiving_base64_whitespace_padding_and_unused_bits() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'atob(" \\taG\\nVsbG8=\\r\\f")==="hello"&&atob("aGVsbG8")==="hello"&&atob("Zg")==="f"&&atob("Zh")==="f"&&atob("Zm8")==="fo"&&atob("Zm9")==="fo"')!.as_bool()
}

fn test_binary_string_invalid_input_is_native_dom_exception() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var errors=0;for(var input of ["Z","Zg=","Zg===","=Zg=","Z=g=","====","Zg==x","Zg==\\u00a0","-w==","_w==","😀","\\ud800"])try{atob(input)}catch(e){if(e instanceof DOMException&&e.name==="InvalidCharacterError"&&e.code===5)errors++}errors===12')!.as_bool()
	assert text_encoding_eval(mut vm, 'var errors=0;for(var input of ["Ā","😀","\\ud800","\\udc00"])try{btoa(input)}catch(e){if(e instanceof DOMException&&e.name==="InvalidCharacterError")errors++}errors===4')!.as_bool()
}

fn test_binary_string_webidl_required_arguments_live_coercion_and_window_brand() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var errors=0,reads=0,source={toString(){reads++;return "eA=="}};for(var f of [()=>atob(),()=>btoa(),()=>atob(Symbol()),()=>btoa(Symbol()),()=>atob.call({},source),()=>btoa.call({},source)])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===6&&reads===0&&atob(source)==="x"&&reads===1&&btoa(undefined)==="dW5kZWZpbmVk"&&btoa(null)==="bnVsbA=="')!.as_bool()
	assert text_encoding_eval(mut vm, 'var marker={},same=false;try{btoa({toString(){throw marker}})}catch(e){same=e===marker}same&&atob.call(null,"eA==")==="x"&&atob.call(window,"eA==")==="x"')!.as_bool()
}

fn test_binary_string_global_metadata_and_fixed_callback_count() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	before := host.closures.len
	assert text_encoding_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(window,"atob");atob.name==="atob"&&btoa.name==="btoa"&&atob.length===1&&btoa.length===1&&d.writable&&d.enumerable&&d.configurable&&(function(){for(var i=0;i<100;i++)if(atob(btoa("item"+i))!=="item"+i)return false;return true})()')!.as_bool()
	assert host.closures.len == before
}

fn test_binary_string_results_and_dom_exceptions_survive_temporary_arena() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('native binary-string codecs')
	entry := arena.enter()
	text_encoding_eval(mut vm, 'var binary=atob("AOn/"),encoded=btoa(binary),failure;try{atob("?")}catch(e){failure=e}')!
	arena.leave(entry)
	arena.reset(); arena.release()
	assert text_encoding_eval(mut vm, 'binary==="\\x00éÿ"&&encoded==="AOn/"&&failure instanceof DOMException&&failure.name==="InvalidCharacterError"')!.as_bool()
}

fn test_binary_string_native_work_obeys_instruction_limit() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	text_encoding_eval(mut vm, 'var hugeBinary="a".repeat(1000000)')!
	for source in ['btoa(hugeBinary)','atob(hugeBinary)'] {
		mut script := libjs.Script.parse(source, vm.realm(), 'binary-string-budget.js', unsafe { nil })!
		if _ := vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 200}) { assert false }
		else { assert exception_message(err).contains('instruction budget') }
	}
}

fn test_cached_binary_string_codecs_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-binary-string-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert text_encoding_eval(mut vm, 'function binaryRoundtrip(s){return atob(btoa(s))}binaryRoundtrip("\\x00éÿ")==="\\x00éÿ"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
