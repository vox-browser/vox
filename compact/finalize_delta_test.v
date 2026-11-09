module main

import browserjs
import dom
import html
import x.json2

fn test_compact_finalization_sends_only_pending_elements_and_keeps_full_snapshot() {
	$if !darwin && !linux {
		return
	}
	document :=
		html.parse_document('<!doctype html><title>old title</title><p id="untouched">old</p><p id="changed">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['changed.textContent="initial"'], runtime, mut
		messages)
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	decoded := json2.decode[map[string]json2.Any](state)!
	assert (decoded['elements'] or { panic('missing elements') }).as_map().len == 0
	full := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdSnapshot()')!)!
	assert (full['elements'] or { panic('missing snapshot') }).as_map().len == 6
	runtime.evaluate_host('document.title="new title";changed.setAttribute("data-updated","yes");changed.textContent="next";console.log("once")')!
	updated := runtime.evaluate_host('__ladybirdFinalize()')!
	updated_state := json2.decode[map[string]json2.Any](updated)!
	assert (updated_state['elements'] or { panic('missing delta') }).as_map().len == 1
	commit := apply_compact_dom_task(document, updated, runtime, mut messages)!
	assert commit.navigation == none
	assert messages == ['once']
	changed := document.get_element_by_id('changed') or { panic('missing changed') }
	assert changed.get_attribute_value('data-updated') == 'yes'
	assert changed.as_node().text_content() or { '' } == 'next'
	assert document_title(document) == 'new title'
	untouched := document.get_element_by_id('untouched') or { panic('missing untouched') }
	assert !untouched.has_attribute('class')
	assert !untouched.has_attribute('style')
}

fn test_compact_finalization_keeps_native_canvas_pixels_and_ordered_selection_operations() {
	$if !darwin && !linux {
		return
	}
	document :=
		html.parse_document('<!doctype html><canvas id="drawing" width="2" height="1"></canvas><div id="parent"><p id="first">A</p><p id="second">B</p></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'globalThis.context=drawing.getContext("2d");context.fillStyle="red";context.fillRect(0,0,2,1)',
	], runtime, mut messages)
	owner := document.get_element_by_id('drawing') or { panic('missing canvas') }
	runtime.evaluate_host('context.fillStyle="lime";context.fillRect(1,0,1,1);document.getElementById("parent").moveBefore(second,first);getSelection().selectAllChildren(second)')!
	// The native selection call flushes the preceding move before it reads.
	// Both semantic changes are already visible before task finalization.
	parent_before := document.get_element_by_id('parent') or { panic('missing parent') }
	first_before := parent_before.as_node().children[0].as_element() or { panic('missing moved child') }
	assert first_before.get_attribute_value('id') == 'second'
	selection_before := document.get_selection() or { panic('missing selection') }
	assert selection_before.to_string() == 'B'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	decoded := json2.decode[map[string]json2.Any](state)!
	assert (decoded['elements'] or { panic('missing canvas state') }).as_map().len == 1
	assert (decoded['operations'] or { panic('missing operations') }).as_array().len == 0
	commit := apply_compact_dom_task(document, state, runtime, mut messages)!
	assert commit.navigation == none
	assert messages == []
	canvas := document.get_element_by_id('drawing') or { panic('missing canvas') }
	assert voidptr(canvas) == voidptr(owner)
	bitmap := html.html_canvas_element_surface(unsafe { &dom.HTMLCanvasElement(canvas) }) or {
		panic('missing bitmap')
	}
	assert bitmap.data[..8] == [u8(255), 0, 0, 255, 0, 255, 0, 255]
	parent := document.get_element_by_id('parent') or { panic('missing parent') }
	first := parent.as_node().children[0].as_element() or { panic('missing first element') }
	assert first.get_attribute_value('id') == 'second'
	selection := document.get_selection() or { panic('missing selection') }
	assert selection.to_string() == 'B'
}
