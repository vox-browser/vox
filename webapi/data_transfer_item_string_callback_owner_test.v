module main

import browserjs
import dom
import html
import page
import time

fn transfer_string_callback_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn transfer_string_callback_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn transfer_string_callback_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn transfer_string_callback_owner_event(document &dom.Document, transfer &html.DataTransfer) &html.DragEvent {
	return html.DragEvent.create('drop', html.DragEventInit{
		MouseEventInit: dom.MouseEventInit{
			EventModifierInit: dom.EventModifierInit{
				UIEventInit: dom.UIEventInit{
					EventInit: dom.EventInit{
						bubbles:    true
						cancelable: true
						composed:   true
					}
					view:   voidptr(document.get_window() or { panic('Owner document needs its Window') })
					detail: 7
				}
			}
		}
		data_transfer: transfer
	}, 19.75, 22.25, 1.75, 2.25)
}

// All entry points in these fixtures already exist on the feature's parent.
// Only this guard requires the new public callback operation.
fn transfer_string_callback_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof DataTransferItem==="function"&&typeof DataTransferItem.prototype.getAsString==="function"&&DataTransferItem.prototype.getAsString.length===1&&Function.prototype.toString.call(DataTransferItem.prototype.getAsString).includes("[native code]")')! == 'true'
}

fn transfer_string_callback_owner_task_cutoff() u64 {
	task := html.main_thread_event_loop().task_queue().last_added_task() or { return 0 }
	return task.id()
}

fn transfer_string_callback_owner_run_tasks(cutoff u64) int {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [cutoff] (task &html.Task) bool {
			return task.source() == .unspecified && task.id() > cutoff
		}) or { break }
		assert task.source() == .unspecified && task.document() == none && task.is_runnable()
		task.execute()
		count++
	}
	return count
}

