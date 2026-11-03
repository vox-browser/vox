module main

import browserjs
import dom
import html
import layout

fn shared_properties_document(markup string) !&dom.Document {
	u := dom.URL{ value: 'https://shared-properties.test/' }
	mut document := html.create_navigation_document(u, u.origin(), none)!
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, markup)
	allocations.finish()
	return document
}

fn retire_shared_properties_document(mut document dom.Document) {
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	layout.retire_native_document_layout(handle)
	document.release_native_storage()
}

fn test_compact_common_accessors_share_functions_and_preserve_own_descriptors() {
	mut document := shared_properties_document('<!doctype html><div id="first">one</div><div id="second">two</div><svg id="drawing"></svg>')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		retire_shared_properties_document(mut document)
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const originals=[first,second,drawing],wrappers=originals.slice();
for(let i=0;i<256;i++)wrappers.push(document.createElement(i%2?"span":"div"));
for(const name of ["id","firstChild","parentNode","parentElement","textContent","innerHTML","className","name","hidden","disabled","checked","indeterminate","complete","data","sheet"]){
 const getter=Object.getOwnPropertyDescriptor(first,name).get,setter=Object.getOwnPropertyDescriptor(first,name).set;
 for(const object of wrappers){
  const descriptor=Object.getOwnPropertyDescriptor(object,name);
  if(!descriptor||descriptor.get!==getter||descriptor.set!==setter||descriptor.enumerable||descriptor.configurable)throw new Error("unshared descriptor "+name);
 }
}
first.id="renamed";second.className="changed";drawing.id="svg-renamed";
if(first.id!=="renamed"||second.className!=="changed"||drawing.id!=="svg-renamed")throw new Error("receiver state");
globalThis.sharedPropertyResult=wrappers.length;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('sharedPropertyResult')! == '259'
	assert document.get_element_by_id('renamed') != none
	assert document.get_element_by_id('second')?.get_attribute_value('class') == 'changed'
	assert document.get_element_by_id('svg-renamed') != none
}

fn test_shared_accessors_use_registered_receivers_and_preserve_conversion_exceptions() {
	mut document := shared_properties_document('<!doctype html><div id="first"></div><div id="second"></div>')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		retire_shared_properties_document(mut document)
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const id=Object.getOwnPropertyDescriptor(first,"id"),classes=Object.getOwnPropertyDescriptor(first,"className");
if(id.get.call(second)!=="second")throw new Error("borrowed getter");
id.set.call(second,"renamed-second");
if(first.id!=="first"||second.id!=="renamed-second")throw new Error("borrowed setter");
let conversions=0;
for(const receiver of [null,undefined,{},Object.create(first),{__state:first.__state}]){
 for(const operation of [()=>id.get.call(receiver),()=>classes.set.call(receiver,{toString(){conversions++;return "forged";}})]){
  let rejected=false;try{operation();}catch(error){rejected=error instanceof TypeError;}
  if(!rejected)throw new Error("unregistered receiver");
 }
}
if(conversions)throw new Error("conversion before receiver validation");
const token={original:true};let exact=false;
try{classes.set.call(second,{toString(){throw token;}});}catch(error){exact=error===token;}
if(!exact||second.className!=="")throw new Error("conversion exception");
classes.set.call(second,{toString(){return "converted";}});
globalThis.sharedReceiverResult=second.className;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('sharedReceiverResult')! == 'converted'
	assert document.get_element_by_id('renamed-second')?.get_attribute_value('class') == 'converted'
}

fn test_shared_control_and_content_properties_replay_to_the_native_models() {
	mut document := shared_properties_document('<!doctype html><input id="control" type="checkbox"><div id="text">old text</div><div id="content"><b>old</b></div><section id="parent"><span id="child"></span></section>')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		retire_shared_properties_document(mut document)
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
control.checked=true;control.indeterminate=true;control.disabled=true;control.name="choice";
if(!control.checked||!control.indeterminate||control.name!=="choice")throw new Error("control properties");
const textOwner=document.getElementById("text"),parentOwner=document.getElementById("parent");
textOwner.textContent="new text";
if(textOwner.textContent!=="new text")throw new Error("text replay");
content.innerHTML="<i>new markup</i>";content.hidden=true;
if(!content.hidden||content.firstChild.localName!=="i"||content.textContent!=="new markup")throw new Error("markup replay");
content.hidden=false;
if(content.hidden||child.parentNode!==parentOwner||child.parentElement!==parentOwner)throw new Error("live parent or attribute state");
globalThis.sharedControlResult="ok";
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('sharedControlResult')! == 'ok'
	control := document.get_element_by_id('control')?
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(control) })
	assert model.checked()
	assert model.indeterminate()
	assert control.has_attribute('disabled')
	assert control.get_attribute_value('name') == 'choice'
	content := document.get_element_by_id('content')?
	assert content.as_node().text_content()? == 'new markup'
	assert !content.has_attribute('hidden')
}

fn test_native_fragments_do_not_acquire_the_element_property_brand() {
	mut document := shared_properties_document('<!doctype html><div id="original"></div>')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		retire_shared_properties_document(mut document)
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fragment=document.createDocumentFragment();
if(Object.getOwnPropertyDescriptor(fragment,"id"))throw new Error("native fragment has an element accessor");
fragment.id="fragment";fragment.className="legacy";
const id=Object.getOwnPropertyDescriptor(original,"id");
if(fragment.id!=="fragment"||fragment.className!=="legacy"||fragment.parentNode!==null||fragment.parentElement!==null)throw new Error("fragment properties");
let propertyRejected=false;try{id.get.call(fragment);}catch(error){propertyRejected=error instanceof TypeError;}
if(!propertyRejected)throw new Error("native fragment acquired property brand");
let rejected=false;
try{Object.getOwnPropertyDescriptor(Element.prototype,"tagName").get.call(fragment);}catch(error){rejected=error instanceof TypeError;}
if(!rejected)throw new Error("fragment acquired Element brand");
globalThis.sharedFragmentResult="ok";
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('sharedFragmentResult')! == 'ok'
}
