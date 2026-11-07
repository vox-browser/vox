module main

import browserjs
import dom
import html

fn test_compact_document_and_shadow_active_elements_retain_native_focus_identity() {
	mut document := html.parse_document('<!doctype html><input id="field"><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'about:blank',[r'
if(document.activeElement!==document.body)throw new Error("initial active element");
field.focus();if(document.activeElement!==field)throw new Error("focused native element");
const shadow=host.attachShadow({mode:"open"});shadow.innerHTML="<input id=inside>";globalThis.inside=shadow.getElementById("inside");
inside.focus();if(document.activeElement!==host||shadow.activeElement!==inside)throw new Error("retargeted shadow focus");
let brands=0;for(const invoke of [()=>Object.getOwnPropertyDescriptor(Document.prototype,"activeElement").get.call({}),()=>Object.getOwnPropertyDescriptor(ShadowRoot.prototype,"activeElement").get.call({})])try{invoke()}catch(error){if(error instanceof TypeError)brands++}if(brands!==2)throw new Error("active element brands");
'],runtime,mut messages)
	assert messages == []string{}
}

fn test_compact_active_element_reads_native_focus_changes_and_detached_document_owners() {
	mut document := html.parse_document('<!doctype html><textarea id="field"></textarea>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'about:blank',['globalThis.other=document.implementation.createHTMLDocument("other");if(other.activeElement!==other.body)throw new Error("detached owner")'],runtime,mut messages)
	assert messages == []string{}
	field := document.get_element_by_id('field') or { panic('missing field') }
	document.set_focused_area(field.as_node())
	assert runtime.evaluate_host('document.activeElement===field&&other.activeElement===other.body')! == 'true'
	document.set_focused_area(none)
	assert runtime.evaluate_host('document.activeElement===document.body')! == 'true'
}
