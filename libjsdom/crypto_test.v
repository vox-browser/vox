// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn crypto_binding_fixture(address string) !(&Host, &libjs.VM) {
	url := dom.URL{value:address}
	document := html.parse_navigation_document('<body></body>',url,url.origin(),none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm,vm.realm(),document,Hooks{})!
	return host,vm
}

fn crypto_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source,vm.realm(),'native-crypto.js',unsafe { nil })!
	return vm.run_with_limits(mut script,libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_crypto_uuid_uses_native_secure_global_and_retains_interface_identity() {
	mut host, mut vm := crypto_binding_fixture('https://native-crypto.test/')!
	defer { host.close() }
	assert crypto_binding_eval(mut vm, 'var value=crypto.randomUUID(),other=crypto.randomUUID(),hex="0123456789abcdef",valid=value.length===36;for(var index=0;index<value.length;index++)valid=valid&&([8,13,18,23].includes(index)?value[index]==="-":hex.includes(value[index]));valid&&value[14]==="4"&&"89ab".includes(value[19])&&other!==value&&window.crypto===crypto&&crypto instanceof Crypto&&Object.prototype.toString.call(crypto)==="[object Crypto]"&&crypto.randomUUID.length===0&&crypto.getRandomValues.length===1')!.as_bool()
}

fn test_crypto_random_values_write_only_the_actual_native_integer_view() {
	mut host, mut vm := crypto_binding_fixture('https://native-crypto.test/')!
	defer { host.close() }
	assert crypto_binding_eval(mut vm, 'var buffer=new ArrayBuffer(32),all=new Uint8Array(buffer);all.fill(7);var view=new Uint8Array(buffer,8,16),same=crypto.getRandomValues(view)===view;var outside=true;for(var i=0;i<8;i++)outside=outside&&all[i]===7&&all[i+24]===7;var kinds=true;for(var C of [Int8Array,Uint8Array,Uint8ClampedArray,Int16Array,Uint16Array,Int32Array,Uint32Array,BigInt64Array,BigUint64Array]){var values=new C(2);kinds=kinds&&crypto.getRandomValues(values)===values}same&&outside&&kinds&&crypto.getRandomValues(new Uint8Array(0)).length===0')!.as_bool()
}

fn test_crypto_view_conversion_native_errors_and_brands_precede_random_writes() {
	mut host, mut vm := crypto_binding_fixture('https://native-crypto.test/')!
	defer { host.close() }
	assert crypto_binding_eval(mut vm, 'var count=0;for(var run of [()=>crypto.getRandomValues(),()=>crypto.getRandomValues({}),()=>Crypto.prototype.getRandomValues.call({},new Uint8Array(1)),()=>Crypto(),()=>new Crypto(),()=>crypto.getRandomValues(new Uint8Array(new SharedArrayBuffer(8))),()=>crypto.getRandomValues(new Uint8Array(new ArrayBuffer(8,{maxByteLength:16})))])try{run()}catch(e){if(e instanceof TypeError)count++}var mismatch=0;for(var value of [new Float32Array(2),new Float64Array(2),new DataView(new ArrayBuffer(4))])try{crypto.getRandomValues(value)}catch(e){if(e instanceof DOMException&&e.name==="TypeMismatchError")mismatch++}var quota=false;try{crypto.getRandomValues(new Uint8Array(65537))}catch(e){quota=e instanceof DOMException&&e.name==="QuotaExceededError"}count===7&&mismatch===3&&quota')!.as_bool()
}

fn test_crypto_insecure_global_retains_random_values_without_exposing_random_uuid() {
	mut host, mut vm := crypto_binding_fixture('http://native-crypto.test/')!
	defer { host.close() }
	assert crypto_binding_eval(mut vm, 'var saved=crypto;crypto={};saved===crypto&&typeof crypto.getRandomValues==="function"&&!("randomUUID" in crypto)&&crypto.getRandomValues(new Uint8Array(1)).length===1')!.as_bool()
}

fn test_cached_crypto_calls_use_the_new_native_global_without_a_compiler() {
	directory := os.join_path(os.temp_dir(),'vox-crypto-cache-'+rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := crypto_binding_fixture('https://native-crypto.test/')!
		vm.enable_native_code_cache(directory,if visit==0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert crypto_binding_eval(mut vm, 'function run(){var bytes=new Uint8Array(16);return crypto.getRandomValues(bytes)===bytes&&crypto.randomUUID().length===36}run()')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit==1 { assert stats.cache_hits > 0 && stats.cache_misses==0 && stats.compiler_invocations==0 && activity.entries>0 }
		vm.close_native_code()!
		host.close()
	}
}
