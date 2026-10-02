module main

import browserjs
import dom
import html

fn test_repeated_cssom_replay_preserves_native_canvas_owner_and_updated_rules() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><style id="rules">canvas { background-color: red; }</style><canvas id="canvas" width="50" height="50"></canvas>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['const context=canvas.getContext("2d");canvas.width=100;context.fillStyle="lime";context.fillRect(0,0,100,50);'], runtime, mut messages)
	owner := document.get_element_by_id('canvas') or { panic('canvas') }
	for color in ['blue', 'lime'] {
		runtime.evaluate_host('rules.sheet.cssRules[0].style.backgroundColor="${color}"') or { panic(err) }
		state := runtime.evaluate_host('__ladybirdFinalize()') or { panic(err) }
		apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
		runtime.evaluate_host('__ladybirdClearLogs()') or { panic(err) }
		style := document.get_element_by_id('rules') or { panic('rules') }
		assert (style.as_node().text_content() or { '' }).contains('background-color: ${color}')
		canvas := document.get_element_by_id('canvas') or { panic('canvas') }
		assert voidptr(canvas) == voidptr(owner)
		bitmap := html.html_canvas_element_surface(unsafe { &dom.HTMLCanvasElement(canvas) }) or { panic('bitmap') }
		assert bitmap.width == 100
		assert bitmap.data[..4] == [u8(0), 255, 0, 255]
	}
	assert messages == []
}
