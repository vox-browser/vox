module layout

import dom
import html

fn cached_line_box_guides(result &DocumentLayoutResult) int {
	mut count := 0
	for bucket in result.paint_phase_commands {
		for command in bucket {
			if command.line_box_debug { count++ }
		}
	}
	return count
}

fn test_debug_guide_toggling_preserves_cached_commands_and_earlier_recordings() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}</style><p>retained text</p>')
	host := &dom.Navigable{
		active_document_: document
	}
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	initial := display_list_commands(document.record_display_list() or {
		panic('missing initial recording')
	})
	result := document_layout_result(document) or { panic('missing layout') }
	guide_count := cached_line_box_guides(result)
	assert guide_count >= 2
	assert initial.all(!it.line_box_debug)
	initial_text := initial.filter(it.kind == 'draw_text').map(it.text)
	assert initial_text == ['retained text']
	for _ in 0 .. 2 {
		navigable.set_should_show_line_box_borders(true)
		// The browser consumes the navigable's repaint flag at the next frame.
		document.set_needs_repaint_with_invalidation(.paint_commands)
		visible := display_list_commands(document.record_display_list() or {
			panic('missing guides')
		})
		assert visible.filter(it.line_box_debug).len == guide_count
		navigable.set_should_show_line_box_borders(false)
		document.set_needs_repaint_with_invalidation(.paint_commands)
		hidden := display_list_commands(document.record_display_list() or {
			panic('missing compact recording')
		})
		assert hidden.all(!it.line_box_debug)
		assert hidden.filter(it.kind == 'draw_text').map(it.text) == initial_text
		assert cached_line_box_guides(result) == guide_count
		assert visible.filter(it.line_box_debug).len == guide_count
		assert initial.all(!it.line_box_debug)
	}
}
