module dom

fn test_segmenter_uses_utf16_grapheme_boundaries() {
	mut segmenter := Segmenter{
		granularity: .grapheme
	}
	segmenter.set_segmented_text('a👩🏼‍❤️‍👨🏻b')
	boundaries := segmenter.boundaries()
	assert boundaries[0] == 0
	assert boundaries[1] == 1
	assert boundaries.len == 4
	assert boundaries.last() == utf16_code_unit_length(segmenter.segmented_text)
	assert segmenter.next_boundary(1) or { -1 } == boundaries[2]
	assert segmenter.previous_boundary(boundaries[2]) or { -1 } == 1
}

fn test_grapheme_edge_tracker_resolves_nearest_edge() {
	mut tracker := GraphemeEdgeTracker.new(1.4)
	assert tracker.update(1, 1) == .@continue
	assert tracker.update(2, 1) == .@break
	assert tracker.resolve() == 1

	mut other := GraphemeEdgeTracker.new(1.6)
	assert other.update(1, 1) == .@continue
	assert other.update(2, 1) == .@break
	assert other.resolve() == 3
}

fn test_line_navigation_preserves_grapheme_column() {
	text := 'ab👩🏼‍❤️‍👨🏻\nx👩🏼‍❤️‍👨🏻z'
	first_line_offset := find_line_end(text, 0)
	next := compute_cursor_position_on_next_line(text, first_line_offset) or { -1 }
	assert next == utf16_code_unit_length('ab👩🏼‍❤️‍👨🏻\nx👩🏼‍❤️‍👨🏻z')
	previous := compute_cursor_position_on_previous_line(text, next) or { -1 }
	assert previous == first_line_offset
}
