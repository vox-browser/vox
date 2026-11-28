module layout

import dom
import html

fn canvas_activation_draws(mut document dom.Document) []PaintCommand {
	display_list := document.record_display_list() or { panic('missing canvas document paint') }
	return display_list_commands(display_list).filter(it.kind == 'draw_canvas')
}

fn test_canvas_contexts_created_after_paint_reuse_layout_geometry() {
	mut document := html.parse_document('<!doctype html><style>canvas{display:block;width:40px;height:20px}</style><canvas id="two" width="4" height="2"></canvas><canvas id="gl" width="4" height="2"></canvas><canvas></canvas>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 120)
	assert canvas_activation_draws(mut document).len == 0
	result := document_layout_result(document) or { panic('missing initial layout') }
	two := unsafe { &dom.HTMLCanvasElement(document.get_element_by_id('two') or { panic('missing 2D canvas') }) }
	gl := unsafe { &dom.HTMLCanvasElement(document.get_element_by_id('gl') or { panic('missing WebGL canvas') }) }
	mut two_context := html.html_canvas_element_get_context(two, '2d', none) or { panic(err) }
	mut gl_context := html.html_canvas_element_create_webgl2_context(gl, none) or { panic(err) }
	assert voidptr(gl_context) != unsafe { nil }
	two_context.fill_rect(0, 0, 4, 2)
	gl_context.clear_color(1, 0, 0, 1)
	gl_context.clear(0x4000)
	assert document.layout_is_up_to_date()
	commands := canvas_activation_draws(mut document)
	assert commands.len == 2
	two_pixels := commands[0].canvas_bitmap or { panic('missing 2D pixels') }
	gl_pixels := commands[1].canvas_bitmap or { panic('missing WebGL pixels') }
	assert two_pixels.data[..4] == [u8(0), 0, 0, 255]
	assert gl_pixels.data[..4] == [u8(255), 0, 0, 255]
	canvas := commands[1].canvas_paintable or { panic('missing retained canvas geometry') }
	assert canvas.canvas_rect.width == 40 && canvas.canvas_rect.height == 20

	gl_context.clear_color(0, 0, 1, 1)
	gl_context.clear(0x4000)
	assert document.layout_is_up_to_date()
	updated := canvas_activation_draws(mut document)
	assert updated.len == 2
	assert voidptr(updated[1].canvas_paintable?) == voidptr(canvas)
	assert updated[1].canvas_bitmap?.data[..4] == [u8(0), 0, 255, 255]
	assert voidptr(document_layout_result(document)?) == voidptr(result)
}
