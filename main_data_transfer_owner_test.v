module main

import browserjs
import dom
import html
import page
import time

fn data_transfer_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn data_transfer_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof DataTransfer==="function"&&(()=>{const prototype=DataTransfer.prototype;return ["getData","setData","clearData"].every(name=>typeof prototype[name]==="function"&&Function.prototype.toString.call(prototype[name]).includes("[native code]"))&&["types","dropEffect","effectAllowed"].every(name=>typeof Object.getOwnPropertyDescriptor(prototype,name).get==="function")})()')! == 'true'
}

fn data_transfer_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn data_transfer_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

// Exercise the actual DOM owner dispatcher, not the Page drag-log route.
// Public string-store operations do not add physical drag delivery or public
// DataTransferItemList/FileList/drag-image bindings.
fn test_public_data_transfer_stays_live_through_owner_drag_dispatch_and_redispatch() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		data_transfer_owner_document('http://data-transfer-public-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.transferAudio=document.createElement("audio");transferAudio.id="transfer-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert data_transfer_owner_guard(runtime)!
	assert document.get_element_by_id('transfer-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('transferAudio')!)!
	runtime.evaluate_host(r'
globalThis.ownerTransfer=new DataTransfer();globalThis.ownerTransferChecks=[];globalThis.ownerTransferSaved=[];globalThis.ownerTransferEvents=[];globalThis.ownerTransferOrder=[];globalThis.ownerTransferStage="native";
const empty=ownerTransfer.types;
ownerTransferChecks.push(Object.getPrototypeOf(ownerTransfer)===DataTransfer.prototype&&ownerTransfer instanceof DataTransfer&&Object.prototype.toString.call(ownerTransfer)==="[object DataTransfer]"&&ownerTransfer.dropEffect==="none"&&ownerTransfer.effectAllowed==="none"&&empty.length===0&&Object.isFrozen(empty)&&ownerTransfer.types===empty);
ownerTransfer.setData("TeXt","initial owner payload");ownerTransfer.setData("URL","https://owner.example.test/");
globalThis.ownerTransferInitialTypes=ownerTransfer.types;
ownerTransferChecks.push(ownerTransfer.getData("TEXT")==="initial owner payload"&&ownerTransfer.getData("url")==="https://owner.example.test/"&&ownerTransferInitialTypes.join(",")==="text/plain,text/uri-list"&&ownerTransferInitialTypes===ownerTransfer.types&&Object.isFrozen(ownerTransferInitialTypes)&&empty.length===0);
ownerTransfer.dropEffect="copy";ownerTransfer.effectAllowed="copyMove";
for(const player of [video,transferAudio]){
 player.addEventListener("drop",function(event){ownerTransferOrder.push("before:"+player.id);ownerTransferChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("drop",function(event){
  ownerTransferOrder.push("store:"+player.id);ownerTransferSaved.push(event);
  const transfer=event.dataTransfer,oldTypes=transfer.types;
  ownerTransferChecks.push(transfer===ownerTransfer&&event instanceof DragEvent&&Object.getPrototypeOf(event)===DragEvent.prototype&&!event.isTrusted&&event.cancelable&&event.view===window&&transfer.types===oldTypes&&Object.isFrozen(oldTypes));
  transfer.setData("text",ownerTransferStage+":"+player.id);transfer.setData("application/owner",player.id);transfer.clearData("URL");transfer.dropEffect="move";transfer.effectAllowed="linkMove";transfer.dropEffect="invalid";transfer.effectAllowed="invalid";
  ownerTransferChecks.push(transfer.getData("text/plain")===ownerTransferStage+":"+player.id&&transfer.getData("url")===""&&transfer.getData("application/owner")===player.id&&transfer.dropEffect==="move"&&transfer.effectAllowed==="linkMove"&&transfer.types!==oldTypes&&Object.isFrozen(transfer.types)&&transfer.types===transfer.types&&transfer.types.join(",")==="text/plain,application/owner");
  event.preventDefault();result.textContent=transfer.getData("text")+":"+ownerTransferSaved.length;
 });
 player.addEventListener("drop",function(event){ownerTransferOrder.push("after:"+player.id);ownerTransferChecks.push(event.defaultPrevented&&event.dataTransfer===ownerTransfer&&window.event===event)});
 ownerTransferEvents.push(new DragEvent("drop",{bubbles:true,cancelable:true,view:window,dataTransfer:ownerTransfer}));
}
document.body.appendChild(transferAudio);void transferAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('transfer-audio')?) == voidptr(created_target)
	transfer_wrapper := runtime.evaluate_host_value('ownerTransfer')!
	mut transfer := runtime.native_data_transfer(transfer_wrapper)!
	assert runtime.javascript_data_transfer(transfer)! == transfer_wrapper
	assert transfer.mode()? == .read_write
	assert transfer.get_data('text') == 'initial owner payload'
	assert transfer.types() == ['text/plain', 'text/uri-list']
	assert transfer.drop_effect() == 'copy' && transfer.effect_allowed() == 'copyMove'
	mut app := data_transfer_owner_app(owner, document, runtime)
	for index, id in ['video', 'transfer-audio'] {
		target := document.get_element_by_id(id)?
		wrapper := runtime.evaluate_host_value('ownerTransferEvents[${index}]')!
		event := runtime.native_event(wrapper)!
		drag := unsafe { &html.DragEvent(event) }
		assert event.interface_ == .drag_event && !event.is_trusted()
		assert drag.data_transfer()? == transfer
		stamp := event.time_stamp()
		runtime.evaluate_host('ownerTransferStage="native";0')!
		assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event)
		assert event.default_prevented() && event.time_stamp() == stamp
		assert voidptr(event.target()?) == voidptr(target)
		assert runtime.javascript_event(event)! == wrapper
		assert transfer.get_data('text') == 'native:${id}'
		assert transfer.get_data('application/owner') == id
		assert transfer.types() == ['text/plain', 'application/owner']
		assert transfer.drop_effect() == 'move' && transfer.effect_allowed() == 'linkMove'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'native:${id}:${index * 2 + 1}'
		assert runtime.evaluate_host('(()=>{const event=ownerTransferEvents[${index}],stamp=event.timeStamp;ownerTransferStage="redispatch";return event.target.dispatchEvent(event)===false&&ownerTransferSaved[${index * 2}]===event&&ownerTransferSaved[${index * 2 + 1}]===event&&event.dataTransfer===ownerTransfer&&event.timeStamp===stamp&&event.currentTarget===null&&window.event===undefined&&ownerTransferChecks.every(Boolean)})()')! == 'true'
		assert runtime.native_event(runtime.evaluate_host_value('ownerTransferSaved[${index * 2 + 1}]')!)! == event
		assert transfer.get_data('text') == 'redispatch:${id}'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'redispatch:${id}:${index * 2 + 2}'
		assert !app.dispatch_javascript_event('drop', target)
		assert runtime.evaluate_host('ownerTransferSaved.length===${index * 2 + 2}&&ownerTransfer.types===ownerTransfer.types')! == 'true'
	}
	assert runtime.evaluate_host(r'ownerTransferChecks.every(Boolean)&&ownerTransferSaved.length===4&&ownerTransferOrder.join(",")==="before:video,store:video,after:video,before:video,store:video,after:video,before:transfer-audio,store:transfer-audio,after:transfer-audio,before:transfer-audio,store:transfer-audio,after:transfer-audio"&&ownerTransferInitialTypes.join(",")==="text/plain,text/uri-list"&&Object.isFrozen(ownerTransferInitialTypes)')! == 'true'
	runtime.evaluate_host(r'ownerTransfer.clearData();0')!
	assert transfer.length() == 0 && transfer.types() == []string{}
	assert runtime.evaluate_host('ownerTransfer.types.length===0&&Object.isFrozen(ownerTransfer.types)&&ownerTransfer.types===ownerTransfer.types&&ownerTransfer.getData("text")===""')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context() && settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_existing_native_data_transfer_respects_store_modes_in_real_owner_listener() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		data_transfer_owner_document('https://data-transfer-native-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.nativeTransferAudio=document.createElement("audio");nativeTransferAudio.id="native-transfer-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert data_transfer_owner_guard(runtime)!
	mut store := html.DragDataStore.create()
	store.mode = .read_write
	mut transfer := html.DataTransfer.create(store)
	transfer.set_data('text', 'native initial')
	data_transfer_owner_export(mut runtime, '__nativeOwnerTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.nativeOwnerTransfer=__nativeOwnerTransfer();globalThis.nativeOwnerChecks=[];globalThis.nativeOwnerSaved=[];globalThis.nativeOwnerExpected="native initial";globalThis.nativeOwnerWritable=true;globalThis.nativeOwnerTrusted=true;
globalThis.nativeOwnerInitialTypes=nativeOwnerTransfer.types;
nativeOwnerChecks.push(nativeOwnerTransfer instanceof DataTransfer&&Object.getPrototypeOf(nativeOwnerTransfer)===DataTransfer.prototype&&nativeOwnerTransfer.types===nativeOwnerInitialTypes&&Object.isFrozen(nativeOwnerInitialTypes)&&nativeOwnerInitialTypes.join(",")==="text/plain");
for(const player of [video,nativeTransferAudio])player.addEventListener("dragover",function(event){
 const transfer=event.dataTransfer,oldTypes=transfer.types;
 nativeOwnerSaved.push(event);nativeOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event&&event.isTrusted===nativeOwnerTrusted&&transfer===nativeOwnerTransfer&&transfer.getData("text")===nativeOwnerExpected);
 transfer.setData("text","listener write");transfer.setData("application/native","listener added");transfer.clearData("missing");transfer.effectAllowed="copyLink";transfer.dropEffect="copy";
 nativeOwnerChecks.push(transfer.getData("text")===(nativeOwnerWritable?"listener write":nativeOwnerExpected)&&transfer.getData("application/native")===(nativeOwnerWritable?"listener added":"")&&transfer.dropEffect==="copy"&&transfer.effectAllowed===(nativeOwnerWritable?"copyLink":"none")&&transfer.types===transfer.types&&Object.isFrozen(transfer.types)&&(nativeOwnerWritable?transfer.types!==oldTypes:transfer.types===oldTypes));
 event.preventDefault();result.textContent=player.id+":"+nativeOwnerSaved.length;
});
document.body.appendChild(nativeTransferAudio);void nativeTransferAudio.paused;0
')!
	mut app := data_transfer_owner_app(owner, document, runtime)
	for index, id in ['video', 'native-transfer-audio'] {
		target := document.get_element_by_id(id)?
		if index == 1 {
			store.mode = .read_only
			transfer.set_effect_allowed_internal('none')
			runtime.evaluate_host('nativeOwnerExpected="listener write";nativeOwnerWritable=false;0')!
			// Clear the first listener's extra type while still writable.
			store.mode = .read_write
			transfer.clear_data('application/native')
			store.mode = .read_only
		}
		drag := html.DragEvent.create('dragover', html.DragEventInit{
			MouseEventInit: dom.MouseEventInit{
				EventModifierInit: dom.EventModifierInit{
					UIEventInit: dom.UIEventInit{
						EventInit: dom.EventInit{
							cancelable: true
						}
						view: voidptr(document.get_window()?)
					}
				}
			}
			data_transfer: transfer
		}, 0, 0, 0, 0)
		event := unsafe { &dom.Event(drag) }
		stamp := event.time_stamp()
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event) == false
		wrapper := runtime.evaluate_host_value('nativeOwnerSaved[${index * 2}]')!
		assert runtime.native_event(wrapper)! == event && runtime.javascript_event(event)! == wrapper
		assert event.is_trusted() && event.default_prevented()
		assert drag.data_transfer()? == transfer
		assert runtime.native_data_transfer(runtime.evaluate_host_value('nativeOwnerSaved[${index * 2}].dataTransfer')!)! == transfer
		assert runtime.evaluate_host('nativeOwnerSaved[${index * 2}].dataTransfer===nativeOwnerTransfer&&nativeOwnerChecks.every(Boolean)&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == '${id}:${index * 2 + 1}'
		runtime.evaluate_host('nativeOwnerExpected="listener write";nativeOwnerTrusted=false;0')!
		assert runtime.evaluate_host('(()=>{const event=nativeOwnerSaved[${index * 2}],stamp=event.timeStamp;return event.target.dispatchEvent(event)===false&&nativeOwnerSaved[${index * 2 + 1}]===event&&event.dataTransfer===nativeOwnerTransfer&&event.timeStamp===stamp&&!event.isTrusted&&event.currentTarget===null&&window.event===undefined&&nativeOwnerChecks.every(Boolean)})()')! == 'true'
		assert event.time_stamp() == stamp && !event.is_trusted() && drag.data_transfer()? == transfer
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == '${id}:${index * 2 + 2}'
		assert !app.dispatch_javascript_event('dragover', target)
		runtime.evaluate_host('nativeOwnerTrusted=true;0')!
	}
	assert transfer.get_data('text') == 'listener write' && transfer.effect_allowed() == 'none'
	runtime.evaluate_host('globalThis.nativeOwnerModeTypes=nativeOwnerTransfer.types;0')!
	store.mode = .protected
	assert runtime.evaluate_host(r'(()=>{const transfer=nativeOwnerTransfer;transfer.setData("text","hidden write");transfer.clearData();transfer.effectAllowed="all";transfer.dropEffect="link";return transfer.getData("text")===""&&transfer.types===nativeOwnerModeTypes&&transfer.types.join(",")==="text/plain"&&transfer.effectAllowed==="none"&&transfer.dropEffect==="link"})()')! == 'true'
	store.mode = .read_only
	assert transfer.get_data('text') == 'listener write'
	assert runtime.evaluate_host('nativeOwnerTransfer.getData("text")==="listener write"&&nativeOwnerTransfer.types===nativeOwnerModeTypes')! == 'true'
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host(r'(()=>{const transfer=nativeOwnerTransfer;transfer.setData("text","detached write");transfer.clearData();transfer.effectAllowed="all";transfer.dropEffect="move";return transfer.getData("text")===""&&transfer.types!==nativeOwnerModeTypes&&transfer.types.length===0&&Object.isFrozen(transfer.types)&&transfer.types===transfer.types&&transfer.effectAllowed==="none"&&transfer.dropEffect==="move"&&nativeOwnerSaved.every(event=>event.dataTransfer===transfer)&&nativeOwnerInitialTypes.join(",")==="text/plain"})()')! == 'true'
	assert runtime.javascript_data_transfer(transfer)! == runtime.evaluate_host_value('nativeOwnerTransfer')!
	assert transfer.mode() == none && transfer.length() == 0
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
