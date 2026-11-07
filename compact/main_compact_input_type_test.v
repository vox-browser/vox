module main

import browserjs
import dom
import html

fn compact_input_type_password_text(node &dom.Node) bool {
	if node.is_text() && unsafe { &dom.Text(node) }.is_password_input() { return true }
	mut child := node.first_child()
	for {
		current := child or { break }
		if compact_input_type_password_text(current) { return true }
		child = current.next_sibling()
	}
	return false
}

// input.type and button.type reflect the content attribute. React sets
// `type` through the IDL attribute, so a facade-local property left
// Discord's password field as a native text input showing the password.
fn test_input_and_button_type_reflect_the_native_attribute() {
	mut document := html.parse_document('<!doctype html><input id="parsed" type="PASSWORD"><input id="plain"><input id="bogus" type="nonsense"><button id="action"></button><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://input-type.test/', [r'
globalThis.read=[parsed.type,plain.type,bogus.type,action.type].join();
const created=document.createElement("input");created.id="created";host.appendChild(created);created.type="password";
plain.type="Email";action.type="reset";
globalThis.afterWrite=[plain.type,plain.getAttribute("type"),action.type,created.type].join();
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('read')! == 'password,text,text,submit'
	assert runtime.evaluate_host('afterWrite')! == 'email,Email,reset,password'
	plain := document.get_element_by_id('plain') or { panic('plain') }
	assert plain.get_attribute_value('type') == 'Email'
	action := document.get_element_by_id('action') or { panic('action') }
	assert action.get_attribute_value('type') == 'reset'
	created := document.get_element_by_id('created') or { panic('created') }
	assert created.get_attribute_value('type') == 'password'
	shadow := created.shadow_root() or { panic('created input has no shadow tree') }
	assert compact_input_type_password_text(unsafe { &dom.Node(shadow) })
}
