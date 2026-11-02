module browserjs

import dom
import html
import libjs

fn C.JSGarbageCollect(context voidptr)

fn string_callback_native_fixture(url string) (&Runtime, &dom.Document, &html.EnvironmentSettingsObject) {
	document := html.parse_document_with_url('<!doctype html><body>Native string callbacks</body>',
		dom.URL{ value: url })
	_ = html.WindowModel.create_top_level(document, none, 'native-string-callback') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, document, settings
}

fn string_callback_native_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('typeof DataTransferItem==="function"&&typeof DataTransferItem.prototype.getAsString==="function"')! == 'true'
}

fn string_callback_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn string_callback_queue_ids() u64 {
	task := html.main_thread_event_loop().task_queue().last_added_task() or { return 0 }
	return task.id()
}

@[heap]
struct StringCallbackTaskSelection {
mut:
	tasks []&html.Task
}

fn string_callback_new_tasks(previous u64) []&html.Task {
	mut selected := &StringCallbackTaskSelection{}
	mut queue := html.main_thread_event_loop().task_queue()
	// Visit through the public selector without removing or executing tasks.
	_ = queue.take_first_runnable_matching(fn [mut selected, previous] (task &html.Task) bool {
		if task.id() > previous && task.source() == .unspecified {
			selected.tasks << task
		}
		return false
	}) or { return selected.tasks }
	return selected.tasks
}

fn string_callback_take_task(id u64) &html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [id] (candidate &html.Task) bool {
		return candidate.id() == id
	}) or { panic('missing native string callback task') }
	assert task.source() == .unspecified
	assert task.document() == none
	return task
}

fn string_callback_assert_balanced(runtime &Runtime, settings &html.EnvironmentSettingsObject) {
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
}

fn test_native_data_transfer_item_string_callback_metadata_brands_arity_and_nullable_conversion() {
	$if !darwin { return }
	mut runtime, mut document, settings := string_callback_native_fixture('https://transfer-string-metadata.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert string_callback_native_guard(runtime)!
	previous := string_callback_queue_ids()
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=DataTransferItem.prototype,d=Object.getOwnPropertyDescriptor(p,"getAsString"),method=d.value,t=new DataTransfer(),item=t.items.add("metadata","text/plain"),marker={};let gets=0,conversions=0;
 check(d.writable&&d.enumerable&&d.configurable&&method.name==="getAsString"&&method.length===1&&Function.prototype.toString.call(method).includes("[native code]")&&!Object.hasOwn(method,"prototype"),"native operation metadata");let nonconstructable=false;try{Reflect.construct(function Empty(){},[],method)}catch(error){nonconstructable=error instanceof TypeError}check(nonconstructable,"operation is not constructable");
 const argument=new Proxy({handleEvent(){throw marker},[Symbol.toPrimitive](){conversions++;throw marker}},{get(){gets++;throw marker},getPrototypeOf(){gets++;throw marker}}),proxy=new Proxy(item,{get(){gets++;throw marker},getPrototypeOf(){gets++;throw marker}});
 for(const receiver of [Object.create(p),proxy,t,t.items,{},null,undefined,1])for(const args of [[],[argument]]){let rejected=false;try{Reflect.apply(method,receiver,args)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransferItem"}check(rejected,"receiver brand precedes arity and callback conversion")}
 let missing=false;try{item.getAsString()}catch(error){missing=error instanceof TypeError&&error.message==="getAsString() needs one argument"}check(missing,"required nullable callback arity");
 for(const value of [false,0,1n,"callback",Symbol("callback"),[],{},Object.create(Function.prototype),argument]){let rejected=false;try{item.getAsString(value)}catch(error){rejected=error instanceof TypeError}check(rejected,"callback conversion rejects noncallables without author conversion")}
 check(item.getAsString(null,argument)===undefined&&item.getAsString(undefined,argument)===undefined&&gets===0&&conversions===0,"explicit null and undefined return without extra argument access");return true;
})()')! == 'true'
	assert string_callback_new_tasks(previous).len == 0
	string_callback_assert_balanced(runtime, settings)
}

fn test_native_data_transfer_item_string_callback_queues_raw_utf16_snapshot_with_owner_context() {
	$if !darwin { return }
	mut runtime, mut document, settings := string_callback_native_fixture('https://transfer-string-snapshot.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert string_callback_native_guard(runtime)!
	owner := voidptr(runtime)
	runtime.define_value_host_function('__stringCallbackContext', fn [owner, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		valid := settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, valid)
	})!
	previous := string_callback_queue_ids()
	assert runtime.evaluate_host(r'(()=>{
 const t=new DataTransfer(),raw="a\ud800\u0000\udc00\ud83d\ude00\udfff",item=t.items.add(raw,"text/plain"),owner=globalThis,check=(condition,label)=>{if(!condition)throw new Error(label)};globalThis.stringCallbackTransfer=t;globalThis.stringCallbackItem=item;globalThis.stringCallbackResults=[];
 check(item.getAsString(function(value){"use strict";stringCallbackResults.push(["strict",value===raw,arguments.length===1,this===undefined,__stringCallbackContext()]);})===undefined,"strict callback request result");
 check(item.getAsString(function(value){stringCallbackResults.push(["sloppy",value===raw,arguments.length===1,this===owner,__stringCallbackContext()]);},{get then(){throw 0}})===undefined,"sloppy callback request result");
 check(stringCallbackResults.length===0,"callbacks are asynchronous");t.setData("text/plain","replacement");check(item.kind==="","setData disables original item");t.items.remove(0);return true;
})()')! == 'true'
	tasks := string_callback_new_tasks(previous)
	assert tasks.len == 2
	mut transfer := runtime.native_data_transfer(runtime.evaluate_host_value('stringCallbackTransfer')!)!
	transfer.disassociate_with_drag_data_store()
	mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
	realm.can_run = false
	defer { realm.can_run = true }
	assert html.can_run_script_for_settings(settings) == .do_not_run
	for task in tasks {
		string_callback_take_task(task.id()).execute()
		string_callback_assert_balanced(runtime, settings)
	}
	realm.can_run = true
	assert runtime.evaluate_host('stringCallbackResults.length===2&&stringCallbackResults[0][0]==="strict"&&stringCallbackResults[1][0]==="sloppy"&&stringCallbackResults.every(result=>result.slice(1).every(Boolean))&&stringCallbackTransfer.items.length===0&&stringCallbackItem.kind===""')! == 'true'
	assert runtime.take_document_state_dirty()
	string_callback_assert_balanced(runtime, settings)
}

