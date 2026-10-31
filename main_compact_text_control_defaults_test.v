module main

import browserjs
import dom
import html

fn test_compact_control_defaults_use_native_clean_and_dirty_value_algorithms() {
	mut document := html.parse_document('<!doctype html><input id="field" value="initial"><textarea id="editor">seed</textarea>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(field.defaultValue!=="initial"||field.value!=="initial"||editor.defaultValue!=="seed"||editor.value!=="seed")throw new Error("initial defaults");
field.defaultValue="clean";if(field.value!=="clean"||field.getAttribute("value")!=="clean")throw new Error("clean input default");
field.value="edited";field.defaultValue="reset";
if(field.value!=="edited"||field.defaultValue!=="reset")throw new Error("dirty input default");
editor.defaultValue="first\r\nsecond";
if(editor.defaultValue!=="first\r\nsecond"||editor.textContent!=="first\r\nsecond"||editor.value!=="first\nsecond")throw new Error("textarea newlines");
editor.textContent="child replacement";if(editor.value!=="child replacement"||editor.defaultValue!=="child replacement")throw new Error("clean textarea children");
editor.value="edited\rvalue";editor.defaultValue="reset text";
if(editor.value!=="edited\nvalue"||editor.defaultValue!=="reset text"||editor.textContent!=="reset text")throw new Error("dirty textarea default");
'], runtime, mut messages)
	assert messages == []string{}
	area_element := document.get_element_by_id('editor') or { panic('missing editor') }
	mut area := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(area_element) })
	assert area.dirty_value
	assert area.value() == 'edited\nvalue'
	area.reset_algorithm()
	assert runtime.evaluate_host('editor.value')! == 'reset text'
}

fn test_detached_textarea_value_and_default_follow_the_native_owner_through_insertion() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const detached=document.createElement("textarea");detached.id="created";
if(detached.defaultValue!==""||detached.value!==""||Object.hasOwn(detached,"value")||!(detached instanceof HTMLTextAreaElement))throw new Error("new textarea");
detached.defaultValue="seed 🙂";detached.value="typed\r\ntext";
host.appendChild(detached);
if(host.firstChild!==detached||detached.value!=="typed\ntext"||detached.defaultValue!=="seed 🙂"||detached.textContent!=="seed 🙂")throw new Error("inserted control");
'], runtime, mut messages)
	assert messages == []string{}
	element := document.get_element_by_id('created') or { panic('missing created textarea') }
	model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	assert model.value() == 'typed\ntext'
	assert model.default_value() == 'seed 🙂'
}

fn test_control_value_descriptors_brand_before_conversion_and_support_tracking() {
	mut document := html.parse_document('<!doctype html><textarea id="editor"></textarea><input id="field"><div id="other"></div><svg><textarea id="foreign"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
function typeError(call){let caught=false;try{call()}catch(error){caught=error instanceof TypeError}if(!caught)throw new Error("expected TypeError");}
let conversions=0,traps=0;const value={toString(){conversions++;return "converted"}},proxy=new Proxy(editor,{get(){traps++;throw 0},getPrototypeOf(){traps++;throw 0}});
for(const [ctor,target,wrong] of [[HTMLInputElement,field,editor],[HTMLTextAreaElement,editor,field]])for(const property of ["value","defaultValue"]){
 const descriptor=Object.getOwnPropertyDescriptor(ctor.prototype,property);
 if(!descriptor.enumerable||!descriptor.configurable||typeof descriptor.get!=="function"||typeof descriptor.set!=="function")throw new Error("IDL descriptor");
 for(const receiver of [undefined,null,{},wrong,other,foreign,Object.create(target),proxy]){typeError(()=>descriptor.get.call(receiver));typeError(()=>descriptor.set.call(receiver,value));}
 typeError(()=>descriptor.set.call(target,Symbol()));
 const reason={};let original=false;try{descriptor.set.call(target,{toString(){throw reason}})}catch(error){original=error===reason}if(!original)throw new Error("conversion identity");
}
if(conversions||traps)throw new Error("branding order");
editor.defaultValue=null;if(editor.defaultValue!=="null"||editor.value!=="null")throw new Error("default DOMString");
editor.value=null;if(editor.value!=="")throw new Error("nullable value");
field.defaultValue=null;if(field.defaultValue!=="null")throw new Error("input default DOMString");
const descriptor=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,"value");let tracked=editor.value;
Object.defineProperty(editor,"value",{configurable:true,get(){return descriptor.get.call(this)},set(value){tracked=String(value);descriptor.set.call(this,value)}});
descriptor.set.call(editor,value);if(conversions!==1||editor.value!=="converted")throw new Error("one native conversion");
editor.value="controlled";if(editor.value!=="controlled"||tracked!=="controlled")throw new Error("value tracker");
'], runtime, mut messages)
	assert messages == []string{}
}
