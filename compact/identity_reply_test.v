module main

import browserjs
import dom
import html
import x.json2

fn test_compact_identity_reply_keeps_first_hydration_and_escaped_keys() {
	mut document := html.parse_document('<!doctype html><input id="field" value="initial"><svg><rect id="shape"/></svg>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	mut binding := &CompactElementQueryBinding{ document: document, runtime: unsafe { nil } }
	for id in ['field', 'shape'] {
		element := document.get_element_by_id(id) or { panic(id) }
		key := '__element_"\\λ😀_' + id
		binding.keys[voidptr(element)] = key
		binding.elements[key] = element
		first := json2.decode[map[string]json2.Any](binding.encode_element_state(element))!
		assert first.len > 1
		assert json_string_property(first, 'bridgeKey')? == key
		if id == 'field' {
			assert json_string_property(first, 'value')? == 'initial'
		} else {
			assert json_string_property(first, 'namespaceURI')? == 'http://www.w3.org/2000/svg'
		}
		second := binding.encode_element_state(element)
		assert second == json2.encode(json2.Any({
			'bridgeKey': json2.Any(key)
		}))
		assert binding.encode_node_state(element.as_node()) == second
		assert voidptr(binding.elements[key]) == voidptr(element)
	}
}

fn test_compact_identity_reply_preserves_non_element_node_states() {
	mut document := html.parse_document('<!doctype html><main id="host">text<!--comment--></main>')
	mut binding := &CompactElementQueryBinding{ document: document, runtime: unsafe { nil } }
	host := document.get_element_by_id('host') or { panic('host') }
	binding.keys[voidptr(host)] = '__element_host'
	binding.elements['__element_host'] = host
	for node in [host.as_node().first_child()?, host.as_node().last_child()?,
		document.create_document_fragment().as_node(), document.as_node()] {
		assert binding.encode_node_state(node) == json2.encode(binding.node_state(node))
	}
}

fn test_compact_element_query_retires_its_hydration_reply() {
	mut document := dom.Document.create(dom.URL{value: 'https://identity-reply.test/'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	html.parse_html_from_a_string(document, '<!doctype html><textarea id="field">λ😀</textarea>')
	element := document.get_element_by_id('field') or { panic('field') }
	mut binding := &CompactElementQueryBinding{document: document, runtime: unsafe { nil }}
	key := '__element_field'
	binding.keys[voidptr(element)] = key
	binding.elements[key] = element
	request := r'{"key":"","action":"documentElementById","selector":"field"}'
	first := binding.query_with_temporary_reply(request)!
	state := json2.decode[map[string]json2.Any](first.value)!
	$if prealloc {
		assert !document.native_storage().arena.contains(first.value.str)
	}
	assert json_string_property(state, 'bridgeKey')? == key
	assert json_string_property(state, 'value')? == 'λ😀'
	first.workspace.finish()
	after := binding.query_with_temporary_reply(request)!
	assert after.value == json2.encode(json2.Any({'bridgeKey': json2.Any(key)}))
	after.workspace.finish()
	model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	assert model.value() == 'λ😀'
}

fn test_compact_identity_reply_preserves_wrappers_across_live_queries() {
	mut document := html.parse_document('<!doctype html><main id="host"><input id="field" value="initial"><svg><rect id="shape" width="7"/></svg></main>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://identity-reply.test/', [r'
const first=document.getElementById("field"),shape=document.querySelector("rect");
if(first.value!=="initial"||shape.namespaceURI!=="http://www.w3.org/2000/svg")throw new Error("hydration");
for(let i=0;i<8;i++){
 if(document.querySelector("input")!==first||host.getElementsByTagName("input")[0]!==first)throw new Error("input identity");
 if(document.getElementById("shape")!==shape||document.querySelectorAll("rect")[0]!==shape)throw new Error("SVG identity");
}
first.value="changed";first.setAttribute("data-label","λ😀");
if(document.querySelector("input").value!=="changed"||document.getElementById("field").getAttribute("data-label")!=="λ😀")throw new Error("live state");
host.appendChild(first);
if(host.lastChild!==first||first.parentNode!==host)throw new Error("node identity");
'], runtime, mut messages)
	assert messages == []string{}
}
