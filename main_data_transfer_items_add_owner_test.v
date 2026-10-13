module main

import browserjs
import dom
import html
import libjs
import page
import time

fn transfer_add_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn transfer_add_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn transfer_add_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn transfer_add_owner_event(document &dom.Document, transfer &html.DataTransfer) &html.DragEvent {
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

// Existing owner entry points and adapters keep these fixtures compilable on the
// feature's parent. The guard fails there before a public add() is invoked.
fn transfer_add_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof DataTransferItemList==="function"&&typeof DataTransferItem==="function"&&(()=>{const descriptor=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"items");return !!descriptor&&typeof descriptor.get==="function"&&Function.prototype.toString.call(descriptor.get).includes("[native code]")&&typeof DataTransferItemList.prototype.add==="function"&&DataTransferItemList.prototype.add.length===1&&Function.prototype.toString.call(DataTransferItemList.prototype.add).includes("[native code]")})()')! == 'true'
}

fn test_owner_public_items_add_produces_live_records_and_real_queued_file_reads() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		transfer_add_owner_document('https://data-transfer-items-add-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.addItemsAudio=document.createElement("audio");addItemsAudio.id="add-items-audio";0',
	], runtime, mut messages)
	assert transfer_add_owner_guard(runtime)!
	assert messages == []
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	list := transfer.items()
	transfer_add_owner_export(mut runtime, '__ownerAddItemsTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.addItemsTransfer=__ownerAddItemsTransfer();globalThis.addItemsList=addItemsTransfer.items;
globalThis.addItemsOriginal={File,Blob,FileList,Item:DataTransferItem,Exception:DOMException};globalThis.addItemsPoisonCalls=0;globalThis.addItemsPoisonMarker={};
globalThis.addItemsInput=new File([new Uint8Array([0,255,65])],"n\u0000\ud800x",{type:"TEXT/PLAIN",lastModified:7});
for(const key of ["name","type","size","lastModified","slice","bytes","arrayBuffer","text","stream",Symbol.toPrimitive])Object.defineProperty(addItemsInput,key,{get(){++addItemsPoisonCalls;throw addItemsPoisonMarker}});
for(const name of ["File","Blob","FileList","DOMException"])globalThis[name]=function(){++addItemsPoisonCalls;throw addItemsPoisonMarker};
globalThis.addItemsType=String.fromCharCode(88,0xd800,0,0xdc00,90);globalThis.addItemsData=String.fromCharCode(65,0xd800,0,0xdc00,0xd83d,0xde00);
globalThis.addItemsChecks=[];globalThis.addItemsSaved=[];globalThis.addItemsFiles=[];globalThis.addItemsSnapshots=[];globalThis.addItemsErrors=[];globalThis.addItemsOrder=[];globalThis.addItemsReads=[];globalThis.addItemsReadErrors=[];globalThis.addItemsStage=0;globalThis.addItemsTrusted=true;
for(const player of [video,addItemsAudio]){
 player.addEventListener("drop",function(event){addItemsOrder.push("before:"+player.id);addItemsChecks.push(this===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("drop",function(event){
  addItemsOrder.push("add:"+player.id);addItemsSaved.push(event);const transfer=event.dataTransfer,items=transfer.items;
  addItemsChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event instanceof DragEvent&&event.isTrusted===addItemsTrusted&&event.view===window&&event.detail===7&&transfer===addItemsTransfer&&items===addItemsList&&items===transfer.items);
  if(addItemsStage===0){
   globalThis.addItemsText=items.add(addItemsData,addItemsType);globalThis.addItemsFirstFile=items.add(addItemsInput);
   addItemsChecks.push(items.length===2&&items[0]===addItemsText&&items[1]===addItemsFirstFile&&addItemsText instanceof addItemsOriginal.Item&&addItemsText.kind==="string"&&addItemsText.type===String.fromCharCode(120,0xd800,0,0xdc00,122)&&addItemsText.getAsFile()===null&&transfer.getData(addItemsType)===addItemsData);
  }else{
   for(let index=0;index<2;index++)try{items.add("duplicate",addItemsType)}catch(error){addItemsErrors.push(error)};
   globalThis.addItemsSecondFile=items.add(addItemsInput);
   addItemsChecks.push(addItemsErrors.length===2&&addItemsErrors[0]!==addItemsErrors[1]&&addItemsErrors.every(error=>error instanceof addItemsOriginal.Exception&&error.name==="NotSupportedError"&&error.code===9&&error.message==="There is already a DataTransferItem with type "+addItemsType)&&items.length===3&&items[0]===addItemsText&&items[1]===addItemsFirstFile&&items[2]===addItemsSecondFile&&addItemsSecondFile!==addItemsFirstFile&&transfer.getData(addItemsType)===addItemsData);
  }
  const item=addItemsStage===0?addItemsFirstFile:addItemsSecondFile,first=item.getAsFile(),second=item.getAsFile(),snapshot=transfer.files;addItemsFiles.push(first,second);addItemsSnapshots.push(snapshot);
  addItemsChecks.push(item instanceof addItemsOriginal.Item&&item.kind==="file"&&item.type==="text/plain"&&first!==second&&first!==addItemsInput&&first instanceof addItemsOriginal.File&&first instanceof addItemsOriginal.Blob&&Object.getPrototypeOf(first)===addItemsOriginal.File.prototype&&first.name==="n\u0000\ufffdx"&&first.type==="text/plain"&&first.size===3&&first.lastModified>0&&Number.isInteger(first.lastModified)&&snapshot instanceof addItemsOriginal.FileList&&snapshot.length===addItemsStage+1&&snapshot[0]!==first&&snapshot[0].name===first.name&&addItemsPoisonCalls===0);
  const read=first.bytes();addItemsChecks.push(read instanceof Promise);read.then(value=>{addItemsReads.push(value);result.textContent="added bytes:"+addItemsReads.length},reason=>addItemsReadErrors.push(reason));
  event.preventDefault();result.textContent=player.id+":"+items.length;
 });
 player.addEventListener("drop",function(event){addItemsOrder.push("after:"+player.id);addItemsChecks.push(event.defaultPrevented&&event.currentTarget===player&&event.dataTransfer.items===addItemsList&&window.event===event)});
}
document.body.appendChild(addItemsAudio);void addItemsAudio.paused;0
')!
	input_wrapper := runtime.evaluate_host_value('addItemsInput')!
	input := runtime.native_file(input_wrapper)!
	assert input.raw_bytes() == [u8(0), 255, 65]
	assert input.name_utf16().code_units() == [u16(`n`), 0, 0xfffd, u16(`x`)]
	assert input.last_modified() == 7
	drag := transfer_add_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) },
		event)
	wrapper := runtime.evaluate_host_value('addItemsSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.default_prevented() && drag.data_transfer()? == transfer
	assert runtime.evaluate_host('addItemsChecks.every(Boolean)&&addItemsSaved[0].currentTarget===null&&window.event===undefined&&addItemsReads.length===0&&addItemsPoisonCalls===0')! == 'true'
	assert voidptr(runtime.native_data_transfer(runtime.evaluate_host_value('addItemsTransfer')!)!) == voidptr(transfer)
	assert voidptr(runtime.native_data_transfer_item_list(runtime.evaluate_host_value('addItemsList')!)!) == voidptr(list)
	assert list.length() == 2
	text_item := list.item(0)?
	first_file_item := list.item(1)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addItemsText')!)!) == voidptr(text_item)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addItemsFirstFile')!)!) == voidptr(first_file_item)
	type_units := [u16(`x`), 0xd800, 0, 0xdc00, u16(`z`)]
	data_units := [u16(`A`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00]
	assert text_item.type_utf16().code_units() == type_units
	assert transfer.get_data_utf16(libjs.utf16_string_from_code_units(type_units)).code_units() == data_units
	mut app := transfer_add_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:2'
	assert runtime.evaluate_host('(()=>{const event=addItemsSaved[0],stamp=event.timeStamp;addItemsStage=1;addItemsTrusted=false;return addItemsAudio.dispatchEvent(event)===false&&addItemsSaved[1]===event&&!event.isTrusted&&event.dataTransfer===addItemsTransfer&&event.dataTransfer.items===addItemsList&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&addItemsChecks.every(Boolean)&&addItemsPoisonCalls===0})()')! == 'true'
	assert runtime.native_event(runtime.evaluate_host_value('addItemsSaved[1]')!)! == event
	assert !event.is_trusted() && event.time_stamp() == stamp && drag.data_transfer()? == transfer
	assert list.length() == 3 && voidptr(list.item(0)?) == voidptr(text_item)
	assert voidptr(list.item(1)?) == voidptr(first_file_item)
	second_file_item := list.item(2)?
	assert voidptr(second_file_item) != voidptr(first_file_item)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addItemsSecondFile')!)!) == voidptr(second_file_item)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'add-items-audio:3'
	for id in ['video', 'add-items-audio'] {
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
	}
	assert runtime.evaluate_host('addItemsSaved.length===2&&addItemsOrder.join(",")==="before:video,add:video,after:video,before:add-items-audio,add:add-items-audio,after:add-items-audio"')! == 'true'
	mut expected_message := libjs.utf16_string('There is already a DataTransferItem with type ').code_units()
	expected_message << [u16(`X`), 0xd800, 0, 0xdc00, u16(`Z`)]
	first_exception := runtime.native_dom_exception(runtime.evaluate_host_value('addItemsErrors[0]')!)!.dom_exception_?
	second_exception := runtime.native_dom_exception(runtime.evaluate_host_value('addItemsErrors[1]')!)!.dom_exception_?
	assert voidptr(first_exception) != voidptr(second_exception)
	assert first_exception.name() == 'NotSupportedError' && first_exception.code() == 9
	assert first_exception.message_utf16().code_units() == expected_message
	assert second_exception.message_utf16().code_units() == expected_message
	for index in 0 .. 4 {
		file_wrapper := runtime.evaluate_host_value('addItemsFiles[${index}]')!
		file := runtime.native_file(file_wrapper)!
		assert runtime.javascript_file(file)! == file_wrapper
		assert voidptr(runtime.native_blob(file_wrapper)!) == voidptr(&file.Blob)
		assert voidptr(file) != voidptr(input)
		assert file.raw_bytes() == input.raw_bytes()
		assert file.name_utf16().code_units() == input.name_utf16().code_units()
		assert file.type_() == 'text/plain' && file.last_modified() > 0
		if index > 0 {
			previous := runtime.native_file(runtime.evaluate_host_value('addItemsFiles[${index - 1}]')!)!
			assert voidptr(previous) != voidptr(file)
		}
	}
	for index in 0 .. 2 {
		file_list := runtime.native_file_list(runtime.evaluate_host_value('addItemsSnapshots[${index}]')!)!
		assert int(file_list.length()) == index + 1
		assert file_list.item(0)?.raw_bytes() == input.raw_bytes()
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
	assert runtime.evaluate_host('addItemsReads.length===2&&addItemsReadErrors.length===0&&addItemsReads.every(value=>value instanceof Uint8Array&&value.length===3&&value[0]===0&&value[1]===255&&value[2]===65)&&addItemsChecks.every(Boolean)&&addItemsPoisonCalls===0')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'added bytes:2'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_owner_public_items_add_converts_strings_before_native_access_gates() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		transfer_add_owner_document('http://data-transfer-items-add-gates-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.addGateAudio=document.createElement("audio");addGateAudio.id="add-gate-audio";0',
	], runtime, mut messages)
	assert transfer_add_owner_guard(runtime)!
	assert messages == []
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	list := transfer.items()
	transfer_add_owner_export(mut runtime, '__ownerAddGateTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.addGateTransfer=__ownerAddGateTransfer();globalThis.addGateItems=addGateTransfer.items;globalThis.addGateInput=new File([new Uint8Array([10,20,30])],"gate.bin",{type:"APPLICATION/OCTET-STREAM",lastModified:19});
globalThis.addGateOriginalFile=File;globalThis.addGatePoisonCalls=0;globalThis.addGateMarker={};for(const key of ["name","type","size","lastModified",Symbol.toPrimitive])Object.defineProperty(addGateInput,key,{get(){++addGatePoisonCalls;throw addGateMarker}});
globalThis.addGateText=addGateItems.add("initial","text/plain");globalThis.addGateFile=addGateItems.add(addGateInput);globalThis.addGateNewText=null;globalThis.addGateNewFile=null;
globalThis.addGateChecks=[];globalThis.addGateSaved=[];globalThis.addGatePhase="read-only";globalThis.addGateTrusted=true;globalThis.addGateConversions=[];
for(const player of [video,addGateAudio])player.addEventListener("drop",function(event){
 const transfer=event.dataTransfer,items=transfer.items;addGateSaved.push(event);
 addGateChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event.isTrusted===addGateTrusted&&event instanceof DragEvent&&event.view===window&&event.detail===7&&transfer===addGateTransfer&&items===addGateItems&&items===transfer.items);
 const trace=[],data={[Symbol.toPrimitive](hint){trace.push("data:"+hint);return "converted"}},type={[Symbol.toPrimitive](hint){trace.push("type:"+hint);return addGatePhase==="read-write"?"application/new":"text/plain"}};
 const text=items.add(data,type),file=items.add(addGateInput);addGateConversions.push(trace.join(","));
 addGateChecks.push(trace.join(",")==="data:string,type:string"&&addGatePoisonCalls===0);
 if(addGatePhase==="read-write"){
  addGateNewText=text;addGateNewFile=file;addGateChecks.push(items.length===4&&items[0]===addGateText&&items[1]===addGateFile&&items[2]===text&&items[3]===file&&text.kind==="string"&&text.type==="application/new"&&transfer.getData("application/new")==="converted"&&file.kind==="file"&&file.type==="application/octet-stream"&&file!==addGateFile);
 }else addGateChecks.push(text===null&&file===null&&items.length===(addGatePhase==="disassociated"?0:2));
 const errors=[];try{items.add({[Symbol.toPrimitive](hint){errors.push(hint);throw addGateMarker}},"unused")}catch(error){addGateChecks.push(error===addGateMarker)};
 addGateChecks.push(errors.join(",")==="string");
 if(addGatePhase==="read-only")addGateChecks.push(addGateFile.kind==="file"&&addGateFile.type==="application/octet-stream"&&addGateFile.getAsFile() instanceof addGateOriginalFile&&transfer.files.length===1&&transfer.getData("text/plain")==="initial");
 if(addGatePhase==="protected")addGateChecks.push(addGateFile.kind==="file"&&addGateFile.type==="application/octet-stream"&&addGateFile.getAsFile()===null&&transfer.files.length===0&&transfer.getData("text/plain")==="");
 if(addGatePhase==="disassociated")addGateChecks.push(items[0]===undefined&&addGateText.kind===""&&addGateText.type===""&&addGateFile.kind===""&&addGateFile.type===""&&addGateNewText.kind===""&&addGateNewFile.kind===""&&addGateFile.getAsFile()===null&&addGateNewFile.getAsFile()===null&&transfer.files.length===0);
 event.preventDefault();result.textContent=player.id+":"+items.length+":"+addGatePhase;
});
document.body.appendChild(addGateAudio);void addGateAudio.paused;0
')!
	assert list.length() == 2
	initial_text := list.item(0)?
	initial_file := list.item(1)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addGateText')!)!) == voidptr(initial_text)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addGateFile')!)!) == voidptr(initial_file)
	input := runtime.native_file(runtime.evaluate_host_value('addGateInput')!)!
	assert input.raw_bytes() == [u8(10), 20, 30] && input.last_modified() == 19
	store.mode = .read_only
	drag := transfer_add_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) },
		event)
	wrapper := runtime.evaluate_host_value('addGateSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.default_prevented() && drag.data_transfer()? == transfer
	assert runtime.evaluate_host('addGateChecks.every(Boolean)&&addGateSaved[0].currentTarget===null&&window.event===undefined&&addGatePoisonCalls===0')! == 'true'
	mut app := transfer_add_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:2:read-only'
	for index, phase in ['protected', 'read-write', 'disassociated'] {
		match phase {
			'protected' { store.mode = .protected }
			'read-write' { store.mode = .read_write }
			'disassociated' { transfer.disassociate_with_drag_data_store() }
			else {}
		}
		id := if index % 2 == 0 { 'add-gate-audio' } else { 'video' }
		expression := if id == 'video' { 'video' } else { 'addGateAudio' }
		expected_length := if phase == 'disassociated' { 0 } else if phase == 'read-write' { 4 } else { 2 }
		assert runtime.evaluate_host('(()=>{const event=addGateSaved[0],stamp=event.timeStamp;addGatePhase="${phase}";addGateTrusted=false;return ${expression}.dispatchEvent(event)===false&&addGateSaved[${index + 1}]===event&&!event.isTrusted&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&addGateChecks.every(Boolean)&&addGatePoisonCalls===0})()')! == 'true'
		assert runtime.native_event(runtime.evaluate_host_value('addGateSaved[${index + 1}]')!)! == event
		assert !event.is_trusted() && event.time_stamp() == stamp && drag.data_transfer()? == transfer
		assert int(list.length()) == expected_length
		if phase != 'disassociated' {
			assert voidptr(list.item(0)?) == voidptr(initial_text)
			assert voidptr(list.item(1)?) == voidptr(initial_file)
		}
		if phase == 'read-write' {
			assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addGateNewText')!)!) == voidptr(list.item(2)?)
			assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('addGateNewFile')!)!) == voidptr(list.item(3)?)
			assert transfer.drag_data(3).data == input.raw_bytes()
		}
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:${expected_length}:${phase}'
	}
	assert initial_text.kind() == '' && initial_file.kind() == ''
	assert initial_text.type_() == '' && initial_file.get_as_file_record() == none
	assert runtime.evaluate_host('addGateSaved.length===4&&addGateConversions.length===4&&addGateConversions.every(value=>value==="data:string,type:string")&&addGateChecks.every(Boolean)&&addGatePoisonCalls===0')! == 'true'
	for id in ['video', 'add-gate-audio'] {
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
	}
	assert runtime.evaluate_host('addGateSaved.length===4')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
