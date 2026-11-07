module main

import browserjs
import css
import dom
import html
import platform

fn replay_snapshot_trial(temporary bool) ?i64 {
	mut document := dom.Document.create(dom.URL{value: 'https://replay-snapshot.test/'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><main id="target">before</main>')
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut binding := &CompactElementQueryBinding{document: document, runtime: runtime}
	target := document.get_element_by_id('target')?
	binding.elements['target'] = target
	binding.keys[voidptr(target)] = 'target'
	state := '{"elements":{"target":{"bridgeKey":"target","attributesDirty":true,"attributes":{"id":"target","data-label":"λ😀"},"textContentDirty":true,"textContent":"after 雪😀"}},"logs":["retained λ😀"],"operations":[{"op":"appendCreated","target":"target","child":{"bridgeKey":"created-svg","tagName":"svg","namespaceURI":"http://www.w3.org/2000/svg","attributeRecords":[{"localName":"href","prefix":"xlink","namespaceURI":"http://www.w3.org/1999/xlink","value":"link λ😀"}]}}],"unused":[' + '{"padding":[1,2,3,4],"other":{"more":17}},'.repeat(255) + '{"last":true}]}'
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	mut messages := []string{}
	if temporary {
		replay := compact_query_replay_snapshot(document, state, mut messages)?
		_ = apply_decoded_javascript_state(document, replay.state, binding.elements, mut messages)
		replay.workspace.finish()
	} else {
		decoded := javascript_replay_state(state, mut messages)?
		_ = apply_decoded_javascript_state(document, decoded, binding.elements, mut messages)
	}
	growth := if storage != unsafe { nil } { storage.arena.usage().used - before } else { i64(0) }
	assert target.get_attribute_value('data-label') == 'λ😀'
	assert target.as_node().text_content()? == 'after 雪😀'
	assert messages == ['retained λ😀']
	churn := platform.begin_thread_scratch('replay snapshot overwrite')
	_ = []u8{len: 128 * 1024, init: u8(0xa5)}
	churn.finish()
	assert target.get_attribute_value('data-label') == 'λ😀'
	assert target.as_node().text_content()? == 'after 雪😀'
	assert messages[0] == 'retained λ😀'
	svg := target.as_node().last_child()?.as_element()?
	assert svg.namespace_uri()? == 'http://www.w3.org/2000/svg'
	assert svg.get_attribute_ns('http://www.w3.org/1999/xlink', 'href')? == 'link λ😀'
	return growth
}

fn test_replay_snapshot_retires_containers_and_retains_dom_strings() {
	control := replay_snapshot_trial(false)?
	candidate := replay_snapshot_trial(true)?
	$if prealloc {
		println('Replay snapshot: candidate=${candidate} control=${control} retained bytes')
		assert candidate * 4 < control
	}
}

fn test_query_snapshot_keeps_created_svg_namespaces_and_bridge_identity() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://replay-snapshot.test/svg', [r'
const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
svg.id="graphic";svg.setAttribute("viewBox","0 0 10 10");
const rect=document.createElementNS(svg.namespaceURI,"rect");
rect.id="shape";rect.setAttribute("data-Label","λ😀");
svg.appendChild(rect);host.appendChild(svg);
if(document.querySelector("#shape")!==rect)throw new Error("created identity");
rect.setAttribute("fill","red");
if(document.querySelector("#graphic")!==svg)throw new Error("parent identity");
if(rect.getAttribute("data-Label")!=="λ😀")throw new Error("namespace lifetime");
'], runtime, mut messages)
	assert messages == []string{}
	shape := css.query_selector_all(document.as_node(), '#shape')
	assert shape.len == 1
	assert shape[0].namespace_uri()? == 'http://www.w3.org/2000/svg'
	assert shape[0].get_attribute('data-Label')? == 'λ😀'
}
