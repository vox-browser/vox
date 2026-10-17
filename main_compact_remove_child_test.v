module main

import browserjs
import html

fn test_compact_remove_child_preserves_identity_and_can_reinsert_detached_children() {
	mut document :=
		html.parse_document('<!doctype html><div id="container"></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
const child=document.createElement("fieldset");child.id="probe";
container.appendChild(child);
child.remove=function(){throw new Error("author remove must not run");};
if(container.removeChild(child)!==child||child.parentNode!==null||container.hasChildNodes())throw new Error("removal identity/state");
if(document.getElementById("probe")!==null)throw new Error("removed id retained");
other.appendChild(child);
if(document.getElementById("probe")!==child||child.parentNode!==other)throw new Error("reinsertion identity");
if(document.getElementsByTagName("fieldset").length!==1)throw new Error("reinserted child missing");
globalThis.removalPassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('removalPassed')! == 'true'
	assert messages == []string{}
	assert document.get_element_by_id('probe')?.as_node().parent_element()?.get_attribute_value('id') == 'other'
}

fn test_compact_remove_child_validates_native_parent_and_receiver() {
	mut document :=
		html.parse_document('<!doctype html><div id="container"><b id="child">child</b></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
let missing=false,illegal=false,notNode=false;
try{other.removeChild(child);}catch(error){missing=error instanceof DOMException&&error.name==="NotFoundError";}
try{Element.prototype.removeChild.call({},child);}catch(error){illegal=error instanceof TypeError;}
try{container.removeChild({__state:child.__state});}catch(error){notNode=error instanceof TypeError;}
if(!missing||!illegal||!notNode||child.parentNode!==container)throw new Error("removeChild validation");
globalThis.validationPassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('validationPassed')! == 'true'
	assert messages == []string{}
}
