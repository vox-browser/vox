module main

import browserjs
import dom
import html
import libjs
import page
import time

fn transfer_entry_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn transfer_entry_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn transfer_entry_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn transfer_entry_owner_event(document &dom.Document, transfer &html.DataTransfer) &html.DragEvent {
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

// Only the public availability guard needs the new operation and entry binding.
// All V fixtures and native adapters compile on this translation's parent.
fn transfer_entry_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof FileSystemEntry==="function"&&typeof DataTransferItem==="function"&&typeof DataTransferItem.prototype.webkitGetAsEntry==="function"&&DataTransferItem.prototype.webkitGetAsEntry.length===0&&Function.prototype.toString.call(DataTransferItem.prototype.webkitGetAsEntry).includes("[native code]")')! == 'true'
}

fn transfer_entry_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner_handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__transferEntryOwnerContext', fn [settings, owner_handle, actual_true] (_ voidptr, arguments []voidptr) !voidptr {
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

fn test_owner_webkit_get_as_entry_uses_native_file_records_and_fresh_readonly_snapshots() {
	$if !darwin { return }
	mut owner, mut document := transfer_entry_owner_document('https://data-transfer-entry-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.entryAudio=document.createElement("audio");entryAudio.id="entry-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert transfer_entry_owner_guard(runtime)!
	transfer_entry_owner_probe(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	mut list := transfer.items()
	transfer_entry_owner_export(mut runtime, '__transferEntryOwnerTransfer', runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.entryTransfer=__transferEntryOwnerTransfer();globalThis.entryList=entryTransfer.items;globalThis.entryOriginal={File,Entry:FileSystemEntry};globalThis.entryOperation=DataTransferItem.prototype.webkitGetAsEntry;
globalThis.entryGetters={};for(const key of ["isFile","isDirectory","name"])entryGetters[key]=Object.getOwnPropertyDescriptor(entryOriginal.Entry.prototype,key).get;
globalThis.entryInput=new File([new Uint8Array([0,255,65])],"\u03a9\u0000\ud800\ud83d\ude00.txt",{type:"TEXT/PLAIN",lastModified:7});globalThis.entryText=entryList.add("text\ud800\u0000","text/plain");globalThis.entryFile=entryList.add(entryInput);
globalThis.entryPoisonCalls=0;globalThis.entryPoisonMarker={};globalThis.entryIgnored={[Symbol.toPrimitive](){entryPoisonCalls++;throw entryPoisonMarker}};
for(const key of ["name","type","size","lastModified",Symbol.toPrimitive])Object.defineProperty(entryInput,key,{get(){entryPoisonCalls++;throw entryPoisonMarker}});
for(const key of ["name","type"])Object.defineProperty(entryOriginal.File.prototype,key,{configurable:true,get(){entryPoisonCalls++;throw entryPoisonMarker}});
globalThis.File=globalThis.FileSystemEntry=function(){entryPoisonCalls++;throw entryPoisonMarker};
globalThis.entryChecks=[];globalThis.entrySaved=[];globalThis.entrySnapshots=[];globalThis.entryOrder=[];globalThis.entryStage=0;globalThis.entryTrusted=true;
for(const player of [video,entryAudio]){
 player.addEventListener("drop",function(event){entryOrder.push("before:"+player.id);entryChecks.push(this===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("drop",function(event){
  entryOrder.push("entries:"+player.id);entrySaved.push(event);
  entryChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event instanceof DragEvent&&event.isTrusted===entryTrusted&&event.view===window&&event.detail===7&&event.dataTransfer===entryTransfer&&event.dataTransfer.items===entryList&&__transferEntryOwnerContext());
  const first=entryFile.webkitGetAsEntry(entryIgnored,Symbol("ignored")),second=entryOperation.call(entryFile,entryIgnored);entrySnapshots.push(first,second);
  entryChecks.push(first!==second&&first instanceof entryOriginal.Entry&&Object.getPrototypeOf(first)===entryOriginal.Entry.prototype&&first.isFile===true&&first.isDirectory===false&&first.name==="\u03a9\u0000\ufffd\ud83d\ude00.txt"&&second.name===first.name&&entryText.webkitGetAsEntry(entryIgnored)===null&&entryPoisonCalls===0);
  for(const key of ["isFile","isDirectory","name"]){
   const descriptor=Object.getOwnPropertyDescriptor(entryOriginal.Entry.prototype,key),getter=entryGetters[key];
   entryChecks.push(descriptor.get===getter&&descriptor.set===undefined&&descriptor.enumerable&&descriptor.configurable&&getter.length===0&&Function.prototype.toString.call(getter).includes("[native code]")&&getter.call(first)===first[key]);
   for(const receiver of [null,undefined,{},Object.create(entryOriginal.Entry.prototype),new Proxy(first,{get(){entryPoisonCalls++;throw entryPoisonMarker}})]){let rejected=false;try{getter.call(receiver)}catch(error){rejected=error instanceof TypeError}entryChecks.push(rejected)}
   let readonly=false;try{(function(){"use strict";first[key]="changed"})()}catch(error){readonly=error instanceof TypeError}entryChecks.push(readonly);
   let notConstructor=false;try{new getter()}catch(error){notConstructor=error instanceof TypeError}entryChecks.push(notConstructor);
  }
  for(const receiver of [null,undefined,{},Object.create(DataTransferItem.prototype),new Proxy(entryFile,{get(){entryPoisonCalls++;throw entryPoisonMarker}})]){let rejected=false;try{entryOperation.call(receiver,entryIgnored)}catch(error){rejected=error instanceof TypeError}entryChecks.push(rejected)}
  let illegal=false;try{new entryOriginal.Entry()}catch(error){illegal=error instanceof TypeError}entryChecks.push(illegal);
  entryChecks.push(first.fullPath===undefined&&first.filesystem===undefined&&first.getParent===undefined&&!["fullPath","filesystem","getParent"].some(key=>key in entryOriginal.Entry.prototype)&&entryPoisonCalls===0);
  entryChecks.push(entryStage===0?entryList.length===2&&entryList[1]===entryFile:entryList.length===1&&entryList[0]===entryFile&&entryText.kind==="");
  event.preventDefault();result.textContent=player.id+":"+entrySnapshots.length;
 });
 player.addEventListener("drop",function(event){entryOrder.push("after:"+player.id);entryChecks.push(event.defaultPrevented&&event.currentTarget===player&&window.event===event)});
}
document.body.appendChild(entryAudio);void entryAudio.paused;0
')!
	input := runtime.native_file(runtime.evaluate_host_value('entryInput')!)!
	assert input.raw_bytes() == [u8(0), 255, 65]
	assert input.name_utf16().code_units() == [u16(0x03a9), 0, 0xfffd, 0xd83d, 0xde00, u16(`.`), u16(`t`), u16(`x`), u16(`t`)]
	text_item := list.item(0)?
	file_item := list.item(1)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('entryText')!)!) == voidptr(text_item)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('entryFile')!)!) == voidptr(file_item)
	assert transfer.drag_data(1).file_name_utf16().code_units() == input.name_utf16().code_units()
	drag := transfer_entry_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) }, event)
	wrapper := runtime.evaluate_host_value('entrySaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.default_prevented() && drag.data_transfer()? == transfer
	assert runtime.evaluate_host('entryChecks.every(Boolean)&&entrySnapshots.length===2&&entrySaved[0].currentTarget===null&&window.event===undefined&&entryPoisonCalls===0')! == 'true'
	mut app := transfer_entry_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:2'
	list.remove(0)!
	assert text_item.mode() == none && voidptr(list.item(0)?) == voidptr(file_item)
	store.mode = .read_only
	runtime.evaluate_host('entryStage=1;entryTrusted=false;0')!
	assert runtime.evaluate_host('(()=>{const event=entrySaved[0],stamp=event.timeStamp;return entryAudio.dispatchEvent(event)===false&&entrySaved[1]===event&&!event.isTrusted&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&entryChecks.every(Boolean)&&entryPoisonCalls===0})()')! == 'true'
	assert runtime.native_event(runtime.evaluate_host_value('entrySaved[1]')!)! == event
	assert !event.is_trusted() && event.time_stamp() == stamp && list.length() == 1
	assert runtime.evaluate_host(r'new Set(entrySnapshots).size===4&&entrySnapshots.every(entry=>entry.isFile&&!entry.isDirectory&&entry.name==="\u03a9\u0000\ufffd\ud83d\ude00.txt")')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'entry-audio:4'
	store.mode = .protected
	assert runtime.evaluate_host(r'entryFile.webkitGetAsEntry(entryIgnored)===null&&entryText.webkitGetAsEntry(entryIgnored)===null&&entryFile.kind==="file"&&entrySnapshots.every(entry=>entryGetters.name.call(entry)==="\u03a9\u0000\ufffd\ud83d\ude00.txt"&&entryGetters.isFile.call(entry)&&!entryGetters.isDirectory.call(entry))&&entryPoisonCalls===0')! == 'true'
	store.mode = .read_write
	list.remove(0)!
	assert file_item.mode() == none && list.length() == 0
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host(r'entryFile.webkitGetAsEntry(entryIgnored)===null&&entryFile.kind===""&&entryList.length===0&&entrySnapshots.every(entry=>entry.name==="\u03a9\u0000\ufffd\ud83d\ude00.txt"&&entry.isFile&&!entry.isDirectory)&&entryChecks.every(Boolean)&&entryPoisonCalls===0&&entryOrder.join(",")==="before:video,entries:video,after:video,before:entry-audio,entries:entry-audio,after:entry-audio"')! == 'true'
	for id in ['video', 'entry-audio'] {
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
	}
	assert runtime.evaluate_host('entrySaved.length===2')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
}

