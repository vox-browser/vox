// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import platform
import rand

fn history_fixture() !(&Host, &libjs.VM, &dom.Document) {
	address := dom.URL{value: 'https://history.test/start'}
	mut document := html.parse_navigation_document('<!doctype html><base href="/base/"><body>History</body>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, document
}

fn history_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-history.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_history_push_replace_update_actual_native_entries_and_live_document_location() {
	mut host, mut vm, document := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var saved=history;history.state===null&&history.length===1&&history===saved&&history instanceof History')!.as_bool()
	assert history_eval(mut vm, 'history.replaceState({first:true},"unused","first?q=1");history.state.first&&history.length===1&&document.URL==="https://history.test/base/first?q=1"&&location.href===document.URL&&location.pathname==="/base/first"&&location.search==="?q=1"')!.as_bool()
	assert history_eval(mut vm, 'history.pushState(42,"","/next#here");history.state===42&&history.length===2&&location.hash==="#here"&&location.toString()===document.URL')!.as_bool()
	binding := host.history_binding or { panic('No native History') }
	window := host.frame_window(mut vm)!
	model := window.navigable_model()
	entry := model.active_session_history_entry()?
	assert model.get_session_history_entries().len == 2
	assert entry.url.serialize() == document.url.serialize()
	assert binding.native.current_url().serialize() == document.url.serialize()
	assert html.structured_deserialize(entry.classic_history_api_state)!.number_data == 42
	assert document.history().state.number_data == 42
}

fn test_history_storage_clone_preserves_cycles_aliases_sparse_arrays_utf16_and_bigints() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var child={n:1},original={a:child,b:child,integer:123456789012345678901234567890n,text:"\\ud800",zero:-0},array=[];array.length=4;array[2]=child;array.extra=original;original.array=array;original.self=original;original["\\udc00"]=17;history.replaceState(original,"");var first=history.state;original.a.n=99;first.local=42;first!==original&&first.self===first&&first.a===first.b&&first.a.n===1&&first.array!==array&&first.array.extra===first&&first.array[2]===first.a&&first.array.length===4&&!(0 in first.array)&&!(1 in first.array)&&!(3 in first.array)&&first.integer===original.integer&&first.text.charCodeAt(0)===55296&&first["\\udc00"]===17&&Object.is(first.zero,-0)&&history.state===first&&history.state.local===42')!.as_bool()
	assert history_eval(mut vm, 'history.replaceState({next:true},"",null);history.state!==first&&history.state.next&&history.length===1;')!.as_bool()
}

fn test_history_clone_snapshots_keys_recurses_depth_first_and_ignores_prototypes_and_symbols() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var order="",source=Object.create({inherited:9}),child={get x(){order+="x";delete source.gone;Object.defineProperty(source,"later",{enumerable:false});source.added=8;return 1}};Object.defineProperty(source,"first",{enumerable:true,get(){order+="a";return child}});source.gone=2;Object.defineProperty(source,"later",{enumerable:true,configurable:true,get(){order+="b";return 3}});source[Symbol()]=()=>1;Object.defineProperty(source,"hidden",{value:()=>1});history.replaceState(source,"");var s=history.state;order==="axb"&&s.first.x===1&&s.later===3&&!("gone" in s)&&!("added" in s)&&!("inherited" in s)&&!("hidden" in s)&&Object.getOwnPropertySymbols(s).length===0&&Object.getPrototypeOf(s)===Object.prototype&&Object.getOwnPropertyDescriptor(s,"first").writable')!.as_bool()
	assert history_eval(mut vm, 'class C{#hidden=1;visible=2}var c=new C();history.replaceState(c,"");history.state.visible===2&&Object.getPrototypeOf(history.state)===Object.prototype')!.as_bool()
	assert history_eval(mut vm, 'var source=Object.create(null);Object.defineProperty(source,"__proto__",{value:{safe:true},enumerable:true});history.replaceState(source,"");Object.getPrototypeOf(history.state)===Object.prototype&&Object.getOwnPropertyDescriptor(history.state,"__proto__").value.safe')!.as_bool()
}

fn test_history_brands_conversions_clone_errors_and_url_errors_leave_entries_unchanged() {
	mut host, mut vm, document := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var count=0;for(var run of [()=>History(),()=>new History(),()=>history.pushState(1),()=>history.replaceState(1,Symbol()),()=>history.replaceState(1,"",Symbol()),()=>History.prototype.pushState.call({},1,""),()=>Object.getOwnPropertyDescriptor(History.prototype,"state").get.call(Object.create(History.prototype)),()=>Object.getOwnPropertyDescriptor(globalThis,"history").get.call({}),()=>{history.scrollRestoration="invalid"}])try{run()}catch(e){if(e instanceof TypeError)count++}count===9')!.as_bool()
	assert history_eval(mut vm, 'history.replaceState({kept:1},"");var saved=history.state,n=0;for(var value of [Symbol(),()=>1,{nested(){return 1}},document.body,new AbortController(),navigator,history,Promise.resolve(1),new Map()])try{history.pushState(value,"","/bad")}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError"&&e.code===25)n++}var security=0;for(var url of ["https://elsewhere.test/","http://["])try{history.replaceState(1,"",url)}catch(e){if(e instanceof DOMException&&e.name==="SecurityError")security++}n===9&&security===2&&history.state===saved&&history.state.kept===1&&history.length===1')!.as_bool()
	assert history_eval(mut vm, 'var marker={},same=false,order="",state={get value(){order+="s";throw marker}};try{history.replaceState(state,{toString(){order+="t";return "unused"}},{toString(){order+="u";return "/next"}})}catch(e){same=e===marker}same&&order==="tus"&&history.state.kept===1')!.as_bool()
	assert document.url.serialize() == 'https://history.test/start'
	binding := host.history_binding or { panic('No native History') }
	mut native := binding.native
	native.set_fully_active(false)
	assert history_eval(mut vm, 'var n=0,touched=0;for(var run of [()=>history.state,()=>history.length,()=>history.scrollRestoration,()=>history.pushState({get x(){touched++;return 1}},"")])try{run()}catch(e){if(e instanceof DOMException&&e.name==="SecurityError")n++}n===4&&touched===0')!.as_bool()
}

