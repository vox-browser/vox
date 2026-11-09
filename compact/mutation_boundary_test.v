module main

import browserjs
import dom
import html
import platform

fn test_compact_pending_handoff_owns_one_batch_and_keeps_task_output_separate() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
let enumerations=0;
const clean={a:{bridgeKey:"a"},b:{bridgeKey:"b"}};
const __state={elements:new Proxy(clean,{ownKeys(target){enumerations++;return Reflect.ownKeys(target);}}),operations:[],logs:[],videoSources:{large:"decoded pixels"}};
const __canvases={};
const __elementApply=Reflect.apply;
function __elementContent(state,name){return state[name];}
' + compact_pending_elements_bootstrap() + r'
enumerations=0;
clean.a.textContent="first";clean.a.textContentDirty=true;
__state.operations.push({op:"focus",target:"a"});
__state.bodyHTMLDirty=true;__state.logs.push("outer");
const query=JSON.parse(__compactTakePendingDOMState(false,false,false));
if(Object.keys(query.elements).join()!=="a"||query.operations.length!==1||!query.bodyHTMLDirty)throw Error("query batch");
if(query.logs.length||"videoSources" in query||__state.logs.join()!=="outer")throw Error("query consumed task output");
if(__compactHasPendingDOMState()||__compactTakePendingDOMState(false,false,false)!==null)throw Error("batch replayed twice");
const task=JSON.parse(__compactTakePendingDOMState(true,true,true));
if(task.logs.join()!=="outer"||__state.logs.length)throw Error("task output handoff");
// Simulate a callback entered while native code consumes the captured batch.
clean.b.checked=true;clean.b.checkedDirty=true;__state.logs.push("reentrant");
const next=JSON.parse(__compactTakePendingDOMState(false,true,true));
if(Object.keys(next.elements).join()!=="b"||!next.elements.b.checked||next.logs.join()!=="reentrant")throw Error("reentrant batch lost");
if(task.logs.join()!=="outer"||__compactHasPendingDOMState())throw Error("batch identity");
const cycle={};cycle.self=cycle;__state.operations.push(cycle);
let failed=false;try{__compactTakePendingDOMState(false,false,false);}catch(error){failed=error instanceof TypeError;}
if(!failed||__state.operations.length!==1)throw Error("serialization failure consumed edits");
__state.operations=[];
__canvases.paint={state:clean.a,kind:"2d",context:{}};
if(__compactTakePendingDOMState(false,false,false)!==null)throw Error("canvas leaked into native query");
const canvas=JSON.parse(__compactTakePendingDOMState(true,false,true));
if(!canvas.elements.a.canvasNative)throw Error("native canvas handoff");
if(__compactHasPendingDOMState()||enumerations)throw Error("clean facade traversal");
const output=JSON.parse(__compactTakeTaskOutput());
if(output.logs.length||output.navigate)throw Error("unexpected task output");
__state.navigate="#once";__state.logs.push("navigation output");
const navigation=JSON.parse(__compactTakeTaskOutput());
if(navigation.navigate!=="#once"||navigation.logs.join()!=="navigation output")throw Error("navigation handoff");
const consumed=JSON.parse(__compactTakeTaskOutput());
if(consumed.navigate||consumed.logs.length)throw Error("task output replayed twice");
__state.navigate="#retained";__state.logs.push(cycle);
let outputFailed=false;try{__compactTakeTaskOutput();}catch(error){outputFailed=error instanceof TypeError;}
if(!outputFailed||__state.navigate!=="#retained"||__state.logs.length!==1)throw Error("serialization failure consumed task output");
__state.logs=[];
if(JSON.parse(__compactTakeTaskOutput()).navigate!=="#retained")throw Error("navigation lost after serialization failure");
true;
')! == 'true'
}

fn test_compact_native_host_boundary_replays_controls_without_consuming_console_output() {
	mut document := html.parse_document('<!doctype html><input id="control" type="checkbox">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://dom-boundary.test/', [
		'globalThis.boundaryControl=document.getElementById("control");',
	], runtime, mut messages)
	assert messages == []string{}
	runtime.evaluate_host('boundaryControl.checked=true;boundaryControl.indeterminate=true;location.href="#native-boundary";console.log("native boundary");')!
	flush_compact_dom_mutations(document, runtime)!
	control := unsafe { &dom.HTMLInputElement(document.get_element_by_id('control')?) }
	assert control.checked()
	assert control.indeterminate()
	commit := commit_compact_dom_task(document, runtime, mut messages)!
	assert commit.navigation? == '#native-boundary'
	next := commit_compact_dom_task(document, runtime, mut messages)!
	assert next.navigation == none
	assert messages == ['native boundary']
	// Clearing output is not an instruction to discard semantic mutations.
	runtime.evaluate_host('boundaryControl.checked=false;__ladybirdClearLogs();')!
	commit_compact_dom_task(document, runtime, mut messages)!
	assert !control.checked()
}