fn test_native_data_transfer_item_string_callback_modes_kind_and_disabled_gates_follow_conversion() {
	$if !darwin { return }
	mut runtime, mut document, settings := string_callback_native_fixture('https://transfer-string-modes.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert string_callback_native_guard(runtime)!
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string_from_code_units([u16(0xdfff), 0, 0xd800])))
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('text/plain'),
		[u8(1)], libjs.utf16_string('file.txt')))
	mut transfer := html.DataTransfer.create(store)
	string_callback_native_export(mut runtime, '__stringModeTransfer', runtime.javascript_data_transfer(transfer)!)!
	previous := string_callback_queue_ids()
	assert runtime.evaluate_host(r'(()=>{const list=__stringModeTransfer().items;globalThis.stringModeText=list[0];globalThis.stringModeFile=list[1];globalThis.stringModeValues=[];globalThis.stringModeCallback=function(value){stringModeValues.push(value)};return stringModeFile.getAsString(stringModeCallback)===undefined&&stringModeText.getAsString(null)===undefined&&stringModeValues.length===0})()')! == 'true'
	assert string_callback_new_tasks(previous).len == 0
	for mode in [html.DragDataStoreMode.read_write, .read_only] {
		store.set_mode(mode)
		assert runtime.evaluate_host('stringModeText.getAsString(stringModeCallback)===undefined&&stringModeValues.length===0')! == 'true'
	}
	store.set_mode(.protected)
	assert runtime.evaluate_host(r'(()=>{let invalid=false;try{stringModeText.getAsString({get handleEvent(){throw 0}})}catch(error){invalid=error instanceof TypeError}return invalid&&stringModeText.getAsString(stringModeCallback)===undefined&&stringModeFile.getAsString(stringModeCallback)===undefined&&stringModeValues.length===0})()')! == 'true'
	tasks := string_callback_new_tasks(previous)
	assert tasks.len == 2
	store.set_mode(.read_write)
	assert runtime.evaluate_host('__stringModeTransfer().items.remove(0)===undefined&&stringModeText.kind===""&&stringModeText.getAsString(stringModeCallback)===undefined')! == 'true'
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host(r'(()=>{let missing=false,invalid=false;try{stringModeText.getAsString()}catch(error){missing=error instanceof TypeError}try{stringModeText.getAsString(1)}catch(error){invalid=error instanceof TypeError}return missing&&invalid&&stringModeText.getAsString(undefined)===undefined&&stringModeFile.getAsString(stringModeCallback)===undefined})()')! == 'true'
	assert string_callback_new_tasks(previous).len == 2
	for task in tasks {
		string_callback_take_task(task.id()).execute()
	}
	assert runtime.evaluate_host(r'stringModeValues.length===2&&stringModeValues.every(value=>value==="\udfff\u0000\ud800")')! == 'true'
	string_callback_assert_balanced(runtime, settings)
}

@[heap]
struct StringCallbackNativeCloseObservation {
mut:
	calls int
}