fn test_history_scroll_restoration_and_state_cache_follow_native_restored_entries() {
	mut host, mut vm, mut document := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'history.scrollRestoration="manual";history.replaceState({first:true},"");var previous=history.state;history.scrollRestoration==="manual"')!.as_bool()
	window := host.frame_window(mut vm)!
	assert window.navigable_model().active_session_history_entry()?.scroll_restoration_mode == .manual
	record := html.structured_serialize_for_storage(dom.js_number(19))!
	entry := &dom.SessionHistoryEntry{url: dom.URL{value:'https://history.test/restored'},classic_history_api_state: dom.DOMSerializationRecord{data:record.data.clone()}}
	document.update_for_history_step_application(entry, false, 3, 1, none)
	assert history_eval(mut vm, 'history.state===19&&history.state!==previous&&history.length===3&&location.href===document.URL&&location.href==="https://history.test/restored"')!.as_bool()
}

fn test_history_rejects_weak_references_before_reading_their_own_state_properties() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'history.replaceState({safe:true},"");var saved=history.state,reads=0,ref=new WeakRef({}),errors=0;Object.defineProperty(ref,"visible",{enumerable:true,get(){reads++;return 1}});for(var state of [ref,{nested:ref}])try{history.pushState(state,"","/invalid")}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError")errors++}errors===2&&reads===0&&history.state===saved&&history.state.safe&&history.length===1')!.as_bool()
}

fn test_history_rejects_generator_frames_before_running_body_or_own_getters() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var body=0,reads=0;function* g(){body++;yield 42}var it=g(),rejected=false;Object.defineProperty(it,"visible",{enumerable:true,get(){reads++;return 1}});try{history.replaceState(it,"")}catch(e){rejected=e instanceof DOMException&&e.name==="DataCloneError"}rejected&&body===0&&reads===0&&history.state===null')!.as_bool()
}

fn test_history_rejects_regexp_match_iterators_before_enumerable_getters() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var reads=0,it="a".matchAll(/a/g),rejected=false;Object.defineProperty(it,"visible",{enumerable:true,get(){reads++;return 1}});try{history.replaceState(it,"")}catch(e){rejected=e instanceof DOMException&&e.name==="DataCloneError"}rejected&&reads===0&&history.state===null')!.as_bool()
}

fn test_history_retains_cloned_state_after_temporary_allocation_scope() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	history_eval(mut vm, 'var original={text:"retained",array:[1,2]};original.self=original')!
	receiver := host.history_object
	write := receiver.get(mut vm, libjs.PropertyName.from_str('replaceState'))!
	data := vm.global_object().get(mut vm, libjs.PropertyName.from_str('original'))!
	arguments := [data, libjs.Value.from_string(vm.empty_string()), libjs.Value.from_string(vm.create_string_from_str('/retained'))]
	mut arena := platform.new_arena('native-history-state')
	entry := arena.enter()
	libjs.call(mut vm, write, libjs.Value.from_object(receiver), arguments)!
	state := receiver.get(mut vm, libjs.PropertyName.from_str('state'))!
	arena.leave(entry)
	assert !arena.contains(state.as_object())
	binding := host.history_binding or { panic('No native History') }
	assert !arena.contains(binding)
	arena.reset()
	arena.release()
	assert history_eval(mut vm, 'history.state.text==="retained"&&history.state.self===history.state&&history.state.array[1]===2&&location.pathname==="/retained"')!.as_bool()
}

fn test_cached_github_style_history_replace_executes_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-history-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, _ := history_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert history_eval(mut vm, 'function replace(url){history.replaceState({url:url},"",url);return history.state.url===url&&location.pathname===url}replace("/cached")')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}

fn test_history_rejects_live_and_revoked_proxies_without_running_traps() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert history_eval(mut vm, 'var reads=0,handler={get(){reads++;throw 1},ownKeys(){reads++;throw 2},getPrototypeOf(){reads++;throw 3}},p=new Proxy({},handler),r=Proxy.revocable([],handler);r.revoke();var errors=0;for(var state of [p,{nested:p},r.proxy])try{history.replaceState(state,"")}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError")errors++}errors===3&&reads===0&&history.state===null')!.as_bool()
}
