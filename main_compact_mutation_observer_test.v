module main

import browserjs
import html
import platform

fn test_compact_mutation_observer_delivers_native_attributes_in_promise_fifo_order() {
	mut document := html.parse_document('<!doctype html><div id="box" data-value="old"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.order=[];globalThis.savedRecords=[];
globalThis.observer=new MutationObserver(function(records,owner){
 if(this!==observer||owner!==observer)throw new Error("callback receiver");
 savedRecords.push(...records);order.push("observer:"+records.length);
});
observer.observe(box,{attributeOldValue:true,attributeFilter:["data-value"]});
Promise.resolve().then(()=>order.push("before"));
box.setAttribute("data-value","new");box.setAttribute("data-value","new");box.setAttribute("unwatched","skip");
Promise.resolve().then(()=>order.push("after"));order.push("sync");
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host(r'
order.join(",")==="sync,before,observer:2,after"&&savedRecords.length===2&&savedRecords.every(record=>record instanceof MutationRecord&&record.target===box&&record.type==="attributes"&&record.attributeName==="data-value"&&record.attributeNamespace===null&&record.addedNodes instanceof NodeList&&record.addedNodes.length===0&&record.removedNodes.length===0&&record.nextSibling===null)&&savedRecords[0].oldValue==="old"&&savedRecords[1].oldValue==="new";
')! == 'true'
}

fn test_compact_mutation_observer_child_records_are_snapshots_and_take_records_disconnect_work() {
	mut document := html.parse_document('<!doctype html><div id="parent"><span id="child">old</span><i id="next"></i></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.calls=0;const observer=new MutationObserver(()=>calls++);
observer.observe(parent,{subtree:true,childList:true,characterDataOldValue:true,attributes:true});
const text=child.firstChild;text.data="new";parent.removeChild(child);child.setAttribute("data-removed","1");
globalThis.records=observer.takeRecords();
if(records.length!==3||records[0].type!=="characterData"||records[0].target!==text||records[0].oldValue!=="old")throw new Error("native text records "+records.length);
const removal=records[1];if(removal.target!==parent||removal.removedNodes[0]!==child||removal.removedNodes.length!==1||removal.addedNodes.length!==0||removal.nextSibling!==next||removal.previousSibling!==null)throw new Error("native child list");
observer.disconnect();parent.appendChild(child);child.setAttribute("data-removed","2");
if(observer.takeRecords().length!==0||removal.removedNodes[0]!==child||removal.removedNodes.length!==1)throw new Error("disconnect and snapshot");
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('calls===0&&records[2].target===child&&records[2].oldValue===null')! == 'true'
}

fn test_compact_mutation_observer_native_changes_and_dictionary_validation() {
	mut document := html.parse_document('<!doctype html><div id="box"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.delivered=[];class Derived extends MutationObserver{};
globalThis.observer=new Derived(records=>delivered.push(...records));
if(!(observer instanceof Derived)||!(observer instanceof MutationObserver)||observer.constructor!==Derived)throw new Error("observer inheritance");
let brands=0;for(const invoke of [()=>MutationObserver.prototype.observe.call({},box,{}),()=>MutationObserver.prototype.takeRecords.call({}),()=>MutationObserver.prototype.disconnect.call({}),()=>observer.observe({},{}),()=>observer.observe(box,{}),()=>observer.observe(box,{attributes:false,attributeFilter:[]}),()=>observer.observe(box,{attributes:true,attributeFilter:{length:1,0:"id"}})])try{invoke()}catch(error){if(error instanceof TypeError)brands++}if(brands!==7)throw new Error("observer validation "+brands);
const order=[],options={};for(const name of ["attributeFilter","attributeOldValue","attributes","characterData","characterDataOldValue","childList","subtree"])Object.defineProperty(options,name,{get(){order.push(name);return name==="attributes"?true:undefined}});
observer.observe(box,options);if(order.join(",")!=="attributeFilter,attributeOldValue,attributes,characterData,characterDataOldValue,childList,subtree")throw new Error("dictionary order");
const marker={};let original=false;try{observer.observe(box,{get attributes(){throw marker}})}catch(error){original=error===marker}if(!original)throw new Error("original dictionary exception");
'], runtime, mut messages)
	assert messages == []string{}
	mut box := document.get_element_by_id('box') or { panic('missing box') }
	box.set_attribute_value('data-native', '1')
	assert runtime.evaluate_host('delivered.length')! == '0'
	// Native mutation queues a real engine microtask; enter the realm to service
	// its checkpoint, then inspect the delivered native target.
	runtime.evaluate_host('void 0')!
	assert runtime.evaluate_host('delivered.length===1&&delivered[0].target===box&&delivered[0].target.getAttribute("data-native")==="1"&&delivered[0].attributeName==="data-native"')! == 'true'
}

fn test_compact_mutation_observer_callback_mutations_queue_another_job_and_report_exceptions() {
	mut document := html.parse_document('<!doctype html><div id="box"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.order=[];let first=true;
const observer=new MutationObserver(records=>{
 order.push(records[0].attributeName);
 if(first){first=false;box.setAttribute("data-second","2");throw new Error("observer callback marker");}
});observer.observe(box,{attributes:true});
box.setAttribute("data-first","1");Promise.resolve().then(()=>order.push("promise"));
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('order.join(",")==="data-first,promise,data-second"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert settings.realm().reported_exceptions[0].error_in_promise == .no
}

fn test_compact_mutation_observer_batches_detached_document_targets_with_the_owning_realm() {
	mut document := html.parse_document('<!doctype html><div id="box"></div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.calls=0;globalThis.nativeRecords=[];
const other=document.implementation.createHTMLDocument("other");globalThis.detached=other.createElement("div");other.body.appendChild(detached);
globalThis.observer=new MutationObserver(records=>{calls++;nativeRecords.push(...records)});
observer.observe(box,{attributes:true});observer.observe(detached,{attributes:true});
'], runtime, mut messages)
	assert messages == []string{}
	mut scratch := platform.begin_thread_scratch('compact mutation observer lifetime')
	runtime.evaluate_host('box.setAttribute("data-retained","first");detached.setAttribute("data-retained","second");')!
	scratch.finish()
	assert runtime.evaluate_host('calls===1&&nativeRecords.length===2&&nativeRecords[0].target===box&&nativeRecords[1].target===detached&&detached.ownerDocument.title==="other"')! == 'true'
	// Closing the runtime disconnects observers before its detached documents
	// retire, including when a saved record still refers to one of their nodes.
}
