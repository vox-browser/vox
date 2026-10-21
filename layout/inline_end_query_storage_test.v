module layout

import css
import dom
import platform

fn test_inline_end_queries_read_line_bounds_without_boxing_line_copies() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	style := css.computed_properties_with_initial_values()
	computed := css.resolve_computed_values(style)
	container := BlockContainer.with_resolved_values(document, none, computed)
	mut lines := []LineBox{cap:16}
	for index in 0 .. 16 { lines << LineBox{bottom_:CSSPixels.new((index + 1) * 10)} }
	used := &UsedValues{line_boxes:lines}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		position := calculate_inline_end_static_position_rect(container, used)
		assert position.rect.x.to_double() == 0
		assert position.rect.y.to_double() == 160
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert used.line_boxes.len == 16
	assert used.line_boxes[0].bottom_.to_double() == 10
}
