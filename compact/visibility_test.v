module main

import browserjs
import html

fn test_compact_document_visibility_tracks_native_state_and_detached_owners() {
	mut document := html.parse_document('<!doctype html><p>visible</p>')
	document.set_initial_visibility_state(.visible)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(document.hidden!==false||document.visibilityState!=="visible")throw new Error("visible native document");
const detached=document.implementation.createHTMLDocument("Detached");
if(detached.hidden!==true||detached.visibilityState!=="hidden")throw new Error("detached native visibility");
globalThis.visibilityChanges=[];
document.addEventListener("visibilitychange",()=>visibilityChanges.push([document.hidden,document.visibilityState]));
for(const name of ["hidden","visibilityState"]){
 const descriptor=Object.getOwnPropertyDescriptor(Document.prototype,name);
 if(descriptor.set!==undefined||!descriptor.enumerable||!descriptor.configurable)throw new Error("readonly visibility descriptor");
 let branded=false;try{descriptor.get.call({})}catch(error){branded=error instanceof TypeError}if(!branded)throw new Error("visibility brand");
}
'], runtime, mut messages)
	assert messages == []string{}
	document.update_the_visibility_state(.hidden)
	assert runtime.evaluate_host('document.hidden===true&&document.visibilityState==="hidden"')! == 'true'
	document.update_the_visibility_state(.visible)
	assert runtime.evaluate_host('document.hidden===false&&document.visibilityState==="visible"')! == 'true'
	document.update_the_visibility_state(.visible)
	assert runtime.evaluate_host('JSON.stringify(visibilityChanges)')! == '[[true,"hidden"],[false,"visible"]]'
}
