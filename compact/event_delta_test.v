module main

import browserjs
import html
import x.json2

fn test_click_replay_keeps_native_attribute_edits_out_of_the_pending_journal() {
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
	// The native attribute call commits the preceding text write itself.
	// Completion must not serialize it again or include unchanged elements.
	assert result['elements']!.as_map().len == 0
	assert result['operations']!.as_array().len == 0
	assert javascript_default_prevented(encoded)
	content := document.get_element_by_id('content')?
	assert content.as_node().text_content()? == 'after'
	assert content.get_attribute_value('class') == 'expanded'
	commit := apply_compact_dom_task(document, encoded, runtime, mut messages)!
	assert commit.navigation == none
	assert messages == ['once']
	full := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdSnapshot()')!)!
	assert full['elements']!.as_map().len > 1024
	second := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdFinalize()')!)!
	assert second['elements']!.as_map().len == 0
	assert second['operations']!.as_array().len == 0
}

fn test_click_delta_preserves_edits_after_a_synchronous_native_query() {
	// Native inline handlers include the element in their scope chain; avoid
	// the legacy facade's own content member shadowing the named paragraph.
	mut document := html.parse_document('<!doctype html><button id="toggle" onclick="document.getElementById(\'content\').textContent=\'first\';document.querySelector(\'#content\');document.getElementById(\'content\').textContent=\'last\';location.href=\'/next\';return false;">toggle</button><p id="content">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', []string{}, runtime, mut messages)
	encoded := runtime.evaluate_host('__ladybirdDispatch("click","toggle")')!
	assert javascript_default_prevented(encoded)
	commit := apply_compact_dom_task(document, encoded, runtime, mut messages)!
	assert commit.navigation? == '/next'
	assert (document.get_element_by_id('content')?).as_node().text_content()? == 'last'
	assert messages == []string{}
}
