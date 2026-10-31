module main

import browserjs
import dom
import html

fn test_compact_input_and_change_listeners_receive_native_events_and_composed_paths_once() {
	mut document := html.parse_document('<!doctype html><div id="parent"><textarea id="field"></textarea></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'about:blank',[r'
globalThis.events=[];globalThis.checks=[];let saved;
function input(event){events.push("field");saved=event;checks.push(event instanceof Event&&event.isTrusted&&this===field&&event.target===field&&event.currentTarget===field&&event.composedPath()[0]===field&&event.composedPath().includes(parent)&&event.composedPath().includes(document));}
field.addEventListener("input",input,{once:true});parent.addEventListener("input",event=>{events.push("parent");checks.push(event===saved&&event.currentTarget===parent)});
function removed(){events.push("removed")}field.addEventListener("change",removed);field.removeEventListener("change",removed);
field.addEventListener("change",event=>{events.push("change");checks.push(event instanceof Event&&event.target===field)},{once:true});
'],runtime,mut messages)
	assert messages == []string{}
	field := document.get_element_by_id('field') or { panic('missing field') }
	mut input := dom.Event.create('input',dom.EventInit{bubbles:true,composed:true})
	input.set_is_trusted(true)
	dom.event_target_dispatch_event(unsafe { &dom.EventTarget(field) },input)
	mut change := dom.Event.create('change',dom.EventInit{bubbles:true})
	change.set_is_trusted(true)
	dom.event_target_dispatch_event(unsafe { &dom.EventTarget(field) },change)
	assert runtime.evaluate_host('events.join(",")==="field,parent,change"&&checks.every(Boolean)')! == 'true'
}

fn test_first_textarea_input_listener_reads_the_edit_and_cannot_reset_it_through_default_value() {
	mut document := html.parse_document('<!doctype html><textarea id="field"></textarea>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'about:blank',[r'
globalThis.seen=[];field.addEventListener("input",()=>{seen.push(field.value);field.defaultValue="new default";seen.push(field.value)});
'],runtime,mut messages)
	field := document.get_element_by_id('field') or { panic('field') }
	mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(field) })
	model.create_shadow_tree_if_needed()
	model.text.handle_insert(dom.input_type_insert_text,'V')!
	assert model.value() == 'V'
	assert model.dirty_value
	assert runtime.evaluate_host('seen.join("|")')! == 'V|V'
	assert messages == []string{}
}
