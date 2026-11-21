module main

import browserjs
import dom
import html
import os

// Insertions send only the child's key; the facade sends a child's state
// only when the native side does not own the child. Natively owned children
// (created elements and text, parsed elements, fragments) insert without it,
// and every insertion leaves the native tree the facade describes.
fn test_insertions_send_child_state_only_when_asked() {
	url := dom.URL{value: 'https://child-state.test/'}
	mut document := html.parse_navigation_document('<!doctype html><body><div id="host"></div><ul id="list"><li id="one">1</li><li id="two">2</li></ul><template id="tpl"><b>t</b><i>u</i></template></body>',
		url, url.origin(), none) or { panic(err) }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	requests_before := compact_child_state_requests
	assert runtime.evaluate_host(r'
 const host=document.getElementById("host"),list=document.getElementById("list");
 const div=document.createElement("div");div.id="made";host.appendChild(div);
 host.appendChild(document.createTextNode("text"));
 list.insertBefore(document.getElementById("two"),document.getElementById("one"));
 const fragment=document.createDocumentFragment();fragment.appendChild(document.createElement("em"));fragment.appendChild(document.createTextNode("f"));host.appendChild(fragment);
 host.appendChild(document.getElementById("tpl").content.cloneNode(true));
 host.insertBefore(document.createElement("span"),div);
 host.firstChild.id==="" && host.children.length===5 && list.firstElementChild.id==="two";
 ')! == 'true'
	assert messages == []string{}, messages.str()
	if os.getenv('VOX_RETAIN_COMPACT_CHILD_STATES') == '' {
		assert compact_child_state_requests == requests_before
	}
	host := document.get_element_by_id('host') or { panic('host') }
	assert host.inner_html() or { '' } == '<span></span><div id="made"></div>text<em></em>f<b>t</b><i>u</i>'
	list := document.get_element_by_id('list') or { panic('list') }
	assert list.inner_html() or { '' } == '<li id="two">2</li><li id="one">1</li>'
}

// A child the native side does not own is refused with "Unknown child node"
// before any mutation, and the same request with the child's state creates
// and inserts it, which is the facade's retry.
fn test_unknown_children_are_created_from_the_state_of_the_retry() {
	mut document := html.parse_document('<!doctype html><body><div id="host"></div></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut binding := &CompactElementQueryBinding{document: document, runtime: &runtime}
	host := document.get_element_by_id('host') or { panic('host') }
	requests := compact_child_state_requests
	binding.node_tree_query(host.as_node(), 'appendNode', '{"child":"__facade_only","reference":""}') or {
		assert err.msg() == 'TypeError: Unknown child node'
	}
	assert compact_child_state_requests == requests + 1
	assert host.inner_html() or { '' } == ''
	binding.node_tree_query(host.as_node(), 'appendNode', '{"child":"__facade_only","reference":"","state":{"tagName":"#text","textContent":"made from state"}}')!
	assert host.inner_html() or { '' } == 'made from state'
	assert compact_child_state_requests == requests + 1
}