fn test_native_data_transfer_item_string_callback_callable_proxies_abrupt_results_and_closed_runtime() {
	$if !darwin { return }
	mut runtime, mut document, settings := string_callback_native_fixture('https://transfer-string-proxies.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert string_callback_native_guard(runtime)!
	reports_before := settings.realm().reported_exceptions.len
	assert runtime.evaluate_host(r'(()=>{
 const t=new DataTransfer(),item=t.items.add("payload","text/plain"),marker={};globalThis.stringProxyItem=item;globalThis.stringProxyCalls=[];globalThis.stringProxyGets=0;globalThis.stringProxyThenReads=0;
 const originalApply=Reflect.apply,callable=new Proxy(function(value){"use strict";stringProxyCalls.push(["body",value==="payload",arguments.length===1,this===undefined]);return {get then(){stringProxyThenReads++;throw marker}}},{apply(target,receiver,args){stringProxyCalls.push(["apply",receiver===undefined,args.length===1,args[0]==="payload"]);return originalApply(target,receiver,args)},get(){stringProxyGets++;throw marker}});
 const revoked=Proxy.revocable(function(){throw marker},{});revoked.revoke();globalThis.stringProxyCallable=callable;globalThis.stringProxyRevoked=revoked.proxy;globalThis.stringProxyThrowing=function(value){stringProxyCalls.push(["throw",value==="payload"]);throw marker};globalThis.stringProxyAfter=function(value){stringProxyCalls.push(["after",value==="payload"]);return Promise.reject(marker).catch(()=>undefined)};return true;
})()')! == 'true'
	baseline_roots := runtime.protected_values_.len
	previous := string_callback_queue_ids()
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},item=stringProxyItem;
 check(item.getAsString(stringProxyCallable)===undefined&&stringProxyCalls.length===0&&stringProxyGets===0,"callable Proxy conversion and deferred call without property reads");
 check(item.getAsString(stringProxyRevoked)===undefined,"revoked callable remains callable during conversion");
 check(item.getAsString(stringProxyThrowing)===undefined,"callback abrupt completion is deferred");
 check(item.getAsString(stringProxyAfter)===undefined,"later callback remains queued");
 globalThis.TypeError=function AuthorTypeError(){throw 0};Reflect.apply=function AuthorApply(){throw 0};Function.prototype.call=function AuthorCall(){throw 0};return stringProxyCalls.length===0&&stringProxyGets===0;
})()')! == 'true'
	assert runtime.protected_values_.len >= baseline_roots + 4
	tasks := string_callback_new_tasks(previous)
	assert tasks.len == 4
	for task in tasks {
		string_callback_take_task(task.id()).execute()
		string_callback_assert_balanced(runtime, settings)
	}
	assert runtime.evaluate_host('stringProxyCalls.length===4&&stringProxyCalls.map(value=>value[0]).join(",")==="apply,body,throw,after"&&stringProxyCalls.every(value=>value.slice(1).every(Boolean))&&stringProxyGets===0&&stringProxyThenReads===0')! == 'true'
	assert settings.realm().reported_exceptions.len == reports_before
	assert runtime.protected_values_.len == baseline_roots
	repeated_previous := string_callback_queue_ids()
	assert runtime.evaluate_host('for(let index=0;index<12;index++)stringProxyItem.getAsString(stringProxyThrowing);stringProxyCalls.length===4')! == 'true'
	repeated_tasks := string_callback_new_tasks(repeated_previous)
	assert repeated_tasks.len == 12
	for task in repeated_tasks {
		string_callback_take_task(task.id()).execute()
		string_callback_assert_balanced(runtime, settings)
	}
	assert runtime.evaluate_host('stringProxyCalls.length===16&&stringProxyGets===0&&stringProxyThenReads===0')! == 'true'
	assert runtime.protected_values_.len == baseline_roots
	assert settings.realm().reported_exceptions.len == reports_before
	mut closing, mut closing_document, closing_settings := string_callback_native_fixture('https://transfer-string-close.example/')
	defer {
		closing.close()
		closing_document.finalize()
	}
	mut observed := &StringCallbackNativeCloseObservation{}
	closing.define_value_host_function('__stringClosedCallback', fn [mut observed, closing] (_ voidptr, _ []voidptr) !voidptr {
		observed.calls++
		return C.vox_jsc_JSValueMakeUndefined(closing.context)
	})!
	callback := closing.evaluate_host_value('globalThis.stringCloseItem=new DataTransfer().items.add("close","text/plain");globalThis.stringCloseCallback=function(){__stringClosedCallback()};stringCloseCallback')!
	roots_before := closing.protected_values_.filter(it == callback).len
	close_previous := string_callback_queue_ids()
	assert closing.evaluate_host('stringCloseItem.getAsString(stringCloseCallback)===undefined')! == 'true'
	assert closing.protected_values_.filter(it == callback).len > roots_before
	close_tasks := string_callback_new_tasks(close_previous)
	assert close_tasks.len == 1
	assert closing.evaluate_host('stringCloseCallback=null;stringCloseItem=null;true')! == 'true'
	C.JSGarbageCollect(closing.context)
	string_callback_assert_balanced(closing, closing_settings)
	closing.close()
	assert closing.protected_values_.len == 0
	string_callback_take_task(close_tasks[0].id()).execute()
	assert observed.calls == 0
	assert closing.protected_values_.len == 0
	assert closing_settings.realm().script_execution_depth == 0
	assert closing_settings.realm().callback_execution_depth == 0
}