fn transfer_string_callback_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner_handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__transferStringCallbackOwnerContext', fn [settings, owner_handle, actual_true] (_ voidptr, arguments []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(owner_handle) }
		assert arguments.len == 0
		assert settings.realm().script_execution_depth > 0
		assert settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn test_owner_get_as_string_callbacks_keep_utf16_snapshots_through_drag_redispatch_and_store_disable() {
	$if !darwin { return }
	mut owner, mut document := transfer_string_callback_owner_document('https://data-transfer-string-callback-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.stringCallbackAudio=document.createElement("audio");stringCallbackAudio.id="string-callback-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert transfer_string_callback_owner_guard(runtime)!
	transfer_string_callback_owner_probe(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	list := transfer.items()
	transfer_string_callback_owner_export(mut runtime, '__transferStringCallbackOwnerTransfer', runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.stringCallbackTransfer=__transferStringCallbackOwnerTransfer();globalThis.stringCallbackList=stringCallbackTransfer.items;
globalThis.stringCallbackType="X\ud800\u0000\udc00";globalThis.stringCallbackFirst="A\udc00\u0000\ud800\ud83d\ude00";globalThis.stringCallbackSecond="B\ud800\u0000\udfff";globalThis.stringCallbackThird="C\udfff\u0000\ud800";
globalThis.stringCallbackText=stringCallbackList.add(stringCallbackFirst,stringCallbackType);globalThis.stringCallbackFile=stringCallbackList.add(new File([new Uint8Array([0,255,65])],"actual.bin",{type:"application/octet-stream",lastModified:7}));
globalThis.stringCallbackChecks=[];globalThis.stringCallbackSaved=[];globalThis.stringCallbackOrder=[];globalThis.stringCallbackCalls=[];globalThis.stringCallbackThenReads=0;globalThis.stringCallbackMarker={};globalThis.stringCallbackStage=0;globalThis.stringCallbackTrusted=true;
for(const player of [video,stringCallbackAudio]){
 player.addEventListener("drop",function(event){stringCallbackOrder.push("before:"+player.id);stringCallbackChecks.push(this===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("drop",function(event){
  stringCallbackOrder.push("queue:"+player.id);stringCallbackSaved.push(event);
  stringCallbackChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event instanceof DragEvent&&event.view===window&&event.detail===7&&event.isTrusted===stringCallbackTrusted&&event.dataTransfer===stringCallbackTransfer&&event.dataTransfer.items===stringCallbackList);
  if(stringCallbackStage===0){
   stringCallbackChecks.push(stringCallbackText.getAsString(function(data){"use strict";stringCallbackChecks.push(this===undefined&&arguments.length===1&&data===stringCallbackFirst&&__transferStringCallbackOwnerContext()&&window.event===undefined);stringCallbackCalls.push("strict");result.textContent="callbacks:"+stringCallbackCalls.length;return {get then(){stringCallbackThenReads++;throw stringCallbackMarker}}})===undefined);
   stringCallbackTransfer.setData(stringCallbackText.type,stringCallbackSecond);globalThis.stringCallbackSecondText=stringCallbackList[1];stringCallbackChecks.push(stringCallbackText.kind===""&&stringCallbackSecondText!==stringCallbackText&&stringCallbackList[0]===stringCallbackFile);
   stringCallbackChecks.push(stringCallbackSecondText.getAsString(function(data){stringCallbackChecks.push(this===window&&arguments.length===1&&data===stringCallbackSecond&&__transferStringCallbackOwnerContext()&&window.event===undefined);stringCallbackCalls.push("sloppy");result.textContent="callbacks:"+stringCallbackCalls.length;return {get then(){stringCallbackThenReads++;throw stringCallbackMarker}}})===undefined);
   stringCallbackChecks.push(stringCallbackSecondText.getAsString(function(data){"use strict";stringCallbackChecks.push(this===undefined&&arguments.length===1&&data===stringCallbackSecond&&__transferStringCallbackOwnerContext());stringCallbackCalls.push("throw");result.textContent="callbacks:"+stringCallbackCalls.length;throw stringCallbackMarker})===undefined);
  }else stringCallbackChecks.push(stringCallbackThirdText===stringCallbackList[1]&&stringCallbackSecondText.kind===""&&stringCallbackThirdText.getAsString(function(data){"use strict";stringCallbackChecks.push(this===undefined&&arguments.length===1&&data===stringCallbackThird&&__transferStringCallbackOwnerContext()&&window.event===undefined);stringCallbackCalls.push("redispatch");result.textContent="callbacks:"+stringCallbackCalls.length})===undefined);
  stringCallbackChecks.push(stringCallbackFile.getAsString(()=>{throw new Error("File callback was queued")})===undefined&&stringCallbackCalls.length===0);
  event.preventDefault();result.textContent=player.id+":queued";
 });
 player.addEventListener("drop",function(event){stringCallbackOrder.push("after:"+player.id);stringCallbackChecks.push(event.defaultPrevented&&event.currentTarget===player&&window.event===event&&stringCallbackCalls.length===0)});
}
document.body.appendChild(stringCallbackAudio);void stringCallbackAudio.paused;0
')!
	text_item := list.item(0)?
	file_item := list.item(1)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('stringCallbackText')!)!) == voidptr(text_item)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('stringCallbackFile')!)!) == voidptr(file_item)
	assert transfer.drag_data(0).text_data_utf16().code_units() == [u16(`A`), 0xdc00, 0, 0xd800, 0xd83d, 0xde00]
	cutoff := transfer_string_callback_owner_task_cutoff()
	drag := transfer_string_callback_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) }, event)
	wrapper := runtime.evaluate_host_value('stringCallbackSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.default_prevented() && drag.data_transfer()? == transfer
	assert runtime.evaluate_host('stringCallbackChecks.every(Boolean)&&stringCallbackCalls.length===0&&stringCallbackSaved[0].currentTarget===null&&window.event===undefined')! == 'true'
	assert text_item.mode() == none && voidptr(list.item(0)?) == voidptr(file_item)
	second_text_item := list.item(1)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('stringCallbackSecondText')!)!) == voidptr(second_text_item)
	assert transfer.drag_data(1).text_data_utf16().code_units() == [u16(`B`), 0xd800, 0, 0xdfff]
	mut app := transfer_string_callback_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:queued'
	runtime.evaluate_host('stringCallbackTransfer.setData(stringCallbackSecondText.type,stringCallbackThird);globalThis.stringCallbackThirdText=stringCallbackList[1];stringCallbackStage=1;stringCallbackTrusted=false;0')!
	third_text_item := list.item(1)?
	assert second_text_item.mode() == none
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('stringCallbackThirdText')!)!) == voidptr(third_text_item)
	store.mode = .read_only
	assert runtime.evaluate_host('(()=>{const event=stringCallbackSaved[0],stamp=event.timeStamp;return stringCallbackAudio.dispatchEvent(event)===false&&stringCallbackSaved[1]===event&&!event.isTrusted&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&stringCallbackChecks.every(Boolean)&&stringCallbackCalls.length===0})()')! == 'true'
	assert runtime.native_event(runtime.evaluate_host_value('stringCallbackSaved[1]')!)! == event
	assert !event.is_trusted() && event.time_stamp() == stamp
	assert transfer.drag_data(1).text_data_utf16().code_units() == [u16(`C`), 0xdfff, 0, 0xd800]
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'string-callback-audio:queued'
	store.mode = .protected
	assert runtime.evaluate_host('stringCallbackThirdText.kind==="string"&&stringCallbackTransfer.getData(stringCallbackType)===""&&stringCallbackCalls.length===0')! == 'true'
	store.mode = .read_write
	list.remove(1)!
	assert third_text_item.mode() == none && voidptr(list.item(0)?) == voidptr(file_item)
	transfer.disassociate_with_drag_data_store()
	assert list.length() == 0 && file_item.mode() == none
	assert runtime.evaluate_host('stringCallbackText.kind===""&&stringCallbackSecondText.kind===""&&stringCallbackThirdText.kind===""&&stringCallbackFile.kind===""&&stringCallbackCalls.length===0')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner.set_is_scripting_enabled(false)
	defer { owner.set_is_scripting_enabled(true) }
	assert html.can_run_script_for_settings(settings) == .do_not_run
	assert transfer_string_callback_owner_run_tasks(cutoff) == 4
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('stringCallbackChecks.every(Boolean)&&stringCallbackCalls.join(",")==="strict,sloppy,throw,redispatch"&&stringCallbackThenReads===0&&stringCallbackSaved.length===2&&stringCallbackOrder.join(",")==="before:video,queue:video,after:video,before:string-callback-audio,queue:string-callback-audio,after:string-callback-audio"')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'callbacks:4'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
}

