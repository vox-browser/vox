module main

import browserjs
import dom
import html
import libjs
import page
import time

fn transfer_files_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn transfer_files_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof DataTransfer==="function"&&(()=>{const descriptor=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"files");return !!descriptor&&typeof descriptor.get==="function"&&Function.prototype.toString.call(descriptor.get).includes("[native code]")})()')! == 'true'
}

fn transfer_files_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn transfer_files_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn transfer_files_owner_event(document &dom.Document, transfer &html.DataTransfer) &html.DragEvent {
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

// The owner runtime installs the actual Blob/File/FileList hosts. Native file
// producers feed the DOM dispatcher directly; Page/Cocoa drag delivery and
// public DataTransfer.items are independent slices.
fn test_owner_drag_files_getter_produces_fresh_real_file_lists_and_owner_reads() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		transfer_files_owner_document('https://data-transfer-files-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.filesAudio=document.createElement("audio");filesAudio.id="files-audio";0',
	], runtime, mut messages)
	assert transfer_files_owner_guard(runtime)!
	assert messages == []
	assert document.get_element_by_id('files-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('filesAudio')!)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string('text is not a file')))
	first_name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00])
	first_bytes := [u8(0), 0xff, 65]
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		first_bytes, first_name))
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string_from_code_units([
		u16(`x`),
		0xd800,
	]), [u8(66), 67], libjs.utf16_string('second.bin')))
	mut transfer := html.DataTransfer.create(store)
	transfer_files_owner_export(mut runtime, '__ownerFilesTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.ownerFilesTransfer=__ownerFilesTransfer();globalThis.ownerFilesChecks=[];globalThis.ownerFilesEvents=[];globalThis.ownerFilesSnapshots=[];globalThis.ownerFilesOrder=[];globalThis.ownerFilesTrusted=true;globalThis.ownerFilesReads=[];globalThis.ownerFilesReadErrors=[];
ownerFilesChecks.push(typeof Blob==="function"&&typeof File==="function"&&typeof FileList==="function"&&ownerFilesTransfer.types.join(",")==="text/plain,Files");
for(const player of [video,filesAudio]){
 player.addEventListener("drop",function(event){ownerFilesOrder.push("before:"+player.id);ownerFilesChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("drop",function(event){
  ownerFilesOrder.push("files:"+player.id);ownerFilesEvents.push(event);
  const transfer=event.dataTransfer,first=transfer.files,second=transfer.files,file=first[0];ownerFilesSnapshots.push(first,second);
  ownerFilesChecks.push(event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&Object.getPrototypeOf(event)===DragEvent.prototype&&event.isTrusted===ownerFilesTrusted&&event.view===window&&event.detail===7&&event.which===2&&event.button===1&&event.buttons===2&&event.ctrlKey&&event.bubbles&&event.cancelable&&event.composed&&transfer===ownerFilesTransfer&&transfer===event.dataTransfer&&window.event===event);
  ownerFilesChecks.push(first!==second&&first instanceof FileList&&second instanceof FileList&&Object.prototype.toString.call(first)==="[object FileList]"&&Object.getPrototypeOf(first)===FileList.prototype&&first.length===2&&second.length===2&&first[0]===file&&first.item(0)===file&&first.item(2)===null&&first[2]===undefined&&Array.from(first).length===2&&file!==second[0]&&file instanceof File&&file instanceof Blob&&Object.getPrototypeOf(file)===File.prototype&&Object.prototype.toString.call(file)==="[object File]"&&file.name.length===4&&file.name.charCodeAt(0)===110&&file.name.charCodeAt(1)===0xd800&&file.name.charCodeAt(2)===0&&file.name.charCodeAt(3)===0xdc00&&file.type==="text/plain"&&file.size===3&&Number.isInteger(file.lastModified)&&file.lastModified>0&&first[1].name==="second.bin"&&first[1].type===""&&first[1].size===2);
  const fields=[event.type,event.detail,event.clientX,event.clientY,event.timeStamp].join(",");event.initMouseEvent("ignored",false,false,null,99,1,2,3,4,false,false,false,false,0,null);ownerFilesChecks.push([event.type,event.detail,event.clientX,event.clientY,event.timeStamp].join(",")===fields&&event.dataTransfer===transfer);
  const bytes=file.bytes();ownerFilesChecks.push(bytes instanceof Promise);bytes.then(value=>{ownerFilesReads.push(value);result.textContent="file bytes:"+ownerFilesReads.length},reason=>ownerFilesReadErrors.push(reason));
  event.preventDefault();result.textContent=player.id+":"+ownerFilesEvents.length;
 });
 player.addEventListener("drop",function(event){ownerFilesOrder.push("after:"+player.id);ownerFilesChecks.push(event.defaultPrevented&&event.currentTarget===player&&event.dataTransfer===ownerFilesTransfer&&window.event===event)});
}
document.body.appendChild(filesAudio);void filesAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('files-audio')?) == voidptr(created_target)
	assert runtime.native_data_transfer(runtime.evaluate_host_value('ownerFilesTransfer')!)! == transfer
	mut app := transfer_files_owner_app(owner, document, runtime)
	for index, id in ['video', 'files-audio'] {
		target := document.get_element_by_id(id)?
		drag := transfer_files_owner_event(document, transfer)
		event := unsafe { &dom.Event(drag) }
		stamp := event.time_stamp()
		runtime.evaluate_host('ownerFilesTrusted=true;0')!
		assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event)
		wrapper := runtime.evaluate_host_value('ownerFilesEvents[${index * 2}]')!
		assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
		assert event.is_trusted() && event.default_prevented() && event.time_stamp() == stamp
		assert drag.data_transfer()? == transfer
		assert runtime.evaluate_host('ownerFilesChecks.every(Boolean)&&ownerFilesEvents[${index * 2}].currentTarget===null&&window.event===undefined&&ownerFilesReads.length===0')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:${index * 2 + 1}'
		assert runtime.evaluate_host('(()=>{const event=ownerFilesEvents[${index * 2}],stamp=event.timeStamp;ownerFilesTrusted=false;return event.target.dispatchEvent(event)===false&&ownerFilesEvents[${index * 2 + 1}]===event&&!event.isTrusted&&event.clientX===9&&event.clientY===-3&&event.pageX===19&&event.offsetX===1&&event.dataTransfer===ownerFilesTransfer&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&ownerFilesChecks.every(Boolean)})()')! == 'true'
		assert !event.is_trusted() && event.time_stamp() == stamp && drag.data_transfer()? == transfer
		assert runtime.native_event(runtime.evaluate_host_value('ownerFilesEvents[${index * 2 + 1}]')!)! == event
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:${index * 2 + 2}'
		assert !app.dispatch_javascript_event('drop', target)
		assert runtime.evaluate_host('ownerFilesEvents.length===${index * 2 + 2}')! == 'true'
		assert runtime.evaluate_host('(()=>{const event=ownerFilesEvents[${index * 2}];event.initUIEvent("after-drop",false,false,null,11);return event.dataTransfer===ownerFilesTransfer&&event.timeStamp===${stamp}&&event.detail===11&&!event.defaultPrevented&&event.target===null})()')! == 'true'
	}
	for index in 0 .. 8 {
		list_wrapper := runtime.evaluate_host_value('ownerFilesSnapshots[${index}]')!
		list := runtime.native_file_list(list_wrapper)!
		assert runtime.javascript_file_list(list)! == list_wrapper
		assert list.length() == 2
		file_wrapper := runtime.evaluate_host_value('ownerFilesSnapshots[${index}][0]')!
		file := runtime.native_file(file_wrapper)!
		assert file == list.item(0)? && runtime.javascript_file(file)! == file_wrapper
		assert voidptr(runtime.native_blob(file_wrapper)!) == voidptr(&file.Blob)
		assert file.name_utf16().code_units() == first_name.code_units()
		assert file.raw_bytes() == first_bytes && file.type_() == 'text/plain'
		assert list.item(1)?.raw_bytes() == [u8(66), 67]
		if index > 0 {
			previous := runtime.native_file_list(runtime.evaluate_host_value('ownerFilesSnapshots[${index - 1}]')!)!
			assert voidptr(previous) != voidptr(list)
			assert voidptr(previous.item(0)?) != voidptr(file)
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
	assert tasks == 4
	assert runtime.evaluate_host('ownerFilesReads.length===4&&ownerFilesReadErrors.length===0&&ownerFilesReads.every(value=>value instanceof Uint8Array&&value.length===3&&value[0]===0&&value[1]===255&&value[2]===65)&&ownerFilesChecks.every(Boolean)')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'file bytes:4'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_owner_drag_files_snapshots_survive_native_removal_and_store_access_gates() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		transfer_files_owner_document('http://data-transfer-files-gate-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.gateFilesAudio=document.createElement("audio");gateFilesAudio.id="gate-files-audio";0',
	], runtime, mut messages)
	assert transfer_files_owner_guard(runtime)!
	assert messages == []
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	removed_name := libjs.utf16_string_from_code_units([u16(0xdfff), 0, u16(`A`)])
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('application/octet-stream'),
		[u8(10), 20, 30], removed_name))
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		'kept'.bytes(), libjs.utf16_string('kept.txt')))
	mut transfer := html.DataTransfer.create(store)
	removed_item := transfer.item(0)
	transfer_files_owner_export(mut runtime, '__ownerGateFilesTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.gateFilesTransfer=__ownerGateFilesTransfer();globalThis.gateFilesChecks=[];globalThis.gateFilesSaved=[];globalThis.gateFilesSnapshots=[];globalThis.gateFilesExpectedLength=2;globalThis.gateFilesExpectedTrusted=true;
for(const player of [video,gateFilesAudio])player.addEventListener("drop",function(event){
 const transfer=event.dataTransfer,first=transfer.files,second=transfer.files;gateFilesSaved.push(event);gateFilesSnapshots.push(first,second);
 gateFilesChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event.isTrusted===gateFilesExpectedTrusted&&event instanceof DragEvent&&event.view===window&&event.detail===7&&event.dataTransfer===gateFilesTransfer&&transfer===event.dataTransfer&&first!==second&&first instanceof FileList&&second instanceof FileList&&first.length===gateFilesExpectedLength&&second.length===gateFilesExpectedLength&&Object.getPrototypeOf(first)===FileList.prototype);
 if(first.length){gateFilesChecks.push(first[0] instanceof File&&first[0] instanceof Blob&&first.item(0)===first[0]&&first[0]!==second[0]);if(first.length===2)gateFilesChecks.push(first[0].name.charCodeAt(0)===0xdfff&&first[0].name.charCodeAt(1)===0&&first[0].name.charCodeAt(2)===65&&first[0].size===3&&first[1].name==="kept.txt");else gateFilesChecks.push(first[0].name==="kept.txt"&&first[0].type==="text/plain"&&first[0].size===4)}else gateFilesChecks.push(first[0]===undefined&&first.item(0)===null);
 event.preventDefault();result.textContent=player.id+":"+first.length+":"+gateFilesSaved.length;
});
document.body.appendChild(gateFilesAudio);void gateFilesAudio.paused;0
')!
	drag := transfer_files_owner_event(document, transfer)
	event := unsafe { &dom.Event(drag) }
	stamp := event.time_stamp()
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) },
		event)
	wrapper := runtime.evaluate_host_value('gateFilesSaved[0]')!
	assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && drag.data_transfer()? == transfer
	mut app := transfer_files_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'video:2:1'
	transfer.remove_item(0)
	assert removed_item.get_as_file_record() == none
	for index, state in ['removed', 'read-only', 'protected', 'readable-again', 'disassociated'] {
		match state {
			'read-only', 'readable-again' { store.mode = .read_only }
			'protected' { store.mode = .protected }
			'disassociated' { transfer.disassociate_with_drag_data_store() }
			else {}
		}
		expected_length := if state in ['protected', 'disassociated'] { 0 } else { 1 }
		id := if index % 2 == 0 { 'gate-files-audio' } else { 'video' }
		expression := if id == 'video' { 'video' } else { 'gateFilesAudio' }
		assert runtime.evaluate_host('(()=>{const event=gateFilesSaved[0],stamp=event.timeStamp;gateFilesExpectedLength=${expected_length};gateFilesExpectedTrusted=false;return ${expression}.dispatchEvent(event)===false&&gateFilesSaved[${index + 1}]===event&&!event.isTrusted&&event.dataTransfer===gateFilesTransfer&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&gateFilesChecks.every(Boolean)})()')! == 'true'
		assert runtime.native_event(runtime.evaluate_host_value('gateFilesSaved[${index + 1}]')!)! == event
		assert !event.is_trusted() && event.default_prevented() && event.time_stamp() == stamp
		assert drag.data_transfer()? == transfer
		assert runtime.native_data_transfer(runtime.evaluate_host_value('gateFilesTransfer')!)! == transfer
		first_wrapper := runtime.evaluate_host_value('gateFilesSnapshots[${(index + 1) * 2}]')!
		second_wrapper := runtime.evaluate_host_value('gateFilesSnapshots[${(index + 1) * 2 + 1}]')!
		first := runtime.native_file_list(first_wrapper)!
		second := runtime.native_file_list(second_wrapper)!
		assert voidptr(first) != voidptr(second) && first.length() == expected_length
		assert second.length() == expected_length
		if expected_length > 0 {
			assert first.item(0)?.name() == 'kept.txt'
			assert first.item(0)?.raw_bytes() == 'kept'.bytes()
			assert voidptr(first.item(0)?) != voidptr(second.item(0)?)
		}
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:${expected_length}:${index + 2}'
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
		assert runtime.evaluate_host('gateFilesSaved.length===${index + 2}')! == 'true'
	}
	retained := runtime.native_file_list(runtime.evaluate_host_value('gateFilesSnapshots[0]')!)!
	assert retained.length() == 2
	assert retained.item(0)?.name_utf16().code_units() == removed_name.code_units()
	assert retained.item(0)?.raw_bytes() == [u8(10), 20, 30]
	assert retained.item(1)?.raw_bytes() == 'kept'.bytes()
	assert runtime.evaluate_host('gateFilesChecks.every(Boolean)&&gateFilesSaved.length===6&&gateFilesSnapshots.length===12&&gateFilesSnapshots[0].length===2&&gateFilesSnapshots[0][0].name.charCodeAt(0)===0xdfff&&gateFilesSnapshots[2].length===1&&gateFilesSnapshots[6].length===0&&gateFilesSnapshots[8].length===1&&gateFilesSnapshots[10].length===0&&gateFilesTransfer.files.length===0&&gateFilesTransfer.files!==gateFilesTransfer.files')! == 'true'
	assert runtime.evaluate_host('(()=>{const event=gateFilesSaved[0];event.initMouseEvent("after-files",false,false,null,1,0,0,0,0,false,false,false,false,0,null);return event.dataTransfer===gateFilesTransfer&&event.dataTransfer.files.length===0&&event.timeStamp===${stamp}&&!event.defaultPrevented&&event.target===null})()')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context() && settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
