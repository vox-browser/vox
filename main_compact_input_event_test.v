module main

import browserjs
import dom
import gg
import html
import page
import time

fn test_native_typing_and_deletion_deliver_input_event_payloads_to_the_live_textarea() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><textarea id="field"></textarea>', dom.URL{value: 'https://input-events.test/'},
		none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://input-events.test/', [r'
globalThis.edits=[];globalThis.inputEventsValid=true;globalThis.captured=0;
document.addEventListener("input",event=>{captured++;inputEventsValid=inputEventsValid&&event.target===field&&event instanceof InputEvent},true);
field.addEventListener("input",event=>{inputEventsValid=inputEventsValid&&event instanceof InputEvent&&event instanceof UIEvent&&event.isTrusted&&event.target===field&&event.bubbles&&event.composed&&!event.cancelable&&!event.isComposing&&event.getTargetRanges().length===0;edits.push([event.inputType,event.data,field.value])});
'], runtime, mut messages)
	target := document.get_element_by_id('field') or { panic('field') }
	mut app := BrowserApp{document: document, page_model: owner, js_runtime: runtime,
		layout_tree_only: true, viewport_width: 320, viewport_height: 200}
	app.relayout(320, 284)
	dom.run_focusing_steps_for_node(target.as_node(), none, .click)
	app.handle_page_character(u32(`R`))
	app.handle_page_character(u32(`😀`))
	app.handle_key(.backspace, unsafe { gg.Modifier(0) })
	assert runtime.evaluate_host('inputEventsValid&&captured===3&&JSON.stringify(edits)===JSON.stringify([["insertText","R","R"],["insertText","😀","R😀"],["deleteContentBackward",null,"R"]])')! == 'true'
	assert messages == []string{}
}
