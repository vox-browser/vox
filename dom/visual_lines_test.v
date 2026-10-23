module dom

fn visual_lines_test_text() (&Document, &Text) {
	mut document := Document.create_for_fragment_parsing()
	text := document.create_text_node('abcd  efgh')
	mut text_node := text.as_node()
	text_node.set_layout_node(&LayoutNode{
		is_text_node_:      true
		visual_lines_data_: &LayoutVisualLines{
			values: [
				VisualLine{
					start_offset:                        0
					end_offset:                          4
					end_offset_with_trailing_whitespace: 6
					has_fragments:                       true
					line_index:                          0
					caret_stops:                         [
						VisualCaretStop{ offset: 0, inline_coordinate: 0 },
						VisualCaretStop{ offset: 2, inline_coordinate: 20 },
						VisualCaretStop{ offset: 4, inline_coordinate: 40 },
						VisualCaretStop{ offset: 6, inline_coordinate: 60 },
					]
				},
				VisualLine{
					start_offset:                        6
					end_offset:                          10
					end_offset_with_trailing_whitespace: 10
					has_fragments:                       true
					line_index:                          1
					caret_stops:                         [
						VisualCaretStop{ offset: 6, inline_coordinate: 0 },
						VisualCaretStop{ offset: 8, inline_coordinate: 20 },
						VisualCaretStop{ offset: 10, inline_coordinate: 40 },
					]
				},
			]
		}
	})
	return document, text
}

fn test_visual_line_affinity_disambiguates_a_soft_wrap_boundary() {
	_, text := visual_lines_test_text()
	lines := collect_visual_lines(text)
	assert lines.len == 2
	assert visual_line_index_for_offset(lines, 6, .upstream)? == 0
	assert visual_line_index_for_offset(lines, 6, .downstream)? == 1

	right := compute_cursor_position_on_next_character(text, 6, .upstream) or {
		panic('missing soft-wrap right step')
	}
	assert right == CursorLinePosition{ offset: 6, affinity: .downstream }
	left := compute_cursor_position_on_previous_character(text, 6, .downstream) or {
		panic('missing soft-wrap left step')
	}
	assert left == CursorLinePosition{ offset: 6, affinity: .upstream }
}

fn test_visual_line_vertical_navigation_preserves_the_inline_coordinate() {
	_, text := visual_lines_test_text()
	next := compute_cursor_position_on_next_line(text, 2, .downstream) or {
		panic('missing next visual line')
	}
	assert next == CursorLinePosition{ offset: 8, affinity: .downstream }
	previous := compute_cursor_position_on_previous_line(text, next.offset, next.affinity) or {
		panic('missing previous visual line')
	}
	assert previous == CursorLinePosition{ offset: 2, affinity: .downstream }
	assert cursor_inline_coordinate(text, 8, .downstream)? == 20
	assert cursor_position_on_first_line_closest_to(text, 31)? == CursorLinePosition{
		offset:   4
		affinity: .downstream
	}
	assert cursor_position_on_last_line_closest_to(text, none)? == CursorLinePosition{
		offset:   6
		affinity: .downstream
	}
}

fn test_visual_line_edges_include_hanging_whitespace_and_retain_affinity() {
	_, text := visual_lines_test_text()
	assert cursor_position_at_visual_start(text)? == CursorLinePosition{ offset: 0 }
	assert cursor_position_at_visual_end(text)? == CursorLinePosition{ offset: 10 }
	assert find_visual_line_start(text, 6, .upstream) == 0
	assert find_visual_line_start(text, 6, .downstream) == 6
	assert find_visual_line_end(text, 2, .downstream) == CursorLinePosition{
		offset:   6
		affinity: .upstream
	}
}

fn test_caret_navigator_visits_both_visual_positions_at_a_soft_wrap() {
	document, text := visual_lines_test_text()
	navigator := CaretNavigator.new(document)
	right := navigator.move(CaretLocation{
		node:     text.as_node()
		offset:   6
		affinity: .upstream
	}, .move, .forward, .character, none) or { panic('missing right destination') }
	assert right.offset == 6
	assert right.affinity == .downstream
	left := navigator.move(right, .move, .backward, .character, none) or {
		panic('missing left destination')
	}
	assert left.offset == 6
	assert left.affinity == .upstream
}
