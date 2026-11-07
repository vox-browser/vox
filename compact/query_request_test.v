module main

import browserjs
import html
import platform
import x.json2

fn test_compact_query_envelope_keeps_owned_fields_after_workspace_finish() {
	input := '{"key":"__element_12","action":"querySelector","selector":"main a"}'.clone()
	request := decode_compact_element_query_request(input)!
	request.workspace.finish()
	unsafe { C.memset(input.str, `x`, uint(input.len)) }
	gc_collect()
	assert request.key == '__element_12'
	assert request.action? == 'querySelector'
	assert request.selector? == 'main a'
	assert request.snapshot == none
	assert request.log_count == 0
}

fn test_compact_query_request_retires_json_graphs_and_owns_replayed_strings() {
	input := json2.encode({
		'action': json2.Any('setMarkup')
		'selector': json2.Any('<span data-value="Привет 🌍">retained</span>')
		'key': json2.Any('__query_42')
		'snapshot': json2.Any('{"elements":{},"operations":[]}')
		'logCount': json2.Any(3)
		'unused': json2.Any([]json2.Any{len: 256, init: json2.Any({'value': json2.Any('temporary')})})
	})
	mut control := platform.new_arena('query decoder control')
	entry := control.enter()
	expected := json2.decode[map[string]json2.Any](input)!
	assert json_string_property(expected, 'key')? == '__query_42'
	control.leave(entry)
	before := platform.thread_arena_usage().used
	request := decode_compact_element_query_request(input)!
	defer { request.workspace.finish() }
	growth := platform.thread_arena_usage().used - before
	$if prealloc {
		assert growth * 10 < control.usage().used, '${growth} retained versus ${control.usage().used} control bytes'
		println('Compact query request: retained=${growth} control=${control.usage().used} bytes')
	}
	control.release()
	churn := platform.begin_thread_scratch('query decoder overwrite')
	_ = []u8{len: 1024 * 1024, init: u8(0xa5)}
	churn.finish()
	assert request.action? == 'setMarkup'
	assert request.selector? == '<span data-value="Привет 🌍">retained</span>'
	assert request.key == '__query_42'
	assert request.snapshot? == '{"elements":{},"operations":[]}'
	assert request.log_count == 3
	missing := decode_compact_element_query_request('{"selector":false,"action":null,"key":42,"logCount":"bad"}')!
	defer { missing.workspace.finish() }
	assert missing.selector == none
	assert missing.action == none
	assert missing.key == ''
	assert missing.log_count == 0
	if _ := decode_compact_element_query_request('{invalid}') {
		assert false
	} else {
		assert err.msg().len > 0
	}
}

fn test_compact_query_snapshot_bytes_retire_with_the_request_workspace() {
	input := json2.encode({
		'action': json2.Any('querySelectorAll')
		'selector': json2.Any('span')
		'key': json2.Any('__query_42')
		'snapshot': json2.Any('{"elements":{},"operations":[],"log":["' + 'λ😀'.repeat(16384) + '"]}')
	})
	mut owner := platform.new_retained_arena('query snapshot transport retention')
	mut entered := owner.enter()
	defer {
		entered.finish()
		owner.release()
	}
	before := owner.arena.usage().used
	for _ in 0 .. 16 {
		request := decode_compact_element_query_request(input)!
		assert request.selector? == 'span'
		assert request.snapshot?.len > 64 * 1024
		assert request.snapshot?.contains('"operations":[]')
		request.workspace.finish()
		// Identity and selector text keep their independent allocation owner.
		assert request.key == '__query_42'
		assert request.selector? == 'span'
	}
	growth := owner.arena.usage().used - before
	$if prealloc {
		assert growth < 4096, '${growth} bytes retained by 16 large snapshot requests'
		println('Compact query snapshot transport: retained=${growth} bytes')
	}
}

fn test_compact_query_request_preserves_native_mutations_after_decoder_retirement() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://query-storage.test/', [r'
host.innerHTML="<span id=child data-value=first>Привет 🌍</span>";
const child=document.querySelector("#child");
child.setAttribute("data-value","retained λ");
const text=document.createTextNode(" durable 🌍");
child.appendChild(text);
if(host.querySelector("span")!==child||child.getAttribute("data-value")!=="retained λ"||child.textContent!=="Привет 🌍 durable 🌍")throw new Error("query request lifetime");
'], runtime, mut messages)
	assert messages == []string{}
	child := document.get_element_by_id('child')?
	assert child.get_attribute_value('data-value') == 'retained λ'
	assert child.as_node().text_content()? == 'Привет 🌍 durable 🌍'
}
