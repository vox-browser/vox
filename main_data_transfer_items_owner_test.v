module main

import browserjs
import dom
import html
import libjs
import page
import time

fn transfer_items_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn transfer_items_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof DataTransferItemList==="function"&&typeof DataTransferItem==="function"&&(()=>{const descriptor=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"items");return !!descriptor&&typeof descriptor.get==="function"&&Function.prototype.toString.call(descriptor.get).includes("[native code]")&&typeof DataTransferItemList.prototype.remove==="function"&&typeof DataTransferItemList.prototype.clear==="function"&&typeof DataTransferItem.prototype.getAsFile==="function"})()')! == 'true'
}

fn transfer_items_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn transfer_items_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn transfer_items_owner_event(document &dom.Document, transfer &html.DataTransfer) &html.DragEvent {
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
				ctrl_key: true
			}
			client_x: 9.75
			client_y: -2.25
			button:   1
			buttons:  2
		}
		data_transfer: transfer
	}, 19.75, 22.25, 1.75, 2.25)
}

// Native producers supply the mixed store. Public add/getAsString/entry APIs
// and physical Page/Cocoa drag routing are independent slices. Use only
// existing V adapters so these fixtures also compile on the feature's parent.
fn test_owner_items_are_live_cached_records_through_remove_clear_and_file_reads() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		transfer_items_owner_document('https://data-transfer-items-live-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.itemsAudio=document.createElement("audio");itemsAudio.id="items-audio";0',
	], runtime, mut messages)
	assert transfer_items_owner_guard(runtime)!
	assert messages == []
	assert document.get_element_by_id('items-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('itemsAudio')!)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string('first text')))
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00])
	bytes := [u8(0), 0xff, 65]
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		bytes, name))
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('application/custom'),
		libjs.utf16_string('last text')))
	mut transfer := html.DataTransfer.create(store)
	list := transfer.items()
	first_text := list.item(0)?
	file_item := list.item(1)?
	last_text := list.item(2)?
	transfer_items_owner_export(mut runtime, '__ownerItemsTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.ownerItemsTransfer=__ownerItemsTransfer();globalThis.ownerItemsList=ownerItemsTransfer.items;globalThis.ownerItemsFirst=ownerItemsList[0];globalThis.ownerItemsFile=ownerItemsList[1];globalThis.ownerItemsLast=ownerItemsList[2];globalThis.ownerItemsInitialTypes=ownerItemsTransfer.types;
globalThis.ownerItemsChecks=[];globalThis.ownerItemsSaved=[];globalThis.ownerItemsFiles=[];globalThis.ownerItemsOrder=[];globalThis.ownerItemsTrusted=true;globalThis.ownerItemsStage=0;globalThis.ownerItemsReads=[];globalThis.ownerItemsReadErrors=[];
ownerItemsChecks.push(ownerItemsList instanceof DataTransferItemList&&Object.getPrototypeOf(ownerItemsList)===DataTransferItemList.prototype&&Object.prototype.toString.call(ownerItemsList)==="[object DataTransferItemList]"&&ownerItemsList===ownerItemsTransfer.items&&ownerItemsList.length===3&&Array.from(ownerItemsList)[1]===ownerItemsFile&&ownerItemsFirst.kind==="string"&&ownerItemsFirst.type==="text/plain"&&ownerItemsFirst.getAsFile()===null&&ownerItemsFile.kind==="file"&&ownerItemsFile.type==="TEXT/PLAIN"&&ownerItemsLast.type==="application/custom");
for(const player of [video,itemsAudio]){
 player.addEventListener("drop",function(event){ownerItemsOrder.push("before:"+player.id);ownerItemsChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("drop",function(event){
  ownerItemsOrder.push("items:"+player.id);ownerItemsSaved.push(event);const transfer=event.dataTransfer,items=transfer.items;
  ownerItemsChecks.push(event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&Object.getPrototypeOf(event)===DragEvent.prototype&&event.isTrusted===ownerItemsTrusted&&event.view===window&&event.detail===7&&event.button===1&&event.buttons===2&&event.which===2&&event.ctrlKey&&event.bubbles&&event.cancelable&&event.composed&&transfer===ownerItemsTransfer&&items===ownerItemsList&&items===transfer.items&&window.event===event);
  if(ownerItemsStage===0){ownerItemsChecks.push(items.length===3&&items[0]===ownerItemsFirst&&items[1]===ownerItemsFile&&items[2]===ownerItemsLast&&items.remove(0)===undefined&&items.length===2&&items[0]===ownerItemsFile&&items[1]===ownerItemsLast&&items[2]===undefined&&ownerItemsFirst.kind===""&&ownerItemsFirst.type===""&&ownerItemsFirst.getAsFile()===null&&transfer.getData("text")==="")}
  else{ownerItemsChecks.push(items.length===2&&items[0]===ownerItemsFile&&items[1]===ownerItemsLast&&items.clear()===undefined&&items.length===1&&items[0]===ownerItemsFile&&items[1]===undefined&&ownerItemsLast.kind===""&&ownerItemsLast.type===""&&ownerItemsLast.getAsFile()===null&&transfer.getData("application/custom")===""&&transfer.types.join(",")==="Files")}
  const first=ownerItemsFile.getAsFile(),second=ownerItemsFile.getAsFile();ownerItemsFiles.push(first,second);
  ownerItemsChecks.push(ownerItemsFile instanceof DataTransferItem&&Object.getPrototypeOf(ownerItemsFile)===DataTransferItem.prototype&&Object.prototype.toString.call(ownerItemsFile)==="[object DataTransferItem]"&&items[0]===ownerItemsFile&&first!==second&&first instanceof File&&first instanceof Blob&&Object.getPrototypeOf(first)===File.prototype&&first.name.length===4&&first.name.charCodeAt(1)===0xd800&&first.name.charCodeAt(2)===0&&first.name.charCodeAt(3)===0xdc00&&first.type==="text/plain"&&first.size===3&&Number.isInteger(first.lastModified)&&first.lastModified>0&&first!==transfer.files[0]);
  const fields=[event.type,event.detail,event.clientX,event.timeStamp].join(",");event.initMouseEvent("ignored",false,false,null,99,0,0,0,0,false,false,false,false,0,null);ownerItemsChecks.push([event.type,event.detail,event.clientX,event.timeStamp].join(",")===fields&&event.dataTransfer.items===items);
  const read=first.bytes();ownerItemsChecks.push(read instanceof Promise);read.then(value=>{ownerItemsReads.push(value);result.textContent="item bytes:"+ownerItemsReads.length},reason=>ownerItemsReadErrors.push(reason));
  event.preventDefault();result.textContent=player.id+":"+items.length;
 });
 player.addEventListener("drop",function(event){ownerItemsOrder.push("after:"+player.id);ownerItemsChecks.push(event.defaultPrevented&&event.dataTransfer.items===ownerItemsList&&event.currentTarget===player&&window.event===event)});
}
document.body.appendChild(itemsAudio);void itemsAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('items-audio')?) == voidptr(created_target)
	assert runtime.native_data_transfer(runtime.evaluate_host_value('ownerItemsTransfer')!)! == transfer
	drag := transfer_items_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) },
		event)
	wrapper := runtime.evaluate_host_value('ownerItemsSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.default_prevented() && drag.data_transfer()? == transfer
	assert list == transfer.items() && list.length() == 2
	assert list.item(0)? == file_item && list.item(1)? == last_text
	assert first_text.kind() == '' && first_text.type_() == '' && first_text.get_as_file_record() == none
	assert runtime.evaluate_host('ownerItemsChecks.every(Boolean)&&ownerItemsSaved[0].currentTarget===null&&window.event===undefined&&ownerItemsReads.length===0')! == 'true'
	mut app := transfer_items_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:2'
	assert runtime.evaluate_host('(()=>{const event=ownerItemsSaved[0],stamp=event.timeStamp;ownerItemsStage=1;ownerItemsTrusted=false;return itemsAudio.dispatchEvent(event)===false&&ownerItemsSaved[1]===event&&!event.isTrusted&&event.clientX===9&&event.clientY===-3&&event.pageX===19&&event.offsetX===1&&event.dataTransfer===ownerItemsTransfer&&event.dataTransfer.items===ownerItemsList&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&ownerItemsChecks.every(Boolean)})()')! == 'true'
	assert runtime.native_event(runtime.evaluate_host_value('ownerItemsSaved[1]')!)! == event
	assert !event.is_trusted() && event.time_stamp() == stamp && drag.data_transfer()? == transfer
	assert list == transfer.items() && list.length() == 1 && list.item(0)? == file_item
	assert last_text.kind() == '' && last_text.type_() == '' && last_text.get_as_file_record() == none
	assert file_item.kind() == 'file' && file_item.type_() == 'TEXT/PLAIN'
	assert transfer.types() == ['Files'] && transfer.length() == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'items-audio:1'
	for id in ['video', 'items-audio'] {
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
	}
	assert runtime.evaluate_host('ownerItemsSaved.length===2&&ownerItemsOrder.join(",")==="before:video,items:video,after:video,before:items-audio,items:items-audio,after:items-audio"&&ownerItemsInitialTypes.join(",")==="text/plain,application/custom,Files"&&Object.isFrozen(ownerItemsInitialTypes)')! == 'true'
	for index in 0 .. 4 {
		file_wrapper := runtime.evaluate_host_value('ownerItemsFiles[${index}]')!
		file := runtime.native_file(file_wrapper)!
		assert runtime.javascript_file(file)! == file_wrapper
		assert voidptr(runtime.native_blob(file_wrapper)!) == voidptr(&file.Blob)
		assert file.raw_bytes() == bytes && file.name_utf16().code_units() == name.code_units()
		if index > 0 {
			previous := runtime.native_file(runtime.evaluate_host_value('ownerItemsFiles[${index - 1}]')!)!
			assert voidptr(previous) != voidptr(file)
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	mut tasks := 0
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		assert task.document() == settings.responsible_document()
		task.execute()
		tasks++
	}
	assert tasks == 2
	assert runtime.evaluate_host('ownerItemsReads.length===2&&ownerItemsReadErrors.length===0&&ownerItemsReads.every(value=>value instanceof Uint8Array&&value.length===3&&value[0]===0&&value[1]===255&&value[2]===65)&&ownerItemsChecks.every(Boolean)')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'item bytes:2'
	assert runtime.evaluate_host('(()=>{const event=ownerItemsSaved[0];event.initUIEvent("after-items",false,false,null,11);return event.dataTransfer===ownerItemsTransfer&&event.dataTransfer.items===ownerItemsList&&event.timeStamp===${stamp}&&event.detail===11&&!event.defaultPrevented&&event.target===null})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_owner_items_preserve_protected_metadata_and_disable_removed_or_disassociated_records() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		transfer_items_owner_document('http://data-transfer-items-gates-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.gateItemsAudio=document.createElement("audio");gateItemsAudio.id="gate-items-audio";0',
	], runtime, mut messages)
	assert transfer_items_owner_guard(runtime)!
	assert messages == []
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	name := libjs.utf16_string_from_code_units([u16(0xdfff), 0, u16(`B`)])
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('application/octet-stream'),
		[u8(10), 20, 30], name))
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('application/other'),
		libjs.utf16_string('visible metadata')))
	mut transfer := html.DataTransfer.create(store)
	list := transfer.items()
	initial_file := list.item(0)?
	initial_text := list.item(1)?
	transfer_items_owner_export(mut runtime, '__ownerGateItemsTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.gateItemsTransfer=__ownerGateItemsTransfer();globalThis.gateItemsList=gateItemsTransfer.items;globalThis.gateItemsFile=gateItemsList[0];globalThis.gateItemsText=gateItemsList[1];globalThis.gateItemsRestored=null;
globalThis.gateItemsChecks=[];globalThis.gateItemsSaved=[];globalThis.gateItemsFiles=[];globalThis.gateItemsPhase="initial";globalThis.gateItemsTrusted=true;
for(const player of [video,gateItemsAudio])player.addEventListener("drop",function(event){
 const transfer=event.dataTransfer,items=transfer.items;gateItemsSaved.push(event);
 gateItemsChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event.isTrusted===gateItemsTrusted&&event instanceof DragEvent&&event.view===window&&event.detail===7&&transfer===gateItemsTransfer&&items===gateItemsList&&items===transfer.items&&items instanceof DataTransferItemList);
 if(["initial","read-only","protected"].includes(gateItemsPhase))gateItemsChecks.push(items.length===2&&items[0]===gateItemsFile&&items[1]===gateItemsText&&gateItemsFile.kind==="file"&&gateItemsFile.type==="application/octet-stream"&&gateItemsText.kind==="string"&&gateItemsText.type==="application/other"&&gateItemsText.getAsFile()===null);
 if(["read-only","protected","disassociated"].includes(gateItemsPhase)){
  const previous=items.length,errors=[];for(const index of [0,4294967295])try{items.remove(index)}catch(error){errors.push(error)}
  gateItemsChecks.push(errors.length===2&&errors[0]!==errors[1]&&errors.every(error=>error instanceof DOMException&&error.name==="InvalidStateError"&&error.code===11&&error.message==="DataTransferItemList is not in read/write mode")&&items.clear()===undefined&&items.length===previous);
 }
 if(gateItemsPhase==="read-write-clear")gateItemsChecks.push(items.clear()===undefined&&items.length===1&&items[0]===gateItemsFile&&items[1]===undefined&&gateItemsText.kind===""&&gateItemsText.type===""&&gateItemsText.getAsFile()===null&&transfer.types.join(",")==="Files");
 if(gateItemsPhase==="restored-native"){gateItemsRestored=items[0];gateItemsChecks.push(items.length===1&&gateItemsRestored!==gateItemsFile&&gateItemsRestored.kind==="file"&&gateItemsRestored.type==="application/octet-stream"&&items[0]===gateItemsRestored)}
 if(gateItemsPhase==="removed"||gateItemsPhase==="disassociated")gateItemsChecks.push(items.length===0&&items[0]===undefined&&gateItemsFile.kind===""&&gateItemsFile.type===""&&gateItemsFile.getAsFile()===null&&gateItemsText.kind===""&&gateItemsText.type==="");
 if(gateItemsPhase==="disassociated")gateItemsChecks.push(gateItemsRestored.kind===""&&gateItemsRestored.type===""&&gateItemsRestored.getAsFile()===null);
 const item=gateItemsPhase==="restored-native"?gateItemsRestored:gateItemsFile;
 if(["initial","read-only","read-write-clear","restored-native"].includes(gateItemsPhase)){const first=item.getAsFile(),second=item.getAsFile();gateItemsFiles.push(first,second);gateItemsChecks.push(first!==second&&first instanceof File&&first instanceof Blob&&first.name.charCodeAt(0)===0xdfff&&first.name.charCodeAt(1)===0&&first.name.charCodeAt(2)===66&&first.type==="application/octet-stream"&&first.size===(gateItemsPhase==="restored-native"?2:3))}
 else gateItemsChecks.push(item.getAsFile()===null);
 event.preventDefault();result.textContent=player.id+":"+items.length+":"+gateItemsSaved.length;
});
document.body.appendChild(gateItemsAudio);void gateItemsAudio.paused;0
')!
	drag := transfer_items_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) },
		event)
	wrapper := runtime.evaluate_host_value('gateItemsSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && drag.data_transfer()? == transfer
	assert runtime.evaluate_host('gateItemsChecks.every(Boolean)&&window.event===undefined')! == 'true'
	mut app := transfer_items_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:2:1'
	for index, state in ['read-only', 'protected', 'read-write-clear', 'removed', 'restored-native',
		'disassociated'] {
		match state {
			'read-only' { store.mode = .read_only }
			'protected' { store.mode = .protected }
			'read-write-clear' { store.mode = .read_write }
			'removed' { transfer.remove_item(0) }
			'restored-native' {
				transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('application/octet-stream'),
					[u8(44), 55], name))
			}
			'disassociated' { transfer.disassociate_with_drag_data_store() }
			else {}
		}
		id := if index % 2 == 0 { 'gate-items-audio' } else { 'video' }
		expression := if id == 'video' { 'video' } else { 'gateItemsAudio' }
		expected_length := if state in ['removed', 'disassociated'] {
			0
		} else if state in ['read-write-clear', 'restored-native'] {
			1
		} else {
			2
		}
		assert runtime.evaluate_host('(()=>{const event=gateItemsSaved[0],stamp=event.timeStamp;gateItemsPhase="${state}";gateItemsTrusted=false;return ${expression}.dispatchEvent(event)===false&&gateItemsSaved[${index + 1}]===event&&!event.isTrusted&&event.dataTransfer===gateItemsTransfer&&event.dataTransfer.items===gateItemsList&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&gateItemsChecks.every(Boolean)})()')! == 'true'
		assert runtime.native_event(runtime.evaluate_host_value('gateItemsSaved[${index + 1}]')!)! == event
		assert !event.is_trusted() && event.default_prevented() && event.time_stamp() == stamp
		assert drag.data_transfer()? == transfer && list == transfer.items()
		assert int(list.length()) == expected_length
		if state in ['read-write-clear', 'removed', 'restored-native', 'disassociated'] {
			assert initial_text.kind() == '' && initial_text.type_() == ''
		}
		if state in ['removed', 'restored-native', 'disassociated'] {
			assert initial_file.kind() == '' && initial_file.type_() == ''
			assert initial_file.get_as_file_record() == none
		}
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:${expected_length}:${index + 2}'
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
		assert runtime.evaluate_host('gateItemsSaved.length===${index + 2}')! == 'true'
	}
	assert runtime.native_data_transfer(runtime.evaluate_host_value('gateItemsTransfer')!)! == transfer
	assert list.length() == 0 && transfer.mode() == none
	for index in 0 .. 8 {
		file_wrapper := runtime.evaluate_host_value('gateItemsFiles[${index}]')!
		file := runtime.native_file(file_wrapper)!
		assert runtime.javascript_file(file)! == file_wrapper
		assert voidptr(runtime.native_blob(file_wrapper)!) == voidptr(&file.Blob)
		assert file.name_utf16().code_units() == name.code_units()
		assert file.raw_bytes() == if index < 6 { [u8(10), 20, 30] } else { [u8(44), 55] }
	}
	assert runtime.evaluate_host('gateItemsChecks.every(Boolean)&&gateItemsSaved.length===7&&gateItemsFiles.length===8&&gateItemsTransfer.items===gateItemsList&&gateItemsList.length===0&&gateItemsFile.kind===""&&gateItemsRestored.kind===""&&gateItemsText.kind===""')! == 'true'
	assert runtime.evaluate_host('(()=>{const event=gateItemsSaved[0];event.initMouseEvent("after-items",false,false,null,1,0,0,0,0,false,false,false,false,0,null);return event.dataTransfer===gateItemsTransfer&&event.dataTransfer.items===gateItemsList&&event.timeStamp===${stamp}&&!event.defaultPrevented&&event.target===null})()')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context() && settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
