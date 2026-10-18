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
	initial := display_list_commands(record_retained_display_list(mut document) or {
		panic('missing initial recording')
	})
	result := document_layout_result(document) or { panic('missing layout') }
	assert cached_line_box_guides(result) == 0
	mut guide_count := 0
	assert initial.all(!it.line_box_debug)
	initial_text := initial.filter(it.kind == 'draw_text').map(it.text)
	assert initial_text == ['retained text']
	for _ in 0 .. 2 {
		navigable.set_should_show_line_box_borders(true)
		// The browser consumes the navigable's repaint flag at the next frame.
		document.set_needs_repaint_with_invalidation(.paint_commands)
		visible := display_list_commands(record_retained_display_list(mut document) or {
			panic('missing guides')
		})
		if guide_count == 0 {
			guide_count = visible.filter(it.line_box_debug).len
			assert guide_count >= 2
		}
		assert visible.filter(it.line_box_debug).len == guide_count
		assert cached_line_box_guides(result) == guide_count
		navigable.set_should_show_line_box_borders(false)
		document.set_needs_repaint_with_invalidation(.paint_commands)
		hidden := display_list_commands(record_retained_display_list(mut document) or {
			panic('missing compact recording')
		})
		assert hidden.all(!it.line_box_debug)
		assert hidden.filter(it.kind == 'draw_text').map(it.text) == initial_text
		assert cached_line_box_guides(result) == 0
		assert visible.filter(it.line_box_debug).len == guide_count
		assert initial.all(!it.line_box_debug)
	}
}

fn test_debug_guide_policy_survives_scrolling_to_deferred_entries() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}p{margin:0;height:100px}</style><p>first</p><p>middle</p><p>last</p>')
	defer { document.finalize() }
	host := &dom.Navigable{active_document_: document}
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	initial := debug_policy_viewport_commands(mut document)
	assert initial.all(!it.line_box_debug)
	navigable.set_should_show_line_box_borders(true)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	visible := debug_policy_viewport_commands(mut document)
	assert visible.any(it.line_box_debug)
	document.set_viewport_rect(dom.Rect{0, 200, 320, 100})
	scrolled := debug_policy_viewport_commands(mut document)
	assert scrolled.any(it.kind == 'draw_text' && it.text == 'last')
	assert scrolled.any(it.line_box_debug)
	navigable.set_should_show_line_box_borders(false)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	plain := debug_policy_viewport_commands(mut document)
	assert plain.all(!it.line_box_debug)
	assert cached_line_box_guides(document_layout_result(document)?) == 0
	assert initial.all(!it.line_box_debug) && visible.any(it.line_box_debug)
}

fn debug_policy_viewport_commands(mut document dom.Document) []PaintCommand {
	list := document.record_viewport_display_list() or { panic('missing viewport list') }
	// The commands are compared after later recordings, so keep their scene.
	_ = retain_display_list_scene(list)
	return display_list_commands(list)
}
