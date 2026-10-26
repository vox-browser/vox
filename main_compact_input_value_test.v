module main

import browserjs
import dom
import html
import platform
import time

fn test_compact_input_value_updates_native_text_placeholder_and_dirty_value() {
	mut document := html.parse_document('<!doctype html><input id="search" placeholder="Поиск и выбор мест" value="initial">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	mut app := &BrowserApp{ document: document, js_runtime: runtime }
	app.relayout(320, 312)
	input := document.get_element_by_id('search')?
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	assert runtime.evaluate_host('search.setAttribute("value","clean default");search.value')! == 'clean default'
	assert model.text_node_?.data() == 'clean default'
	assert runtime.evaluate_host(r'search.value="a\nb\rc";search.value')! == 'abc'
	assert model.value() == 'abc'
	assert model.text_node_?.data() == 'abc'
	assert model.placeholder_value() == none
	assert runtime.evaluate_host('search.getAttribute("value")')! == 'clean default'
	assert runtime.evaluate_host('search.setAttribute("value","new default");search.value')! == 'abc'
	assert model.value() == 'abc'
	assert runtime.evaluate_host('search.value=null;search.value')! == ''
	assert model.value() == ''
	assert model.text_node_?.data() == ''
	assert model.placeholder_value()? == 'Поиск и выбор мест'
	assert model.placeholder_element_?.get_attribute_value('style').contains('display:block')
	assert runtime.evaluate_host('search.setAttribute("placeholder","Changed prompt");search.value')! == ''
	assert model.placeholder_text_node_?.data() == 'Changed prompt'
	assert runtime.evaluate_host('search.value=undefined;search.value')! == 'undefined'
	assert model.value() == 'undefined'
	model.set_value('native edit')!
	assert runtime.evaluate_host('search.value')! == 'native edit'
	assert messages == []string{}
}

fn test_compact_input_value_uses_native_owner_before_insertion_and_for_default_modes() {
	mut document := html.parse_document('<!doctype html><div id="host"></div><input id="number" type="number"><input id="checkbox" type="checkbox"><input id="upload" type="file">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const detached=document.createElement("input");
if(!(detached instanceof HTMLInputElement)||!(detached instanceof HTMLElement)||detached.value!=="")throw new Error("detached input interface");
detached.id="created";detached.value="before\ninsertion";
if(detached.value!=="beforeinsertion")throw new Error("detached sanitization");
host.appendChild(detached);
if(host.firstChild!==detached||detached.value!=="beforeinsertion")throw new Error("inserted input identity");
detached.setAttribute("type","number");detached.value="not a number";
if(detached.value!=="")throw new Error("live type sanitization");
detached.value="42";
number.value="invalid";if(number.value!=="")throw new Error("number sanitization");
number.value=12.5;if(number.value!=="12.5")throw new Error("numeric conversion");
if(checkbox.value!=="on")throw new Error("default-on value");
checkbox.value="checked value";
if(checkbox.getAttribute("value")!=="checked value")throw new Error("reflected checkbox value");
upload.value=null;if(upload.value!=="")throw new Error("clear file input");
let invalid=false;try{upload.value="private.txt"}catch(error){invalid=error instanceof DOMException&&error.name==="InvalidStateError"}
if(!invalid||upload.value!=="")throw new Error("file input restriction");
console.log("input modes passed");
'], runtime, mut messages)
	assert messages == ['input modes passed']
	created := document.get_element_by_id('created')?
	assert html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(created) }).value() == '42'
	assert document.get_element_by_id('checkbox')?.get_attribute_value('value') == 'checked value'
}

fn test_compact_input_value_descriptor_brands_before_conversion_and_supports_react_tracking() {
	mut document := html.parse_document('<!doctype html><input id="control"><div id="other"></div><svg><input id="foreign"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const descriptor=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,"value");
if(!descriptor.enumerable||!descriptor.configurable||typeof descriptor.get!=="function"||typeof descriptor.set!=="function"||control.hasOwnProperty("value"))throw new Error("value descriptor");
if(Object.getPrototypeOf(HTMLInputElement)!==HTMLElement||Object.getPrototypeOf(HTMLInputElement.prototype)!==HTMLElement.prototype)throw new Error("input interface inheritance");
let conversions=0,traps=0;
const value={toString(){conversions++;return "converted"}},proxy=new Proxy(control,{get(){traps++;throw new Error("get trap")},getPrototypeOf(){traps++;throw new Error("prototype trap")}});
function typeError(callback){let failed=false;try{callback()}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("expected TypeError")}
for(const receiver of [undefined,null,{},other,foreign,Object.create(control),proxy]){
 typeError(()=>descriptor.get.call(receiver));typeError(()=>descriptor.set.call(receiver,value));
}
if(conversions||traps)throw new Error("brand before conversion");
typeError(()=>descriptor.set.call(control,Symbol("invalid")));
const reason={};let original=false;try{descriptor.set.call(control,{toString(){throw reason}})}catch(error){original=error===reason}
if(!original)throw new Error("conversion exception");
control.value=value;if(conversions!==1||control.value!=="converted")throw new Error("one conversion");
let tracked=control.value;
Object.defineProperty(control,"value",{configurable:true,get(){return descriptor.get.call(this)},set(value){tracked=String(value);descriptor.set.call(this,value)}});
control.value="controlled";
if(tracked!=="controlled"||control.value!=="controlled")throw new Error("React value tracker");
console.log("input descriptor passed");
'], runtime, mut messages)
	assert messages == ['input descriptor passed']
	control := document.get_element_by_id('control')?
	assert html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(control) }).value() == 'controlled'
}

fn test_compact_input_value_timer_invalidates_retained_paint() {
	mut document := html.parse_document('<!doctype html><input id="search" placeholder="Search">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	mut app := &BrowserApp{ document: document, js_runtime: runtime }
	app.relayout(320, 312)
	runtime.take_document_state_dirty()
	runtime.take_document_replay_effects()
	paint := app.paint_display_list
	assert runtime.evaluate_host('search.value')! == ''
	assert !runtime.take_document_state_dirty()
	runtime.evaluate_host('globalThis.valueTimerDone=false;setTimeout(()=>{search.value="query";valueTimerDone=true;},1)')!
	deadline := time.sys_mono_now() + 2_000_000_000
	for runtime.evaluate_host('valueTimerDone')! != 'true' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.005)
	}
	assert runtime.evaluate_host('valueTimerDone')! == 'true'
	app.poll_javascript_tasks()
	input := document.get_element_by_id('search')?
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	assert model.value() == 'query'
	assert model.text_node_?.data() == 'query'
	assert model.placeholder_value() == none
	assert voidptr(app.paint_display_list) != voidptr(paint)
}
