// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import fetch
import html
import libjs
import os
import rand

fn headers_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'headers.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 10000}) or { return error(exception_message(err)) }
}

fn test_headers_construct_normalize_and_preserve_native_identity_and_latin1() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert headers_eval(mut vm, 'var h=new Headers([["X-B"," two "],["x-a","one"],["x-b","three"]]);h instanceof Headers&&h.get("X-B")==="two, three"&&h.get("missing")===null&&h.has("x-a")&&Headers.length===0&&Object.prototype.toString.call(h)==="[object Headers]"')!.as_bool()
	assert headers_eval(mut vm, 'h.set("X-B","four");h.append("x-latin","\\u00e9");h.delete("x-a");!h.has("x-a")&&h.get("x-b")==="four"&&h.get("x-latin").charCodeAt(0)===233')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('h'))!
	mut native := host.headers[voidptr(value.as_object())] or { panic('Missing native Headers') }
	assert native.get('x-latin')? == [u8(233)].bytestr()
	native.append('x-native', 'live')!
	assert voidptr(host.wrap_headers(native, none).as_object()) == voidptr(value.as_object())
	assert headers_eval(mut vm, 'h.get("x-native")==="live"&&new Headers(h).get("x-b")==="four"')!.as_bool()
	assert headers_eval(mut vm, 'class H extends Headers{}var sub=new H({"x-answer":42});sub instanceof H&&sub instanceof Headers&&sub.get("x-answer")==="42"')!.as_bool()
}

fn test_headers_record_conversion_order_enumerability_and_dictionary_errors() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert headers_eval(mut vm, 'var order="",o={get b(){order+="b";return "2"},get a(){order+="a";return "1"}};Object.defineProperty(o,"hidden",{value:"no"});var h=new Headers(o);order==="ba"&&!h.has("hidden")&&h.get("a")==="1"')!.as_bool()
	for source in ['Headers()', 'new Headers(null)', 'new Headers(42)', 'new Headers([["x"]])', 'new Headers([["x","a","b"]])', 'new Headers(["xy"])', 'new Headers({x:Symbol()})', 'new Headers({x:"\\u0100"})', 'new Headers({x:"\\0"})', 'new Headers({"bad name":"x"})', 'h.get("")', 'h.set("x")', 'Headers.prototype.get.call({},"x")'] {
		assert headers_eval(mut vm, 'var caught=false;try{'+source+'}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	}
	assert headers_eval(mut vm, 'var token={},caught=false,o={toString:function(){throw token}};try{h.set("x",o)}catch(e){caught=e===token};caught')!.as_bool()
	assert headers_eval(mut vm, 'var o={},caught=false;o[Symbol()]=1;try{new Headers(o)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_headers_iterators_and_foreach_observe_live_native_changes() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert headers_eval(mut vm, 'var h=new Headers({c:"3",a:"1"}),it=h.keys();var a=it.next().value;h.append("b","2");var b=it.next().value;h.delete("c");var done=it.next().done;h.append("d","4");a==="a"&&b==="b"&&done&&it.next().done&&it[Symbol.iterator]()===it&&h.entries===h[Symbol.iterator]')!.as_bool()
	assert headers_eval(mut vm, 'var h=new Headers({a:"1"}),result="",context={},identity=true;h.forEach(function(v,k,o){identity=identity&&this===context&&o===h;result+=k+v;if(k==="a")h.append("b","2")},context);result==="a1b2"&&identity&&h.values().next().value==="1"')!.as_bool()
	assert headers_eval(mut vm, 'var h=new Headers([["Set-Cookie","a=1"],["Set-Cookie","b=2"]]),it=h.entries();h.getSetCookie().join("|")==="a=1|b=2"&&it.next().value[1]==="a=1"&&it.next().value[1]==="b=2"&&it.next().done')!.as_bool()
}

fn test_headers_iterable_conversion_closes_inner_and_outer_after_original_exception() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert headers_eval(mut vm, 'var closed="",token={},caught=false,bad={toString:function(){throw token}},pair={next:function(){return{value:bad,done:false}},return:function(){closed+="i";return{}}},outer={next:function(){return{value:pair,done:false}},return:function(){closed+="o";return{}}};pair[Symbol.iterator]=function(){return this};outer[Symbol.iterator]=function(){return this};try{new Headers(outer)}catch(e){caught=e===token};caught&&closed==="io"')!.as_bool()
}

fn test_headers_guard_and_shared_budget_preserve_native_rules_and_close() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	mut native := fetch.Headers.construct([fetch.HeaderPair{name: 'x', value: '42'}])!
	native.set_guard(.immutable)
	mut global := vm.global_object()
	global.define_direct_property(libjs.PropertyName.from_str('frozen'), host.wrap_headers(native, none), libjs.attribute_configurable)
	assert headers_eval(mut vm, 'var caught=false;try{frozen.append("x","7")}catch(e){caught=e instanceof TypeError};caught&&frozen.get("x")==="42"')!.as_bool()
	if _ := headers_eval(mut vm, 'var n=0,h=new Headers({a:"1"});h.forEach(function(){h.append("x"+(++n),"1")})') { assert false }
	host.close()
	assert host.headers.len == 0 && host.headers_wrappers.len == 0 && host.headers_iterators.len == 0
}

fn test_headers_native_cache_reopens_without_a_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-headers-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut document := html.parse_document('<body></body>')
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), document, Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert headers_eval(mut vm, 'var h=new Headers({"x-answer":42});h.get("x-answer")==="42"&&h.entries().next().value[0]==="x-answer"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 1 && stats.compiler_invocations == 0 && activity.entries >= 1 }
		vm.close_native_code()!
		host.close()
	}
}

fn test_headers_record_conversion_preserves_proxy_traps_and_original_exceptions() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert headers_eval(mut vm, 'var log="",p=new Proxy({"x-a":"one","x-b":"two"},{ownKeys(){log+="keys;";return ["x-b","x-a"]},getOwnPropertyDescriptor(t,k){log+="desc:"+k+";";return Reflect.getOwnPropertyDescriptor(t,k)},get(t,k,r){if(typeof k==="string")log+="get:"+k+";";return Reflect.get(t,k,r)}}),h=new Headers(p);h.get("x-a")==="one"&&h.get("x-b")==="two"&&log==="keys;desc:x-b;get:x-b;desc:x-a;get:x-a;"')!.as_bool()
	assert headers_eval(mut vm, 'var marker={},p=new Proxy({a:1},{getOwnPropertyDescriptor(){throw marker}}),caught=false;try{new Headers(p)}catch(e){caught=e===marker}caught')!.as_bool()
}
