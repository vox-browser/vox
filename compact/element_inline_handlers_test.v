module main

import browserjs
import html

fn inline_handlers_document(markup string, script string) (&BrowserApp, &browserjs.Runtime, []string) {
	mut document := html.parse_document(markup)
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [script], runtime, mut messages)
	return &BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true }, runtime, messages
}

// Script-dispatched events skipped content attributes and on* properties:
// only the shell's own click/input/change replay ran them.
fn test_script_dispatched_events_run_inline_handlers_once() {
	mut app, mut runtime, messages := inline_handlers_document('<!doctype html><div id="d" onclick="runs.push(\'attr:\'+event.type+(this===d));return false" onmouseover="runs.push(\'over\')" onkeydown="runs.push(\'key\')" oncustom="runs.push(\'custom\')"><input id="field" onchange="runs.push(\'change\')" oninput="runs.push(\'input\')"></div>',
		r'globalThis.runs=[];')
	defer {
		runtime.close()
		app.document.finalize()
	}
	assert messages == []string{}
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n+" "+runs.join())};
 check(d.dispatchEvent(new MouseEvent("click",{bubbles:true,cancelable:true}))===false,"return false cancels");
 check(runs.join()==="attr:clicktrue","click attribute once");runs.length=0;
 d.dispatchEvent(new MouseEvent("mouseover",{bubbles:true}));d.dispatchEvent(new KeyboardEvent("keydown",{bubbles:true}));
 field.dispatchEvent(new Event("change",{bubbles:true}));field.dispatchEvent(new Event("input",{bubbles:true}));
 check(runs.join()==="over,key,change,input","native dispatch runs attributes");runs.length=0;
 // oncustom is not an event handler attribute.
 d.dispatchEvent(new Event("custom"));check(runs.length===0,"unknown attribute");
 const compiled=d.onclick;
 check(typeof compiled==="function"&&compiled.name==="onclick"&&!Object.hasOwn(d,"onclick")&&"onclick" in d,"compiled getter");
 d.onclick=function(event){runs.push("property:"+(this===d));};
 d.dispatchEvent(new MouseEvent("click",{bubbles:true}));check(runs.join()==="property:true","property replaces attribute");runs.length=0;
 d.onclick="not callable";check(d.onclick===null,"non-callable is null");
 d.dispatchEvent(new MouseEvent("click",{bubbles:true}));check(runs.length===0,"removed handler");
 d.onclick=()=>runs.push("again");d.click();check(runs.join()==="again","click() runs the handler once");runs.length=0;
 return true;
})()')! == 'true'
	// The shell replays a native click after the page dispatched it; native
	// dispatch now runs the handler, so the compact replay must not repeat it.
	// The shell applies queued compact mutations between tasks; a query does so here.
	runtime.evaluate_host('runs.length=0;d.onclick=null;d.setAttribute("onclick","runs.push(\'replayed\')");d.matches("div");0')!
	runtime.evaluate_host('__ladybirdDispatch("click","d")')!
	assert runtime.evaluate_host('runs.join()')! == 'replayed'
}

fn test_inline_handlers_keep_form_scope_and_compact_owned_elements_keep_expandos() {
	mut app, mut runtime, messages := inline_handlers_document('<!doctype html><form id="f"><button id="b" type="button" onclick="runs.push(scopeMarker)">b</button></form><img id="picture" alt="">',
		r'globalThis.runs=[];f.scopeMarker="form";globalThis.scopeMarker="global";')
	defer {
		runtime.close()
		app.document.finalize()
	}
	assert messages == []string{}
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n+" "+runs.join())};
 b.dispatchEvent(new MouseEvent("click",{bubbles:true}));check(runs.join()==="form","form owner scope");
 const handler=function(){};picture.onclick=handler;
 check(Object.hasOwn(picture,"onclick")&&picture.onclick===handler,"compact-owned element keeps its expando");
 let illegal=false;try{Object.getOwnPropertyDescriptor(HTMLElement.prototype,"onclick").get.call({})}catch(error){illegal=error instanceof TypeError}
 check(illegal,"receiver check");return true;
})()')! == 'true'
}
