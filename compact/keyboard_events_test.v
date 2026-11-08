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

fn test_native_keyup_uses_current_focus_and_drops_inactive_or_repeat_events() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><textarea id="first"></textarea><textarea id="second"></textarea>',dom.URL{value:'https://keyboard.example.test/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://keyboard.example.test/',[r'
globalThis.releases=[];
first.addEventListener("keydown",event=>{event.preventDefault();second.focus()});
second.addEventListener("keyup",event=>{releases.push(event.isTrusted&&event instanceof KeyboardEvent&&event.target===second&&event.key==="a"&&event.shiftKey);event.preventDefault()});
'],runtime,mut messages)
	mut app := BrowserApp{document:document,page_model:owner,js_runtime:runtime,layout_tree_only:true,viewport_width:320,viewport_height:200}
	app.relayout(320,284)
	assert runtime.evaluate_host('first.focus();"ready"')! == 'ready'
	assert owner.handle_keydown(int(`A`),dom.modifier_shift,u32(`a`),false) == .cancelled
	assert owner.handle_keyup(int(`A`),dom.modifier_shift,u32(`a`),false) == .cancelled
	assert owner.handle_keyup(int(`A`),dom.modifier_shift,u32(`a`),true) == .dropped
	owner.event_handler.set_document_state(false,false)
	assert owner.handle_keyup(int(`A`),dom.modifier_shift,u32(`a`),false) == .dropped
	assert runtime.evaluate_host('releases.length===1&&releases[0]')! == 'true'
	assert messages == []string{}
}

fn test_native_character_callback_honors_beforeinput_cancellation() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><textarea id="field"></textarea>',dom.URL{value:'https://keyboard.example.test/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://keyboard.example.test/',[r'
globalThis.edits=[];
field.addEventListener("beforeinput",event=>{edits.push([event.isTrusted,event.cancelable,event.inputType,event.data,field.value,event.getTargetRanges().length]);if(event.data==="x")event.preventDefault()});
'],runtime,mut messages)
	mut app := BrowserApp{document:document,page_model:owner,js_runtime:runtime,layout_tree_only:true,viewport_width:320,viewport_height:200}
	app.relayout(320,284)
	assert runtime.evaluate_host('field.focus();"ready"')! == 'ready'
	app.handle_character(u32(`x`))
	app.handle_character(u32(`y`))
	assert runtime.evaluate_host('JSON.stringify(edits)')! == '[[true,true,"insertText","x","",0],[true,true,"insertText","y","",0]]'
	assert runtime.evaluate_host('field.value')! == 'y'
	assert messages == []string{}
}