fn test_owner_webkit_get_as_entry_preserves_raw_store_names_and_readable_mode_gates() {
	$if !darwin { return }
	mut owner, mut document := transfer_entry_owner_document('http://data-transfer-entry-gates-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.entryGateAudio=document.createElement("audio");entryGateAudio.id="entry-gate-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert transfer_entry_owner_guard(runtime)!
	transfer_entry_owner_probe(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	text_item := transfer.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'), libjs.utf16_string('text')))
	name_units := [u16(`r`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00, u16(`z`)]
	file_item := transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('text/plain'), [u8(0), 255], libjs.utf16_string_from_code_units(name_units)))
	directory_named_item := transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('application/octet-stream'), [u8(65)], libjs.utf16_string('directory/')))
	mut list := transfer.items()
	transfer_entry_owner_export(mut runtime, '__transferEntryGateTransfer', runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.entryGateTransfer=__transferEntryGateTransfer();globalThis.entryGateList=entryGateTransfer.items;globalThis.entryGateText=entryGateList[0];globalThis.entryGateFile=entryGateList[1];globalThis.entryGateDirectoryNamed=entryGateList[2];globalThis.entryGateChecks=[];globalThis.entryGateSaved=[];globalThis.entryGateSnapshots=[];globalThis.entryGatePhase="protected";globalThis.entryGateTrusted=true;globalThis.entryGateCoercions=0;globalThis.entryGateIgnored=new Proxy({},{get(){entryGateCoercions++;throw new Error("Extra arguments must be ignored")}});
for(const player of [video,entryGateAudio])player.addEventListener("drop",function(event){
 entryGateSaved.push(event);entryGateChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event instanceof DragEvent&&event.view===window&&event.detail===7&&event.isTrusted===entryGateTrusted&&event.dataTransfer===entryGateTransfer&&event.dataTransfer.items===entryGateList&&__transferEntryOwnerContext());
 const entry=entryGateFile.webkitGetAsEntry(entryGateIgnored),directoryNamed=entryGateDirectoryNamed.webkitGetAsEntry(entryGateIgnored);entryGateChecks.push(entryGateText.webkitGetAsEntry(entryGateIgnored)===null&&entryGateCoercions===0);
 if(entryGatePhase==="read-only"){
  entryGateSnapshots.push(entry,directoryNamed);entryGateChecks.push(entry instanceof FileSystemEntry&&entry.isFile&&!entry.isDirectory&&entry.name==="r\ud800\u0000\udc00\ud83d\ude00z"&&directoryNamed instanceof FileSystemEntry&&directoryNamed.isFile&&!directoryNamed.isDirectory&&directoryNamed.name==="directory/"&&entryGateFile.kind==="file"&&entryGateList[1]===entryGateFile);
 }else entryGateChecks.push(entry===null&&directoryNamed===null&&entryGateSnapshots.length===(entryGatePhase==="protected"?0:2));
 event.preventDefault();result.textContent=player.id+":"+entryGatePhase;
});document.body.appendChild(entryGateAudio);void entryGateAudio.paused;0
')!
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('entryGateFile')!)!) == voidptr(file_item)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('entryGateDirectoryNamed')!)!) == voidptr(directory_named_item)
	assert transfer.drag_data(1).file_name_utf16().code_units() == name_units
	store.mode = .protected
	drag := transfer_entry_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) }, event)
	wrapper := runtime.evaluate_host_value('entryGateSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.default_prevented()
	assert runtime.evaluate_host('entryGateChecks.every(Boolean)&&entryGateSaved[0].currentTarget===null&&window.event===undefined&&entryGateSnapshots.length===0')! == 'true'
	mut app := transfer_entry_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:protected'
	store.mode = .read_only
	runtime.evaluate_host('entryGatePhase="read-only";entryGateTrusted=false;0')!
	assert runtime.evaluate_host('(()=>{const event=entryGateSaved[0],stamp=event.timeStamp;return entryGateAudio.dispatchEvent(event)===false&&entryGateSaved[1]===event&&!event.isTrusted&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&entryGateChecks.every(Boolean)})()')! == 'true'
	assert runtime.native_event(runtime.evaluate_host_value('entryGateSaved[1]')!)! == event
	assert !event.is_trusted() && event.time_stamp() == stamp
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'entry-gate-audio:read-only'
	store.mode = .read_write
	list.remove(0)!
	assert text_item.mode() == none && voidptr(list.item(0)?) == voidptr(file_item)
	assert transfer.drag_data(0).file_name_utf16().code_units() == name_units
	assert runtime.evaluate_host(r'entryGateFile===entryGateList[0]&&entryGateFile.webkitGetAsEntry().name==="r\ud800\u0000\udc00\ud83d\ude00z"&&entryGateDirectoryNamed===entryGateList[1]&&entryGateDirectoryNamed.webkitGetAsEntry().isFile')! == 'true'
	list.remove(0)!
	assert file_item.mode() == none && voidptr(list.item(0)?) == voidptr(directory_named_item)
	assert runtime.evaluate_host(r'entryGateFile.webkitGetAsEntry(entryGateIgnored)===null&&entryGateText.webkitGetAsEntry(entryGateIgnored)===null&&entryGateDirectoryNamed.webkitGetAsEntry().name==="directory/"&&entryGateSnapshots[0].name==="r\ud800\u0000\udc00\ud83d\ude00z"&&entryGateSnapshots[1].name==="directory/"')! == 'true'
	transfer.disassociate_with_drag_data_store()
	runtime.evaluate_host('entryGatePhase="disassociated";0')!
	assert runtime.evaluate_host('(()=>{const event=entryGateSaved[0],stamp=event.timeStamp;return video.dispatchEvent(event)===false&&entryGateSaved[2]===event&&!event.isTrusted&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&entryGateChecks.every(Boolean)&&entryGateList.length===0&&entryGateFile.kind===""&&entryGateDirectoryNamed.kind===""&&entryGateCoercions===0})()')! == 'true'
	assert runtime.native_event(runtime.evaluate_host_value('entryGateSaved[2]')!)! == event
	assert directory_named_item.mode() == none && list.length() == 0
	assert runtime.evaluate_host(r'entryGateSnapshots.length===2&&entryGateSnapshots[0].isFile&&!entryGateSnapshots[0].isDirectory&&entryGateSnapshots[0].name==="r\ud800\u0000\udc00\ud83d\ude00z"&&entryGateSnapshots[1].isFile&&!entryGateSnapshots[1].isDirectory&&entryGateSnapshots[1].name==="directory/"')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:disassociated'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context() && settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	runtime.close()
	assert !runtime.take_document_state_dirty()
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
