module main

import browserjs
import html
import dom
import x.json2

fn test_pending_finalization_and_clearing_do_not_enumerate_clean_facades() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
let enumerations=0;
const states={a:{bridgeKey:"a"},b:{bridgeKey:"b"},c:{bridgeKey:"c"}};
const __state={elements:new Proxy(states,{ownKeys(target){enumerations++;return Reflect.ownKeys(target);}}),operations:[],logs:[]};
const __canvases={};
' + compact_pending_elements_bootstrap() + r'
enumerations=0;
states.b.textContentDirty=true;
if(Object.keys(__pendingElementStates(true)).join()!=="b")throw new Error("missing dirty element");
__compactTakePendingDOMState(false,false,true);
if(__dirtyElementStates.size||Object.keys(__pendingElementStates(true)).length)throw new Error("edits were not drained");
states.c.attributesDirty=true;states.c.attributesDirty=false;
if(Object.keys(__pendingElementStates(false)).length||__dirtyElementStates.size)throw new Error("cancelled edit retained");
__state.elements.d={bridgeKey:"d",checkedDirty:true};
if(Object.keys(__pendingElementStates(true)).join()!=="d")throw new Error("new state untracked");
__compactTakePendingDOMState(false,false,true);
__canvases.paint={state:states.a};states.a.canvasNative=true;
if(Object.keys(__pendingElementStates(true)).join()!=="a")throw new Error("canvas lost");
if(Object.keys(__pendingElementStates(false)).length)throw new Error("canvas leaked into query replay");
if(enumerations)throw new Error("clean facades enumerated");
true;
')! == 'true'
}

fn test_pending_finalization_covers_removed_and_created_content_and_control_edits_once() {
	$if !darwin && !linux {
		return
	}
	mut document := html.parse_document('<!doctype html><p id="text">before</p><input id="control" type="checkbox"><div id="parent"></div>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [''], runtime, mut messages)
	runtime.evaluate_host('const parent=document.getElementById("parent");text.textContent="after";control.checked=true;control.indeterminate=true;globalThis.added=document.createElement("p");added.id="added";added.innerHTML="<b>created</b>";parent.appendChild(added);text.remove();')!
	encoded := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, encoded, runtime, mut messages)
	assert document.get_element_by_id('text') == none
	assert document.get_element_by_id('added')?.inner_html()! == '<b>created</b>'
	control := document.get_element_by_id('control')?
	assert unsafe { &dom.HTMLInputElement(control) }.checked()
	assert unsafe { &dom.HTMLInputElement(control) }.indeterminate()
	second := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdFinalize()')!)!
	assert (second['elements'] or { panic('missing pending map') }).as_map().len == 0
	runtime.evaluate_host('added.textContent="preserved";__ladybirdClearLogs()')!
	third := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdFinalize()')!)!
	assert (third['elements'] or { panic('missing pending map') }).as_map().len == 1
}
