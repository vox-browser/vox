// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module html

import dom
import webgl

struct SourceCanvasRepaintWitness {
mut:
	invalidations []dom.InvalidateDisplayList
}

fn source_canvas_repaint_callback(owner voidptr, _ voidptr, invalidation dom.InvalidateDisplayList) {
	mut witness := unsafe { &SourceCanvasRepaintWitness(owner) }
	witness.invalidations << invalidation
}

fn test_source_webgl_canvas_update_keeps_retained_paint_commands_and_updates_actual_surface() {
	for kind in ['webgl', 'webgl2'] {
		mut document := dom.Document.create(dom.url_about_blank())
		element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
		mut canvas := unsafe { &dom.HTMLCanvasElement(element) }
		html_canvas_element_set_width(mut canvas, 1)!
		html_canvas_element_set_height(mut canvas, 1)!
		rendering := html_canvas_element_get_rendering_context(canvas, kind, {
			'preserveDrawingBuffer': dom.js_bool(true)
		})!
		mut context := rendering.webgl_context or { panic('native Source context') }
		mut witness := &SourceCanvasRepaintWitness{}
		mut paintable := &dom.Paintable{
			repaint_callback_target:    voidptr(witness)
			callbacks: &dom.PaintableCallbacks{ set_needs_repaint_callback: source_canvas_repaint_callback }
		}
		mut node := unsafe { &dom.Node(canvas) }
		node.set_layout_node(&dom.LayoutNode{ paintables_: [paintable] })
		mut source := html_canvas_element_ensure_external_content_source(canvas)
		for color in [[f32(1), 0, 0, 1]!, [f32(0), 0, 1, 1]!] {
			witness.invalidations.clear()
			paintable.needs_repaint = false
			context.clear_color(color[0], color[1], color[2], color[3])
			context.clear(0x4000)
			assert html_canvas_element_is_dirty(canvas)
			assert paintable.needs_repaint
			assert witness.invalidations == [dom.InvalidateDisplayList.no]
			frame := html_canvas_element_present_existing_surface(canvas) or { panic('actual presented surface') }
			expected := if color[0] == 1 { [u8(255), 0, 0, 255] } else { [u8(0), 0, 255, 255] }
			assert frame.data == expected
			assert source.current_frame()?.bitmap().data == expected
			assert context.get_error() == webgl.no_error
		}
		witness.invalidations.clear()
		// Source did_update_canvas_content has no lost-context early return.
		context.lose_context_from_compositor_loss()
		context.draw_arrays(0xbad, -1, -1)
		assert html_canvas_element_is_dirty(canvas)
		assert witness.invalidations == [dom.InvalidateDisplayList.no]
	}
}