fn test_owner_get_as_string_registration_gates_and_pending_close_use_real_native_tasks() {
	$if !darwin { return }
	mut owner, mut document := transfer_string_callback_owner_document('http://data-transfer-string-callback-gates-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.stringGateAudio=document.createElement("audio");stringGateAudio.id="string-gate-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert transfer_string_callback_owner_guard(runtime)!
	transfer_string_callback_owner_probe(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	list := transfer.items()
	transfer_string_callback_owner_export(mut runtime, '__transferStringCallbackGateTransfer', runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.stringGateTransfer=__transferStringCallbackGateTransfer();globalThis.stringGateList=stringGateTransfer.items;globalThis.stringGateData="read-only\ud800\u0000\udfff";globalThis.stringGateText=stringGateList.add(stringGateData,"text/plain");globalThis.stringGateFile=stringGateList.add(new File(["file bytes"],"gate.txt",{type:"text/plain"}));globalThis.stringGateChecks=[];globalThis.stringGateCalls=[];globalThis.stringGateSaved=[];globalThis.stringGatePhase="protected";globalThis.stringGateTrusted=true;
for(const player of [video,stringGateAudio])player.addEventListener("drop",function(event){
 stringGateSaved.push(event);stringGateChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event instanceof DragEvent&&event.isTrusted===stringGateTrusted&&event.dataTransfer===stringGateTransfer&&event.dataTransfer.items===stringGateList);
 stringGateChecks.push(stringGateText.getAsString(null)===undefined&&stringGateText.getAsString(undefined)===undefined&&stringGateFile.getAsString(()=>stringGateCalls.push("file"))===undefined);
 let invalid=false;try{stringGateText.getAsString({handleEvent(){throw new Error("not a FunctionStringCallback")}})}catch(error){invalid=error instanceof TypeError}stringGateChecks.push(invalid);
 stringGateChecks.push(stringGateText.getAsString(function(data){"use strict";stringGateChecks.push(this===undefined&&arguments.length===1&&data===stringGateData&&__transferStringCallbackOwnerContext());stringGateCalls.push("read-only");result.textContent="read-only callback"})===undefined&&stringGateCalls.length===0);
 event.preventDefault();result.textContent=player.id+":"+stringGatePhase;
});document.body.appendChild(stringGateAudio);void stringGateAudio.paused;0
')!
	text_item := list.item(0)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('stringGateText')!)!) == voidptr(text_item)
	cutoff := transfer_string_callback_owner_task_cutoff()
	store.mode = .protected
	drag := transfer_string_callback_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) }, event)
	assert transfer_string_callback_owner_run_tasks(cutoff) == 0
	assert runtime.evaluate_host('stringGateCalls.length===0&&stringGateChecks.every(Boolean)&&stringGateSaved[0].currentTarget===null&&window.event===undefined')! == 'true'
	mut app := transfer_string_callback_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:protected'
	store.mode = .read_only
	runtime.evaluate_host('stringGatePhase="read-only";stringGateTrusted=false;0')!
	assert runtime.evaluate_host('(()=>{const event=stringGateSaved[0],stamp=event.timeStamp;return stringGateAudio.dispatchEvent(event)===false&&stringGateSaved[1]===event&&!event.isTrusted&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&stringGateCalls.length===0&&stringGateChecks.every(Boolean)})()')! == 'true'
	assert !event.is_trusted() && event.time_stamp() == stamp
	assert runtime.native_event(runtime.evaluate_host_value('stringGateSaved[0]')!)! == event
	assert runtime.native_event(runtime.evaluate_host_value('stringGateSaved[1]')!)! == event
	store.mode = .read_write
	list.remove(0)!
	assert text_item.mode() == none
	assert runtime.evaluate_host('stringGateText.getAsString(()=>stringGateCalls.push("removed"))===undefined&&stringGateText.getAsString(null)===undefined')! == 'true'
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('stringGateText.getAsString(()=>stringGateCalls.push("disassociated"))===undefined&&stringGateFile.getAsString(()=>stringGateCalls.push("disassociated file"))===undefined&&stringGateText.kind===""&&stringGateFile.kind===""&&stringGateList.length===0&&stringGateCalls.length===0')! == 'true'
	assert transfer_string_callback_owner_run_tasks(cutoff) == 1
	assert runtime.evaluate_host('stringGateCalls.join(",")==="read-only"&&stringGateChecks.every(Boolean)')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'read-only callback'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context() && settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	close_cutoff := transfer_string_callback_owner_task_cutoff()
	assert runtime.evaluate_host('globalThis.stringCloseCalls=0;globalThis.stringCloseTransfer=new DataTransfer();globalThis.stringCloseItem=stringCloseTransfer.items.add("queued before close","text/plain");stringCloseItem.getAsString(()=>{stringCloseCalls++;throw new Error("closed runtime callback ran")})===undefined&&stringCloseCalls===0')! == 'true'
	runtime.close()
	assert transfer_string_callback_owner_run_tasks(close_cutoff) == 1
	assert !runtime.take_document_state_dirty()
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
