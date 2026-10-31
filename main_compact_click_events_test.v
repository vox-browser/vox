module main

import browserjs
import dom
import html
import page
import time

fn test_compact_click_listeners_use_native_paths_capture_cancellation_and_once() {
	mut document := html.parse_document('<!doctype html><div id="parent"><button id="field">click</button></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.order=[];globalThis.valid=true;
document.addEventListener("click",event=>{order.push("document");valid=valid&&event instanceof MouseEvent&&event.composedPath()[0]===field&&event.eventPhase===1},{capture:true});
parent.addEventListener("click",()=>order.push("parent"),true);
field.addEventListener("click",event=>{order.push("field");event.preventDefault()},{once:true});
function removed(){throw new Error("removed click")}document.addEventListener("click",removed);document.removeEventListener("click",removed);
'], runtime, mut messages)
	encoded := runtime.evaluate_host('__ladybirdDispatch("click","field")')!
	assert javascript_default_prevented(encoded)
	assert runtime.evaluate_host('valid&&order.join(",")==="document,parent,field"')! == 'true'
	second := runtime.evaluate_host('order=[];__ladybirdDispatch("click","field")')!
	assert !javascript_default_prevented(second)
	assert runtime.evaluate_host('valid&&order.join(",")==="document,parent"')! == 'true'
	assert messages == []string{}
}

fn test_compact_replay_does_not_dispatch_a_native_page_click_twice() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><button id="field">click</button>', dom.URL{ value: 'https://click.example.test/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://click.example.test/', [r'
globalThis.count=0;globalThis.trusted=false;field.addEventListener("click",event=>{count++;trusted=event.isTrusted;event.preventDefault()});
'], runtime, mut messages)
	target := document.get_element_by_id('field') or { panic('field') }
	input := page.InputTarget.from_node(target.as_node())
	owner.event_handler.set_document_state(true, true)
	owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1)
	owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0)
	mut app := BrowserApp{ document: document, page_model: owner, js_runtime: runtime, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	assert !app.dispatch_javascript_event('click', target)
	assert runtime.evaluate_host('count+"|"+trusted')! == '1|true'
	assert messages == []string{}
}