fn test_compact_task_completion_settles_reentrant_reaction_writes_before_paint() {
	url := dom.URL{ value: 'https://dom-boundary.test/reactions' }
	mut document := html.parse_navigation_document('<!doctype html><x-boundary id="actor"></x-boundary><input id="control" type="checkbox"><p id="result">before</p>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [r'
globalThis.boundaryControl=document.getElementById("control");
globalThis.boundaryResult=document.getElementById("result");
class Boundary extends HTMLElement{
 static get observedAttributes(){return ["data-phase"];}
 attributeChangedCallback(){boundaryControl.checked=true;boundaryControl.indeterminate=true;boundaryResult.textContent="reaction";location.href="/inner";console.log("reaction output");}
}
customElements.define("x-boundary",Boundary);
'], runtime, mut messages)
	assert messages == []string{}
	mut actor := document.get_element_by_id('actor')?
	actor.set_attribute_value('data-phase', 'commit')
	assert document.has_pending_custom_element_reactions()
	runtime.evaluate_host('location.href="/outer";console.log("task output");')!
	commit := commit_compact_dom_task(document, runtime, mut messages)!
	assert commit.navigation? == '/inner'
	control := unsafe { &dom.HTMLInputElement(document.get_element_by_id('control')?) }
	assert control.checked()
	assert control.indeterminate()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'reaction'
	assert !document.has_pending_custom_element_reactions()
	assert messages == ['task output', 'reaction output']
	for _ in 0 .. 2 {
		next := commit_compact_dom_task(document, runtime, mut messages)!
		assert next.navigation == none
	}
	assert messages == ['task output', 'reaction output']
	assert runtime.evaluate_host('__ladybirdTakePendingDOMMutations()')! == 'null'
}

fn test_compact_media_click_preflush_keeps_navigation_for_the_task_owner() {
	mut document := html.parse_document('<!doctype html><video id="media"></video><p id="result">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://dom-boundary.test/media', []string{}, runtime, mut messages)
	assert messages == []string{}
	mut app := BrowserApp{ document: document, js_runtime: runtime }
	runtime.evaluate_host('document.getElementById("result").textContent="click";location.href="#after-click";console.log("click output");')!
	media := document.get_element_by_id('media')?
	_ = app.media_click_replay_state(media)!
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'click'
	assert app.js_messages == []string{}
	commit := commit_compact_dom_task(document, runtime, mut app.js_messages)!
	assert commit.navigation? == '#after-click'
	assert app.js_messages == ['click output']
	next := commit_compact_dom_task(document, runtime, mut app.js_messages)!
	assert next.navigation == none
	assert app.js_messages == ['click output']
}

fn test_compact_native_query_settles_reaction_writes_before_its_read() {
	url := dom.URL{ value: 'https://dom-boundary.test/query' }
	mut document := html.parse_navigation_document('<!doctype html><x-boundary id="actor"></x-boundary><input id="control" type="checkbox">', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [r'
globalThis.boundaryControl=document.getElementById("control");
class Boundary extends HTMLElement{static get observedAttributes(){return ["data-phase"];}attributeChangedCallback(){boundaryControl.checked=true;}}
customElements.define("x-boundary",Boundary);
'], runtime, mut messages)
	assert messages == []string{}
	mut actor := document.get_element_by_id('actor')?
	actor.set_attribute_value('data-phase', 'read')
	assert runtime.evaluate_host('document.querySelector(":checked")===boundaryControl')! == 'true'
	assert runtime.evaluate_host('__ladybirdTakePendingDOMMutations()')! == 'null'
}

fn test_compact_task_output_survives_the_callers_scratch_scope() {
	url := dom.URL{ value: 'https://dom-boundary.test/storage' }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><body><p id="target">before</p>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}
	runtime.evaluate_host('location.href="/retained";console.log("retained output");document.getElementById("target").textContent="retained text";')!
	mut scratch := platform.begin_thread_scratch('task completion caller')
	commit := commit_compact_dom_task(document, runtime, mut messages)!
	scratch.leave()
	scratch.finish()
	mut churn := platform.begin_thread_scratch('overwrite task completion caller')
	_ = 'overwritten'.repeat(65536)
	churn.leave()
	churn.finish()
	assert commit.navigation? == '/retained'
	assert messages == ['retained output']
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'retained text'
}
