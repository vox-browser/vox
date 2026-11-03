module main

import browserjs
import dom
import html

fn test_compact_select_interface_preserves_native_selection_and_startup_type_checks() {
	mut document := html.parse_document('<!doctype html><select id="control"><option value="first">First</option><option value="second">Second</option></select><input id="input"><textarea id="editor"></textarea><div id="plain"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 const select=document.getElementById("control");
 if(!(select instanceof HTMLSelectElement)||!(select instanceof HTMLElement)||!(select instanceof Element)||!(select instanceof Node))throw Error("select interface hierarchy");
 if(Object.getPrototypeOf(HTMLSelectElement)!==HTMLElement||Object.getPrototypeOf(HTMLSelectElement.prototype)!==HTMLElement.prototype||Object.getPrototypeOf(select)!==HTMLSelectElement.prototype)throw Error("select prototype chain");
 const global=Object.getOwnPropertyDescriptor(globalThis,"HTMLSelectElement"),prototype=Object.getOwnPropertyDescriptor(HTMLSelectElement,"prototype"),tag=Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,Symbol.toStringTag);
 if(!global.writable||!global.configurable||global.enumerable||prototype.writable||!tag.configurable||tag.writable||tag.enumerable)throw Error("interface descriptors");
 if(HTMLSelectElement.length!==0||HTMLSelectElement.name!=="HTMLSelectElement"||HTMLSelectElement.prototype.constructor!==HTMLSelectElement||Object.prototype.toString.call(select)!=="[object HTMLSelectElement]")throw Error("select interface metadata");
 // GitHub startup path branches over all three form-control interfaces.
 for(const id of ["input","editor","plain"]){const node=document.getElementById(id);if(node instanceof HTMLSelectElement)throw Error("unrelated element classified as select");}
 if(!(input instanceof HTMLInputElement)||!(editor instanceof HTMLTextAreaElement))throw Error("neighboring interface changed");
 if(select.value!=="first"||select.selectedIndex!==0||select.options.length!==2||select.options!==select.options)throw Error("initial native selection");
 select.selectedIndex=1;
 if(select.value!=="second"||select.options[1].value!=="second")throw Error("native selectedIndex write");
 select.value="first";
 if(select.selectedIndex!==0||select.value!=="first")throw Error("native value write");
 globalThis.selectIdentity=select;
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
	control := document.get_element_by_id('control')?
	native_select := unsafe { &dom.HTMLSelectElement(control) }
	assert html.html_select_element_selected_index(native_select) == 0
	html.set_html_select_element_selected_index(native_select, 1)
	assert runtime.evaluate_host('document.getElementById("control")===selectIdentity&&selectIdentity instanceof HTMLSelectElement&&selectIdentity.value==="second"&&selectIdentity.selectedIndex===1')! == 'true'
}

fn test_compact_select_interface_classifies_created_cloned_and_namespaced_elements() {
	mut document := html.parse_document('<!doctype html><select id="source"><option>A</option></select>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 const html="http://www.w3.org/1999/xhtml",svg="http://www.w3.org/2000/svg";
 for(const element of [document.createElement("select"),document.createElement("SELECT"),document.createElementNS(html,"select"),document.createElementNS(html,"p:select"),source.cloneNode(false),source.cloneNode(true)]){
  if(!(element instanceof HTMLSelectElement)||Object.getPrototypeOf(element)!==HTMLSelectElement.prototype||Object.prototype.toString.call(element)!=="[object HTMLSelectElement]")throw Error("created or cloned select interface");
 }
 for(const element of [document.createElementNS(svg,"select"),document.createElementNS("urn:foreign","select"),document.createElementNS(null,"select"),document.createElementNS(html,"SELECT"),document.createElement("div")]){
  if(element instanceof HTMLSelectElement||Object.getPrototypeOf(element)===HTMLSelectElement.prototype)throw Error("select namespace or local-name mismatch");
 }
 let illegal=0;for(const construct of [()=>HTMLSelectElement(),()=>new HTMLSelectElement()])try{construct()}catch(error){if(error instanceof TypeError)illegal++}
 if(illegal!==2)throw Error("unsupported direct HTML construction must stay explicit");
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
}
