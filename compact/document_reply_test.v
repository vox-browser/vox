module main

import browserjs
import dom
import html
import platform
import x.json2

fn test_compact_document_reply_preserves_fields_and_registers_foreign_identity() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut foreign := dom.Document.create(dom.url_about_blank())
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); foreign.finalize(); document.finalize() }
	mut binding := &CompactElementQueryBinding{document:document, runtime:&runtime}
	for owner in [document, foreign, document, foreign] {
		actual := binding.encode_document_state(owner)
		expected := json2.encode(binding.document_state(owner))
		assert actual == expected
		decoded := json2.decode[map[string]json2.Any](actual)!
		assert decoded.len == 4
		assert (decoded['nodeType'] or { panic('node type') }).int() == 9
	}
	assert binding.nodes.len == 1
	key := '__document_${foreign.as_node().unique_id()}'
	registered := binding.nodes[key] or { panic('foreign registration') }
	assert voidptr(registered) == voidptr(foreign.as_node())
	assert binding.document_query(document.as_node(), 'ownerDocument', '')! == 'null'
	assert binding.document_query(foreign.as_node(), 'ownerDocument', '')! == 'null'
}

fn test_compact_document_reply_queries_current_owner_after_native_adoption() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut foreign := dom.Document.create(dom.url_about_blank())
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); foreign.finalize(); document.finalize() }
	mut binding := &CompactElementQueryBinding{document:document, runtime:&runtime}
	mut element := document.create_element('div')!
	root_reply := binding.encode_document_state(document)
	assert binding.document_query(element.as_node(), 'ownerDocument', '')! == root_reply
	foreign.adopt_node(element.as_node())
	assert binding.document_query(element.as_node(), 'ownerDocument', '')! == binding.encode_document_state(foreign)
	document.adopt_node(element.as_node())
	assert binding.document_query(element.as_node(), 'ownerDocument', '')! == root_reply
	assert binding.encode_node_state(document.as_node()) == root_reply
	assert binding.encode_node_state(foreign.as_node()) == binding.encode_document_state(foreign)
}

fn test_compact_document_reply_keeps_javascript_identity_for_live_node_owners() {
	mut document := html.parse_document('<!doctype html><body><div id="host"></div></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const host=document.getElementById("host"),other=document.implementation.createHTMLDocument("other");
const nodes=[other.createElement("b"),other.createTextNode("text"),other.createComment("comment")];
if(document.ownerDocument!==null||other.ownerDocument!==null||document.documentElement.ownerDocument!==document)throw new Error("document identity");
for(const node of nodes){
 if(node.ownerDocument!==other||node.ownerDocument!==other)throw new Error("foreign owner");
 host.appendChild(node);
 if(node.ownerDocument!==document||node.ownerDocument!==document)throw new Error("adopted main owner");
 other.body.appendChild(node);
 if(node.ownerDocument!==other||node.ownerDocument!==other)throw new Error("adopted foreign owner");
}
const fragment=other.createDocumentFragment();
if(fragment.ownerDocument!==other)throw new Error("fragment owner");
globalThis.documentReplyIdentityPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('documentReplyIdentityPassed')! == 'true'
}

fn test_compact_document_reply_survives_temporary_host_reply_retirement() {
	mut document := html.parse_document('<!doctype html><body><div id="target"></div></body>')
	document.enable_native_storage()
	mut entered := document.enter_native_storage()
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	mut binding := &CompactElementQueryBinding{document:document, runtime:&runtime}
	element := document.get_element_by_id('target') or { panic('target') }
	key := binding.element_key(element)
	input := json2.encode({'key':json2.Any(key), 'action':json2.Any('ownerDocument'), 'selector':json2.Any('')})
	expected := json2.encode(binding.document_state(document))
	for _ in 0 .. 8 {
		reply := binding.query_with_temporary_reply(input)!
		control := reply.value.clone()
		reply.workspace.finish()
		work := platform.begin_thread_scratch('document host reply overwrite')
		_ = []u8{len:128*1024, init:u8(0xa5)}
		work.finish()
		assert reply.value == expected && control == expected
	}
	runtime.close()
	document.finalize()
	entered.finish()
	document.release_native_storage()
}
