module main

import browserjs
import html
import x.json2

fn test_click_replay_sends_pending_edits_without_the_unchanged_document() {
	mut document := html.parse_document('<!doctype html><button id="toggle">toggle</button><p id="content">before</p>' +
		'<div class="untouched">unchanged</div>'.repeat(1024))
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'toggle.addEventListener("click",function(event){content.textContent="after";content.setAttribute("class","expanded");console.log("once");event.preventDefault();});',
	], runtime, mut messages)
	encoded := runtime.evaluate_host('__ladybirdDispatch("click","toggle")')!
	result := json2.decode[map[string]json2.Any](encoded)!
	assert result['elements']!.as_map().len == 1
	assert result['operations']!.as_array().len == 1
	assert javascript_default_prevented(encoded)
	apply_javascript_runtime_state(document, encoded, runtime, mut messages)
	runtime.evaluate_host('__ladybirdClearLogs()')!
	content := document.get_element_by_id('content')?
	assert content.as_node().text_content()? == 'after'
	assert content.get_attribute_value('class') == 'expanded'
	assert messages == ['once']
	full := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdSnapshot()')!)!
	assert full['elements']!.as_map().len > 1024
	second := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdFinalize()')!)!
	assert second['elements']!.as_map().len == 0
	assert second['operations']!.as_array().len == 0
}

fn test_click_delta_preserves_edits_after_a_synchronous_native_query() {
	mut document := html.parse_document('<!doctype html><button id="toggle" onclick="content.textContent=\'first\';document.querySelector(\'#content\');content.textContent=\'last\';location.href=\'/next\';return false;">toggle</button><p id="content">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', []string{}, runtime, mut messages)
	encoded := runtime.evaluate_host('__ladybirdDispatch("click","toggle")')!
	assert javascript_default_prevented(encoded)
	assert apply_javascript_runtime_state(document, encoded, runtime, mut messages)? == '/next'
	assert (document.get_element_by_id('content')?).as_node().text_content()? == 'last'
	assert messages == []string{}
}
