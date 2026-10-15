module main

import browserjs
import dom
import html
import page
import time

fn media_drag_handler_document(markup string, address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn media_drag_handler_guard(runtime &browserjs.Runtime) !bool {
	// The parent compiles these owner fixtures and fails here, before an own
	// property assignment could conceal a missing native accessor.
	return runtime.evaluate_host(r'["ondrag","ondragend","ondragenter","ondragleave","ondragover","ondragstart","ondrop"].every(name=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!d&&typeof d.get==="function"&&typeof d.set==="function"&&d.get.length===0&&d.set.length===1&&[d.get,d.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))&&[video,mediaDragAudio].every(player=>player[name]===null&&!Object.hasOwn(player,name))})')! == 'true'
}

fn media_drag_handler_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn media_drag_handler_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn media_drag_handler_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner_handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaDragHandlerContext', fn [settings, owner_handle, actual_true] (_ voidptr, arguments []voidptr) !voidptr {
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

fn media_drag_handler_event(document &dom.Document, type_ string, transfer ?&html.DataTransfer) &dom.Event {
	drag := html.DragEvent.create(type_, html.DragEventInit{
		MouseEventInit: dom.MouseEventInit{
			EventModifierInit: dom.EventModifierInit{
				UIEventInit: dom.UIEventInit{
					EventInit: dom.EventInit{
						bubbles:    true
						cancelable: true
						composed:   true
					}
					view:   voidptr(document.get_window() or { panic('Media drag owner needs its Window') })
					detail: 7
				}
				ctrl_key: true
			}
			screen_x: 111.25
			screen_y: 221.75
			client_x: 11.5
			client_y: 21.125
			button:   2
			buttons:  2
		}
		data_transfer: transfer
	}, 31.5, 41.125, 1.75, 2.625)
	return unsafe { &dom.Event(drag) }
}

// Page's current drag route records DragDispatch entries. These tests use the
// actual native factory and DOM dispatcher; they do not manufacture a Cocoa
// drag producer, automatic store-mode transitions, or a default drop action.
fn test_media_drag_handlers_keep_actual_payload_records_and_redispatch_the_same_event() {
	$if !darwin { return }
	mut owner, mut document := media_drag_handler_document('<video id="video"></video><div id="result">waiting</div>',
		'https://media-drag-handler-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mediaDragAudio=document.createElement("audio");mediaDragAudio.id="media-drag-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_drag_handler_guard(runtime)!
	media_drag_handler_probe(mut runtime, document)!
	assert document.get_element_by_id('media-drag-audio') == none
	created := runtime.native_event_target(runtime.evaluate_host_value('mediaDragAudio')!)!
	mut transfer := html.DataTransfer.construct()
	mut list := transfer.items()
	media_drag_handler_export(mut runtime, '__mediaDragOwnerTransfer', runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.mediaDragTransfer=__mediaDragOwnerTransfer();globalThis.mediaDragList=mediaDragTransfer.items;
globalThis.mediaDragInput=new File([new Uint8Array([0,255,65])],"\u03a9\u0000\ud800\ud83d\ude00.txt",{type:"TEXT/PLAIN",lastModified:7});
globalThis.mediaDragText=mediaDragList.add("owner\ud800\u0000","text/plain");globalThis.mediaDragFile=mediaDragList.add(mediaDragInput);
globalThis.mediaDragOrder=[];globalThis.mediaDragChecks=[];globalThis.mediaDragSaved=[];globalThis.mediaDragEntries=[];globalThis.mediaDragFiles=[];
globalThis.mediaDragTrusted=true;globalThis.mediaDragReturn=0;
for(const player of [video,mediaDragAudio])for(const type of ["drag","dragend","dragenter","dragleave","dragover","dragstart","drop"]){
 const name="on"+type;
 player.addEventListener(type,function(event){mediaDragOrder.push(player.id+":"+type+":before");mediaDragChecks.push(this===player&&event.target===player&&event.currentTarget===player&&!event.defaultPrevented&&window.event===event)});
 player[name]=function(){mediaDragOrder.push("obsolete")};
 player.addEventListener(type,function(event){mediaDragOrder.push(player.id+":"+type+":after");mediaDragChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===(mediaDragReturn===false)&&window.event===event);result.textContent=mediaDragOrder.join(",")});
 const replacement=function(event){
  mediaDragOrder.push(player.id+":"+type+":handler");mediaDragSaved.push(event);
  mediaDragChecks.push(arguments.length===1&&this===player&&event.type===type&&event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof Event&&event.isTrusted===mediaDragTrusted&&event.bubbles&&event.cancelable&&event.composed&&event.view===window&&event.detail===7&&event.button===2&&event.buttons===2&&event.ctrlKey&&event.target===player&&event.currentTarget===player&&window.event===event&&__mediaDragHandlerContext());
  mediaDragChecks.push(event.dataTransfer===mediaDragTransfer&&event.dataTransfer.items===mediaDragList&&mediaDragList.length===2&&mediaDragList[0]===mediaDragText&&mediaDragList[1]===mediaDragFile&&mediaDragTransfer.getData("text")==="owner\ud800\u0000");
  const first=mediaDragFile.webkitGetAsEntry(),second=mediaDragFile.webkitGetAsEntry();mediaDragEntries.push(first,second);
  const file=mediaDragFile.getAsFile();mediaDragFiles.push(file);
  mediaDragChecks.push(first!==second&&first instanceof FileSystemEntry&&second instanceof FileSystemEntry&&first.isFile&&!first.isDirectory&&first.name==="\u03a9\u0000\ufffd\ud83d\ude00.txt"&&second.name===first.name&&mediaDragText.webkitGetAsEntry()===null&&file instanceof File&&file!==mediaDragInput&&file.name===first.name&&file.type==="text/plain"&&file.size===3);
  return mediaDragReturn;
 };player[name]=replacement;mediaDragChecks.push(player[name]===replacement&&!Object.hasOwn(player,name));
}
document.body.appendChild(mediaDragAudio);void mediaDragAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('media-drag-audio')?) == voidptr(created)
	input := runtime.native_file(runtime.evaluate_host_value('mediaDragInput')!)!
	assert input.raw_bytes() == [u8(0), 255, 65] && input.last_modified() == 7
	text_item := list.item(0)?
	file_item := list.item(1)?
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('mediaDragText')!)!) == voidptr(text_item)
	assert voidptr(runtime.native_data_transfer_item(runtime.evaluate_host_value('mediaDragFile')!)!) == voidptr(file_item)
	mut app := media_drag_handler_app(owner, document, runtime)
	mut delivery_count := 0
	for type_ in ['drag', 'dragend', 'dragenter', 'dragleave', 'dragover', 'dragstart', 'drop'] {
		for id in ['video', 'media-drag-audio'] {
			target := document.get_element_by_id(id)?
			other := if id == 'video' { 'mediaDragAudio' } else { 'video' }
			runtime.evaluate_host('mediaDragOrder=[];mediaDragTrusted=true;mediaDragReturn=0;0')!
			event := media_drag_handler_event(document, type_, transfer)
			stamp := event.time_stamp()
			assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event)
			assert runtime.evaluate_host('mediaDragOrder.join(",")==="${id}:${type_}:before,${id}:${type_}:handler,${id}:${type_}:after"&&mediaDragChecks.every(Boolean)')! == 'true'
			wrapper := runtime.evaluate_host_value('mediaDragSaved[${delivery_count}]')!
			assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
			assert runtime.javascript_event(event)! == wrapper
			assert event.is_trusted() && !event.default_prevented()
			drag := unsafe { &html.DragEvent(event) }
			assert voidptr(drag.data_transfer()?) == voidptr(transfer)
			assert runtime.evaluate_host('mediaDragSaved[${delivery_count}].clientX===11.5&&mediaDragSaved[${delivery_count}].pageX===31.5&&mediaDragSaved[${delivery_count}].currentTarget===null&&window.event===undefined')! == 'true'
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.text_content()? == '${id}:${type_}:before,${id}:${type_}:handler,${id}:${type_}:after'
			assert !app.dispatch_javascript_event(type_, target)
			delivery_count++
			assert runtime.evaluate_host('(()=>{mediaDragTrusted=false;mediaDragReturn=false;const event=mediaDragSaved[${delivery_count - 1}],stamp=event.timeStamp;return ${other}.dispatchEvent(event)===false&&mediaDragSaved[${delivery_count}]===event&&!event.isTrusted&&event.defaultPrevented&&event.timeStamp===stamp&&event.currentTarget===null&&event.eventPhase===Event.NONE&&window.event===undefined&&mediaDragChecks.every(Boolean)})()')! == 'true'
			assert voidptr(runtime.native_event(runtime.evaluate_host_value('mediaDragSaved[${delivery_count}]')!)!) == voidptr(event)
			assert event.time_stamp() == stamp && !event.is_trusted() && event.default_prevented()
			assert voidptr(drag.data_transfer()?) == voidptr(transfer)
			app.poll_javascript_tasks()
			other_target := document.get_element_by_id(if id == 'video' { 'media-drag-audio' } else { 'video' })?
			assert !app.dispatch_javascript_event(type_, other_target)
			delivery_count++
		}
	}
	assert delivery_count == 28
	assert runtime.evaluate_host('mediaDragSaved.length===28&&mediaDragEntries.length===56&&new Set(mediaDragEntries).size===56&&mediaDragFiles.length===28&&new Set(mediaDragFiles).size===28&&mediaDragChecks.every(Boolean)&&mediaDragSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
	retained_entry := runtime.native_file_system_entry(runtime.evaluate_host_value('mediaDragEntries[0]')!)!
	retained_file := runtime.native_file(runtime.evaluate_host_value('mediaDragFiles[0]')!)!
	assert retained_file.raw_bytes() == input.raw_bytes()
	assert retained_entry.name_utf16().code_units() == input.name_utf16().code_units()
	list.remove(0)!
	assert text_item.mode() == none && voidptr(list.item(0)?) == voidptr(file_item)
	list.remove(0)!
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host(r'mediaDragList.length===0&&mediaDragText.kind===""&&mediaDragFile.kind===""&&mediaDragFile.getAsFile()===null&&mediaDragFile.webkitGetAsEntry()===null&&mediaDragEntries.every(entry=>entry.isFile&&!entry.isDirectory&&entry.name==="\u03a9\u0000\ufffd\ud83d\ude00.txt")&&mediaDragFiles.every(file=>file.name===mediaDragInput.name&&file.size===3)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	runtime.close()
	assert retained_entry.name_utf16().code_units() == input.name_utf16().code_units()
	assert retained_file.raw_bytes() == [u8(0), 255, 65] && file_item.mode() == none
	assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id('video')?) }, media_drag_handler_event(document, 'drop', none))
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_drag_handler_slots_keep_replacement_order_and_page_script_gate() {
	$if !darwin { return }
	mut owner, mut document := media_drag_handler_document('<video id="video"></video><div id="result">waiting</div>',
		'https://media-drag-slot-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mediaDragAudio=document.createElement("audio");mediaDragAudio.id="media-drag-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_drag_handler_guard(runtime)!
	media_drag_handler_probe(mut runtime, document)!
	created := runtime.native_event_target(runtime.evaluate_host_value('mediaDragAudio')!)!
	runtime.evaluate_host(r'
globalThis.mediaDragSlotOrder=[];globalThis.mediaDragSlotChecks=[];globalThis.mediaDragSlotSaved=[];globalThis.mediaDragObjectReads=0;globalThis.mediaDragSlotReturn=0;
for(const player of [video,mediaDragAudio]){
 player.addEventListener("drop",function(event){mediaDragSlotOrder.push(player.id+":before");mediaDragSlotChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&window.event===event&&__mediaDragHandlerContext())});
 player.ondrop=function(){mediaDragSlotOrder.push("obsolete")};
 player.addEventListener("drop",function(event){mediaDragSlotOrder.push(player.id+":after");mediaDragSlotChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&window.event===event);result.textContent=mediaDragSlotOrder.join(",")});
 const callback=function(event){mediaDragSlotOrder.push(player.id+":handler");mediaDragSlotSaved.push(event);mediaDragSlotChecks.push(arguments.length===1&&this===player&&event.target===player&&event.currentTarget===player&&event instanceof DragEvent&&event.isTrusted&&event.dataTransfer===null&&window.event===event&&__mediaDragHandlerContext());return mediaDragSlotReturn};player.ondrop=callback;mediaDragSlotChecks.push(player.ondrop===callback&&!Object.hasOwn(player,"ondrop"));
}
document.body.appendChild(mediaDragAudio);void mediaDragAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('media-drag-audio')?) == voidptr(created)
	mut app := media_drag_handler_app(owner, document, runtime)
	for id in ['video', 'media-drag-audio'] {
		target := document.get_element_by_id(id)?
		actual_target := unsafe { &dom.EventTarget(target) }
		player := if id == 'video' { 'video' } else { 'mediaDragAudio' }
		for returned in ['0', '""', 'null', 'undefined', 'new Boolean(false)', '({})', 'false'] {
			runtime.evaluate_host('mediaDragSlotOrder=[];mediaDragSlotReturn=${returned};0')!
			event := media_drag_handler_event(document, 'drop', none)
			assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event) == (returned != 'false')
			assert event.default_prevented() == (returned == 'false')
			assert runtime.evaluate_host('mediaDragSlotOrder.join(",")==="${id}:before,${id}:handler,${id}:after"&&mediaDragSlotChecks.every(Boolean)')! == 'true'
		}
		runtime.evaluate_host('${player}.ondrop=null;mediaDragSlotOrder=[];0')!
		assert actual_target.event_listener_list().len == 2
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, media_drag_handler_event(document, 'drop', none))
		assert runtime.evaluate_host('${player}.ondrop===null&&mediaDragSlotOrder.join(",")==="${id}:before,${id}:after"')! == 'true'
		runtime.evaluate_host('globalThis.mediaDragLegacyObject={get handleEvent(){mediaDragObjectReads++;throw "handleEvent"},[Symbol.toPrimitive](){mediaDragObjectReads++;throw "conversion"}};${player}.ondrop=mediaDragLegacyObject;mediaDragSlotOrder=[];0')!
		assert actual_target.event_listener_list().len == 3
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, media_drag_handler_event(document, 'drop', none))
		assert runtime.evaluate_host('${player}.ondrop===mediaDragLegacyObject&&mediaDragSlotOrder.join(",")==="${id}:before,${id}:after"&&mediaDragObjectReads===0')! == 'true'
		runtime.evaluate_host('${player}.ondrop=function(event){mediaDragSlotOrder.push("${id}:reactivated");mediaDragSlotSaved.push(event);mediaDragSlotChecks.push(this===${player}&&event.target===${player}&&event.currentTarget===${player}&&event.isTrusted&&window.event===event&&__mediaDragHandlerContext());return false};mediaDragSlotOrder=[];0')!
		owner.set_is_scripting_enabled(false)
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, media_drag_handler_event(document, 'drop', none))
		assert runtime.evaluate_host('mediaDragSlotOrder.length===0&&window.event===undefined')! == 'true'
		owner.set_is_scripting_enabled(true)
		assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, media_drag_handler_event(document, 'drop', none))
		assert runtime.evaluate_host('mediaDragSlotOrder.join(",")==="${id}:before,${id}:after,${id}:reactivated"&&mediaDragSlotChecks.every(Boolean)&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:before,${id}:after'
		for primitive in ['null', 'undefined', 'false', '0', '"return false"', 'Symbol("handler")', '1n'] {
			assert runtime.evaluate_host('${player}.ondrag=${primitive};${player}.ondrag===null')! == 'true'
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert runtime.evaluate_host('mediaDragSlotSaved.length===16&&mediaDragSlotSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&mediaDragSlotChecks.every(Boolean)&&mediaDragObjectReads===0&&window.event===undefined')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	runtime.close()
	for id in ['video', 'media-drag-audio'] {
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id(id)?) }, media_drag_handler_event(document, 'drop', none))
	}
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert runtime.libjs_vm().execution_context_stack().len == 0
}

