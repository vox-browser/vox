module main

import browserjs
import dom
import gg
import html
import page
import time

fn test_native_enter_reaches_compact_keyboard_listeners_before_the_editing_default_action() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><textarea id="field"></textarea>',dom.URL{value:'https://keyboard.example.test/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://keyboard.example.test/',[r'
globalThis.keys=[];document.addEventListener("keydown",event=>keys.push("document:"+event.key),true);
field.addEventListener("keydown",event=>{keys.push(event instanceof KeyboardEvent&&event.isTrusted&&event.key==="Enter"&&event.code==="Enter"&&event.composedPath()[0]===field?"native":"wrong");event.preventDefault()},{once:true});
'],runtime,mut messages)
	target := document.get_element_by_id('field') or { panic('field') }
	mut app := BrowserApp{document:document,page_model:owner,js_runtime:runtime,layout_tree_only:true,viewport_width:320,viewport_height:200}
	app.relayout(320,284)
	dom.run_focusing_steps_for_node(target.as_node(),none,.click)
	app.handle_key(.enter,unsafe { gg.Modifier(0) })
	actual := runtime.evaluate_host('keys.join("|")')!
	assert actual == 'document:Enter|native'
	model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(target) })
	assert model.value() == ''
	app.handle_key(.enter,unsafe { gg.Modifier(0) })
	assert model.value() == '\n'
	assert messages == []string{}
}
