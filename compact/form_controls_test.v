module main

import browserjs
import html
import platform

fn test_compact_form_controls_follow_native_association_and_tree_order() {
	mut document := html.parse_document('<!doctype html><input id="external" form="owner" name="outside"><form id="owner"><textarea id="composer" name="prompt"></textarea><input id="picture" type="image"><input id="moved" form="other"><button id="send" name="submitter">Send</button></form><form id="other"></form>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const controls=owner.elements;
if(composer.form!==owner||send.form!==owner||external.form!==owner||moved.form!==other)throw new Error("native control form owners");
if(controls!==owner.elements||!(controls instanceof HTMLFormControlsCollection)||!(controls instanceof HTMLCollection)||owner.length!==3)throw new Error("form collection identity "+JSON.stringify([controls===owner.elements,controls instanceof HTMLFormControlsCollection,controls instanceof HTMLCollection,owner.length,Array.from(controls,n=>n.id)]));
if(Array.from(controls,n=>n.id).join(",")!=="external,composer,send")throw new Error("native form ownership/order/image exclusion");
if(controls.namedItem("prompt")!==composer||controls.composer!==composer||controls.namedItem("")!==null||controls.item(9)!==null)throw new Error("named form controls");
external.setAttribute("form","other");if(controls.length!==2||other.elements.length!==2)throw new Error("reassociation");
if(external.form!==other)throw new Error("reassociated owner getter");
composer.name="edited";if(controls.namedItem("prompt")!==null||controls.namedItem("edited")!==composer)throw new Error("renamed control");
const extra=document.createElement("input");extra.name="extra";owner.appendChild(extra);
if(controls.length!==3||controls.namedItem("extra")!==extra)throw new Error("inserted control");
extra.remove();if(controls.length!==2)throw new Error("removed control");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_radio_node_list_is_live_and_uses_native_checked_values() {
	mut document := html.parse_document('<!doctype html><form id="owner"><input id="one" type="radio" name="choice" value="one" checked><input id="two" type="radio" name="choice" value="two"></form>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const group=owner.elements.namedItem("choice");
if(!(group instanceof RadioNodeList)||!(group instanceof NodeList)||group.length!==2||group.item(0)!==one||group.value!=="one")throw new Error("radio list");
if(!(owner.elements.choice instanceof RadioNodeList)||Array.from(group.values()).length!==2)throw new Error("named radio getter/iterator");
group.value="two";if(group.value!=="two"||one.checked||!two.checked)throw new Error("native radio value setter");
group.value="absent";if(group.value!=="two")throw new Error("unmatched radio setter");
two.remove();if(group.length!==1||group.value!==""||owner.elements.namedItem("choice")!==one)throw new Error("saved radio list stays live");
one.checked=true;if(group.value!=="one")throw new Error("pending checked mutation");
const getter=Object.getOwnPropertyDescriptor(RadioNodeList.prototype,"value").get;
let branded=false;try{getter.call({})}catch(error){branded=error instanceof TypeError}if(!branded)throw new Error("radio brand");
'], runtime, mut messages)
	assert messages == []string{}
	runtime.evaluate_host('const extraRadio=document.createElement("input");extraRadio.setAttribute("type","radio");extraRadio.name="choice";owner.appendChild(extraRadio)')!
	scratch := platform.begin_thread_scratch('compact form named list')
	runtime.evaluate_host('globalThis.retainedRadioGroup=owner.elements.namedItem("choice")')!
	scratch.finish()
	assert runtime.evaluate_host('retainedRadioGroup instanceof RadioNodeList&&retainedRadioGroup.length===2&&retainedRadioGroup.value==="one"')! == 'true'
}

fn test_compact_detached_form_collection_and_native_receiver_checks() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const form=document.createElement("form"),input=document.createElement("input");input.name="detached";form.appendChild(input);
const controls=form.elements;if(controls.length!==1||controls.namedItem("detached")!==input)throw new Error("detached controls "+JSON.stringify([controls.length,Array.from(controls,n=>[n.name,n===input]),controls.namedItem("detached")===input]));
if(input.form!==form)throw new Error("detached form owner");
host.appendChild(form);if(form.elements!==controls||controls.item(0)!==input)throw new Error("inserted form identity");
let branded=false;try{Object.getOwnPropertyDescriptor(HTMLFormElement.prototype,"elements").get.call(host)}catch(error){branded=error instanceof TypeError}if(!branded)throw new Error("form brand");
let converted=false;try{HTMLFormControlsCollection.prototype.namedItem.call({}, {toString(){converted=true;return "x"}})}catch(error){}if(converted)throw new Error("form collection brand before conversion");
'], runtime, mut messages)
	assert messages == []string{}
}