fn test_raw_media_drag_attributes_stay_uncompiled_when_native_idl_handlers_replace_them() {
	$if !darwin { return }
	raw_source := 'globalThis.rawMediaDragRuns++'
	types := ['drag', 'dragend', 'dragenter', 'dragleave', 'dragover', 'dragstart', 'drop']
	mut attribute_parts := []string{}
	for type_ in types {
		attribute_parts << 'on${type_}="${raw_source}"'
	}
	attributes := attribute_parts.join(' ')
	mut owner, mut document := media_drag_handler_document('<video id="video" ${attributes}></video><div id="result">waiting</div>',
		'https://raw-media-drag-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mediaDragAudio=document.createElement("audio");mediaDragAudio.id="media-drag-audio";globalThis.rawMediaDragRuns=0;globalThis.rawMediaDragAssigned=0;globalThis.rawMediaDragChecks=[];0',
	], runtime, mut messages)
	assert messages == []
	assert media_drag_handler_guard(runtime)!
	media_drag_handler_probe(mut runtime, document)!
	target := runtime.native_event_target(runtime.evaluate_host_value('video')!)!
	video := document.get_element_by_id('video')?
	assert voidptr(target) == voidptr(video) && target.event_listener_list().len == 7
	for type_ in types {
		raw_handler := target.data.event_handler(type_) or {
			assert false, 'Missing raw media drag handler ${type_}'
			return
		}
		assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
		assert dom.event_target_dispatch_event(target, media_drag_handler_event(document, type_, none))
		assert runtime.evaluate_host('video.on${type_}===null&&rawMediaDragRuns===0')! == 'true'
		assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
		runtime.evaluate_host('video.on${type_}=function(event){rawMediaDragAssigned++;rawMediaDragChecks.push(arguments.length===1&&this===video&&event.type==="${type_}"&&event.target===video&&event.currentTarget===video&&event instanceof DragEvent&&event.isTrusted&&event.dataTransfer===null&&window.event===event&&__mediaDragHandlerContext());result.textContent="assigned:"+event.type;return false};0')!
		assigned := target.data.event_handler(type_) or {
			assert false, 'Missing assigned media drag handler ${type_}'
			return
		}
		assert voidptr(assigned) == voidptr(raw_handler) && assigned.value.kind == .object
		assert !dom.event_target_dispatch_event(target, media_drag_handler_event(document, type_, none))
		assert video.get_attribute('on${type_}')? == raw_source
		assert runtime.evaluate_host('video.on${type_}=null;video.on${type_}===null&&rawMediaDragRuns===0&&rawMediaDragChecks.every(Boolean)&&window.event===undefined')! == 'true'
		assert !target.data.has_event_handler(type_)
		assert dom.event_target_dispatch_event(target, media_drag_handler_event(document, type_, none))
		assert video.get_attribute('on${type_}')? == raw_source
	}
	assert target.event_listener_list().len == 0
	assert runtime.evaluate_host('rawMediaDragAssigned===7&&rawMediaDragRuns===0&&rawMediaDragChecks.length===7&&rawMediaDragChecks.every(Boolean)&&window.event===undefined')! == 'true'
	mut app := media_drag_handler_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.text_content()? == 'assigned:drop'
	for type_ in types {
		assert video.get_attribute('on${type_}')? == raw_source
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
}
