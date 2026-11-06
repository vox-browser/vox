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
		// CSSOM declaration edits update the live rule, without rewriting the
		// style element's source text (which would replace its sheet/identities).
		assert runtime.evaluate_host('rules.sheet.cssRules[0].style.backgroundColor')! == color
		assert style.as_node().text_content() or { '' } == 'canvas { background-color: red; }'
		canvas := document.get_element_by_id('canvas') or { panic('canvas') }
		assert voidptr(canvas) == voidptr(owner)
		bitmap := html.html_canvas_element_surface(unsafe { &dom.HTMLCanvasElement(canvas) }) or { panic('bitmap') }
		assert bitmap.width == 100
		assert bitmap.data[..4] == [u8(0), 255, 0, 255]
	}
	assert messages == []
}

// Drawing already updates the exact DOM canvas retained by the host registry.
// Finalization must preserve that owner without serializing its bitmap again.
fn test_canvas_finalization_retains_created_native_surface_without_pixel_readback() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="container"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 globalThis.drawing=document.createElement("canvas");drawing.id="drawing";
 drawing.width=1024;drawing.height=1024;
 globalThis.context=drawing.getContext("2d");context.fillStyle="red";context.fillRect(1023,1023,1,1);
 const nativeCall=__ladybirdCanvas;
 __ladybirdCanvas=function(input){if(JSON.parse(input).method==="snapshot")throw new Error("unexpected bitmap readback");return nativeCall(input);};
 container.appendChild(drawing);
 '], runtime, mut messages)
	assert messages == []
	owner := document.get_element_by_id('drawing') or { panic('missing created canvas') }
	canvas := unsafe { &dom.HTMLCanvasElement(owner) }
	context := html.html_canvas_element_get_context(canvas, '2d', none)!
	assert (context.get_image_data(1023, 1023, 1, 1, none)!).data() == [u8(255), 0, 0, 255]
	for _ in 0 .. 3 {
		state := runtime.evaluate_host('__ladybirdFinalize()')!
		assert !state.contains('canvasPixels')
		assert state.len < 16384
		apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
		assert voidptr(document.get_element_by_id('drawing')?) == voidptr(owner)
		assert (context.get_image_data(1023, 1023, 1, 1, none)!).data() == [u8(255), 0, 0, 255]
	}
	runtime.evaluate_host('drawing.width=2;drawing.height=1;context.fillStyle="lime";context.fillRect(1,0,1,1)')!
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	assert voidptr(document.get_element_by_id('drawing')?) == voidptr(owner)
	assert html.html_canvas_element_width(canvas) == 2
	assert html.html_canvas_element_height(canvas) == 1
	assert (context.get_image_data(0, 0, 2, 1, none)!).data() == [u8(0), 0, 0, 0, 0, 255, 0, 255]
}
