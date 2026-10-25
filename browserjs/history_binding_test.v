module browserjs

import dom
import html
import loader
import platform

fn history_binding_fixture() !(&Runtime, &dom.Document, &html.WindowModel) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://history.example/start' }
	document := html.parse_navigation_document('<!doctype html><base href="/base/"><body></body>', address, address.origin(), none)!
	window_target := document.get_window() or { return error('History fixture has no Window') }
	window := unsafe { &html.WindowModel(window_target) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_history_binding()!
	return runtime, document, window
}

fn test_history_state_clones_actual_engine_values_and_commits_native_urls() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, window := history_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 if(history.state!==null||history.length!==1)throw new Error("initial history");
 globalThis.original={integer:12345678901234567890n,bytes:new Uint8Array([3,7])};original.self=original;
 history.replaceState(original,"unused","first?q=1");
 if(history.state===original)throw new Error("state was not cloned");
 const first=history.state;
 if(first===original||first.self!==first||first.integer!==original.integer||first.bytes===original.bytes||first.bytes[1]!==7)throw new Error("storage clone");
 original.bytes[1]=99;first.custom=42;
 if(history.state!==first||history.state.custom!==42||first.bytes[1]!==7||history.length!==1)throw new Error("state identity");
 history.pushState({second:true},"","/next#here");
 history.state!==first&&history.state.second&&history.length===2;
 ')! == 'true'
	assert document.history().length == 2
	assert document.history().state.kind == .object
	assert document.url.serialize() == 'https://history.example/next#here'
	assert window.history().current_url().serialize() == document.url.serialize()
	model := window.navigable_model()
	entry := model.active_session_history_entry()?
	assert entry.url.serialize() == document.url.serialize()
	assert model.get_session_history_entries().len == 2
	assert html.structured_deserialize(entry.classic_history_api_state)!.kind == .object
	assert runtime.evaluate_host(r'
 history.scrollRestoration="manual";history.replaceState(7,"",null);
 history.scrollRestoration==="manual"&&history.state===7&&history.length===2;
 ')! == 'true'
	active := model.active_session_history_entry()?
	assert active.scroll_restoration_mode == .manual
	assert document.history().state.number_data == 7
}

fn test_history_binding_enforces_receivers_conversion_and_url_security() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, window := history_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const saved=history;let invalid=0,traps=0;
 const proxy=new Proxy(history,{get(){traps++;throw 1},getPrototypeOf(){traps++;throw 1}});
 for(const receiver of [null,{},Object.create(history),proxy])for(const callback of [()=>History.prototype.pushState.call(receiver,0,""),()=>Object.getOwnPropertyDescriptor(History.prototype,"state").get.call(receiver)])try{callback()}catch(e){if(e instanceof TypeError)invalid++}
 for(const callback of [()=>new History(),()=>history.pushState(0),()=>history.replaceState(0,Symbol()),()=>{history.scrollRestoration="invalid"}])try{callback()}catch(e){if(e instanceof TypeError)invalid++}
 let windowBrand=false;try{Object.getOwnPropertyDescriptor(globalThis,"history").get.call({})}catch(e){windowBrand=e instanceof TypeError}
 let security=0;for(const url of ["https://elsewhere.example/","http://["])try{history.pushState(1,"",url)}catch(e){if(e instanceof DOMException&&e.name==="SecurityError")security++}
 let clone=false;try{history.replaceState({method(){}},"")}catch(e){clone=e instanceof DOMException&&e.name==="DataCloneError"}
 history.replaceState(2,{[Symbol.toPrimitive](hint){if(hint!=="string")throw new Error("conversion hint");return "ignored"}},"");
 const method=Object.getOwnPropertyDescriptor(History.prototype,"pushState"),attribute=Object.getOwnPropertyDescriptor(globalThis,"history");
 invalid===12&&windowBrand&&traps===0&&security===2&&clone&&history===saved&&history.state===2&&history.length===1&&method.value.length===2&&method.enumerable&&method.writable&&method.configurable&&attribute.set===undefined&&attribute.enumerable&&attribute.configurable&&Object.prototype.toString.call(history)==="[object History]";
 ')! == 'true'
	assert document.url.serialize() == 'https://history.example/start'
	runtime.install_history_binding()!
	assert runtime.evaluate_host('history.state===2')! == 'true'
	mut history := window.history()
	history.set_fully_active(false)
	assert runtime.evaluate_host(r'
 let inactive=0;for(const callback of [()=>history.state,()=>history.length,()=>history.pushState(null,""),()=>history.scrollRestoration])try{callback()}catch(e){if(e instanceof DOMException&&e.name==="SecurityError")inactive++}inactive===4;
 ')! == 'true'
}

