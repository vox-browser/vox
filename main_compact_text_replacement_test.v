module main

import browserjs
import dom
import html
import x.json2

fn test_compact_empty_text_content_removes_controls_before_client_render() {
	mut document := html.parse_document('<!doctype html><div id="host"><input id="server"><svg><path d="M0 0"/></svg></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const previous=server;
host.textContent="";
const replacement=document.createElement("input");replacement.id="client";
host.appendChild(replacement);
if(host.querySelectorAll("input").length!==1||host.firstChild!==replacement||host.childNodes.length!==1)throw new Error("client render retained server children");
if(previous.isConnected||previous.parentNode!==null)throw new Error("server control still connected");
console.log("replacement passed");
'], runtime, mut messages)
	assert messages == ['replacement passed']
	assert document.get_element_by_id('server') == none
	assert document.get_element_by_id('host')?.as_node().child_count() == 1
}

fn test_compact_equal_text_content_replaces_nested_elements_and_text_identity() {
	mut document := html.parse_document('<!doctype html><div id="host"><span id="nested">same</span></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const previous=nested;
host.textContent="same";
const first=host.firstChild;
if(first.nodeType!==3||first.nodeValue!=="same"||previous.isConnected)throw new Error("equal text retained nested element");
host.textContent="same";
const second=host.firstChild;
if(second===first||first.parentNode!==null||second.nodeValue!=="same")throw new Error("equal text retained Text identity");
console.log("equal text passed");
'], runtime, mut messages)
	assert messages == ['equal text passed']
	assert document.get_element_by_id('nested') == none
	assert document.get_element_by_id('host')?.as_node().first_child()?.is_text()
}

fn test_compact_legacy_body_text_replay_clears_children_with_empty_text() {
	mut document := html.parse_document('<!doctype html><input id="server"><br>')
	defer { document.finalize() }
	mut state := javascript_initial_state(document, 'about:blank', [])
	state['bodyTextDirty'] = json2.Any(true)
	state['bodyText'] = json2.Any('')
	state['elements'] = json2.Any(map[string]json2.Any{})
	mut messages := []string{}
	apply_javascript_state(document, json2.encode(state), map[string]&dom.Element{}, mut messages)
	assert messages == []string{}
	assert !document.body()?.as_node().has_children()
}
