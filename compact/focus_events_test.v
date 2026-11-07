module main

import browserjs
import dom
import page
import time

// Script focus() moved focus without the focusing steps, so focus and blur
// listeners and onfocus attributes never ran; blur() did not exist.
fn test_script_focus_runs_the_focusing_steps_and_fires_focus_events() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><input id="first" onfocus="events.push(\'inline:first\')"><input id="second">',
		dom.URL{ value: 'https://focus.example.test/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://focus.example.test/', [r'
globalThis.events=[];
for(const field of [first,second]){
 field.addEventListener("focus",event=>events.push("focus:"+field.id+":"+event.isTrusted));
 field.addEventListener("blur",event=>events.push("blur:"+field.id));
}
'], runtime, mut messages)
	assert messages == []string{}
	mut app := &BrowserApp{ document: document, page_model: owner, js_runtime: runtime }
	app.relayout(320, 312)
	// focus() runs synchronously, so the events precede the next statement.
	result := runtime.evaluate_host('first.focus();const afterFirst=events.join();second.focus();second.blur();afterFirst+"|"+events.join()+"|"+(document.activeElement===document.body)')!
	assert result == 'inline:first,focus:first:true|inline:first,focus:first:true,blur:first,focus:second:true,blur:second|true', result
}