fn test_history_binding_resolves_document_base_and_refreshes_after_native_traversal() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, window := history_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('history.replaceState({first:true},"","first?q=1");globalThis.previous=history.state')!
	assert document.url.serialize() == 'https://history.example/base/first?q=1'
	record := html.structured_serialize_for_storage(dom.js_number(19))!
	entry := &dom.SessionHistoryEntry{
		url:                       dom.URL{ value: 'https://history.example/restored' }
		classic_history_api_state: dom.DOMSerializationRecord{ data: record.data.clone() }
	}
	document.update_for_history_step_application(entry, false, 3, 1, none)
	assert window.history().length()! == 3
	assert runtime.evaluate_host('history.state===19&&history.length===3')! == 'true'
}

fn test_history_state_is_realm_local_and_initial_blank_push_replaces() {
	$if !darwin && !linux {
		return
	}
	mut first, mut first_document, _ := history_binding_fixture()!
	mut second, mut second_document, _ := history_binding_fixture()!
	defer {
		first.close()
		second.close()
		first_document.finalize()
		second_document.finalize()
	}
	first.evaluate_host('history.replaceState({realm:1},"","/one")')!
	assert second.evaluate_host('history.state===null&&history.length===1')! == 'true'
	second_document.set_is_initial_about_blank(true)
	second.evaluate_host('history.pushState({realm:2},"")')!
	assert second.evaluate_host('history.state.realm===2&&history.length===1')! == 'true'
	assert first.evaluate_host('history.state.realm===1&&history.length===1')! == 'true'
	assert first_document.url.serialize() == 'https://history.example/one'
	assert second_document.url.serialize() == 'https://history.example/start'
}

fn test_history_storage_restore_uses_owning_realm_platform_interfaces() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := history_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const source=new DOMException("stored","AbortError");
 history.replaceState({first:source,again:source},"");
 const restored=history.state;globalThis.previousExceptionState=restored;
 restored.first!==source&&restored.first===restored.again&&restored.first instanceof DOMException&&restored.first.name==="AbortError"&&restored.first.message==="stored";
 ')! == 'true'
	// A native traversal must use the same target-realm decoder as push/replace.
	previous := document.get_latest_entry()?
	entry := &dom.SessionHistoryEntry{
		url:                       dom.URL{ value: 'https://history.example/restored' }
		classic_history_api_state: previous.classic_history_api_state
	}
	document.update_for_history_step_application(entry, false, 2, 0, none)
	assert runtime.evaluate_host('history.state!==previousExceptionState&&history.state.first instanceof DOMException&&history.state.first.name==="AbortError"')! == 'true'
	assert document.history().state.kind == .object
}

fn test_history_storage_outlives_temporary_script_allocation() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := history_binding_fixture()!
	document.enable_native_storage()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut temporary := platform.begin_thread_scratch('History caller')
	source := r'history.pushState({text:"Санкт-Петербург 😀",nested:{value:42}},"","/map");true'.clone()
	assert runtime.evaluate_host(source)! == 'true'
	temporary.finish()
	gc_collect()
	assert runtime.evaluate_host('history.state.text==="Санкт-Петербург 😀"&&history.state.nested.value===42&&history.length===2')! == 'true'
	assert document.url.serialize() == 'https://history.example/map'
	assert document.history().state.kind == .object
	$if prealloc {
		storage := document.native_storage()
		assert storage.arena.contains(document.url.value.str)
	}
}
