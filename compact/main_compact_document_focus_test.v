module main

import browserjs
import dom
import html

fn test_compact_has_focus_uses_its_native_document_and_checks_receivers() {
	mut document := html.parse_document('<!doctype html><p>focus</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(document.hasFocus()!==false)throw new Error("detached owner focus");
const detached=document.implementation.createHTMLDocument("Detached");
if(detached.hasFocus()!==false)throw new Error("detached factory focus");
let rejected=false;try{Document.prototype.hasFocus.call({})}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("hasFocus brand");
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('document.hasFocus()')! == document.has_focus_for_bindings().str()
}

fn test_compact_has_focus_follows_native_system_focus_and_active_document_identity() {
	mut document := html.parse_document('<!doctype html><p>focus</p>')
	mut other := html.parse_document('<!doctype html><p>other</p>')
	mut system_focused := true
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
		html_model_handle_: voidptr(&system_focused)
		is_focused_callback_: fn (owner voidptr) bool { return unsafe { *(&bool(owner)) } }
	}
	navigable.traversable_navigable_ = navigable
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		other.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'if(typeof document.hasFocus!=="function")throw new Error("focus binding");'], runtime, mut messages)
	assert messages == []string{}
	// Scripting initialization installs its own navigable. Install this native
	// focus fixture afterwards and restore that owner before realm teardown.
	previous := document.navigable()
	document.set_cached_navigable(navigable)
	defer { document.set_cached_navigable(previous) }
	assert runtime.evaluate_host('document.hasFocus()')! == 'true'
	system_focused = false
	assert runtime.evaluate_host('document.hasFocus()')! == 'false'
	system_focused = true
	navigable.active_document_ = other
	assert runtime.evaluate_host('document.hasFocus()')! == 'false'
	navigable.active_document_ = document
	assert runtime.evaluate_host('document.hasFocus()')! == 'true'
}
