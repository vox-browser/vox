module dom

// GraphemeEdgeTracker translates LibWeb's visual edge selection algorithm.
// The adjacent-line helpers use one unit per grapheme until the layout port can
// expose font measurement to DOM without introducing a module cycle.

pub enum GraphemeEdgeTrackerDecision {
	@continue
	@break
}

pub struct GraphemeEdgeTracker {
pub mut:
	target_width        f32
	left_edge           int
	right_edge          int
	width_to_left_edge  f32
	width_to_right_edge f32
}

pub fn GraphemeEdgeTracker.new(target_width f32) GraphemeEdgeTracker {
	return GraphemeEdgeTracker{
		target_width: target_width
	}
}

pub fn (mut tracker GraphemeEdgeTracker) update(grapheme_length_in_code_units int, grapheme_width f32) GraphemeEdgeTrackerDecision {
	if grapheme_width == 0 {
		return .@continue
	}
	tracker.right_edge += grapheme_length_in_code_units
	tracker.width_to_right_edge += grapheme_width
	if tracker.width_to_right_edge >= tracker.target_width {
		return .@break
	}
	tracker.left_edge = tracker.right_edge
	tracker.width_to_left_edge = tracker.width_to_right_edge
	return .@continue
}

pub fn (tracker GraphemeEdgeTracker) resolve() int {
	if tracker.target_width - tracker.width_to_left_edge < tracker.width_to_right_edge - tracker.target_width {
		return tracker.left_edge
	}
	return tracker.right_edge
}

fn segmenter_grapheme_boundaries(text string) []int {
	mut boundaries := [0]
	mut code_units := 0
	for grapheme in text.graphemes() {
		code_units += utf16_code_unit_length(grapheme)
		boundaries << code_units
	}
	return boundaries
}

fn segmenter_word_class(grapheme string) int {
	if grapheme.len == 0 {
		return 0
	}
	if grapheme.len > 1 || grapheme[0] >= 0x80 {
		return 1
	}
	byte := grapheme[0]
	if (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)
		|| (byte >= `0` && byte <= `9`) || byte == `_` {
		return 1
	}
	if byte == ` ` || byte == `\t` || byte == `\n` || byte == `\r` || byte == `\f` {
		return 2
	}
	return 3
}

fn segmenter_word_boundaries(text string) []int {
	mut boundaries := [0]
	mut code_units := 0
	mut previous_class := -1
	for grapheme in text.graphemes() {
		class := segmenter_word_class(grapheme)
		if previous_class >= 0 && class != previous_class {
			boundaries << code_units
		}
		code_units += utf16_code_unit_length(grapheme)
		previous_class = class
	}
	if boundaries.len == 0 || boundaries.last() != code_units {
		boundaries << code_units
	}
	return boundaries
}

fn segmenter_line_boundaries(text string) []int {
	mut boundaries := [0]
	mut code_units := 0
	for grapheme in text.graphemes() {
		code_units += utf16_code_unit_length(grapheme)
		if grapheme == '\n' {
			boundaries << code_units
		}
	}
	if boundaries.last() != code_units {
		boundaries << code_units
	}
	return boundaries
}

pub fn (segmenter &Segmenter) boundaries() []int {
	return match segmenter.granularity {
		.grapheme { segmenter_grapheme_boundaries(segmenter.segmented_text) }
		.word { segmenter_word_boundaries(segmenter.segmented_text) }
		.line { segmenter_line_boundaries(segmenter.segmented_text) }
	}
}

pub fn (segmenter &Segmenter) next_boundary(offset int) ?int {
	for boundary in segmenter.boundaries() {
		if boundary > offset {
			return boundary
		}
	}
	return none
}

pub fn (segmenter &Segmenter) previous_boundary(offset int) ?int {
	boundaries := segmenter.boundaries()
	for index := boundaries.len - 1; index >= 0; index-- {
		if boundaries[index] < offset {
			return boundaries[index]
		}
	}
	return none
}

pub fn segmenter_should_continue_beyond_word(text string) bool {
	for grapheme in text.graphemes() {
		if segmenter_word_class(grapheme) == 1 {
			return false
		}
	}
	return true
}

pub fn find_line_start(text string, offset int) int {
	units := utf16_code_units_from_string(text)
	mut result := if offset < units.len { offset } else { units.len }
	for result > 0 && units[result - 1] != u16(`\n`) {
		result--
	}
	return result
}

pub fn find_line_end(text string, offset int) int {
	units := utf16_code_units_from_string(text)
	mut result := if offset < 0 {
		0
	} else if offset < units.len {
		offset
	} else {
		units.len
	}
	for result < units.len && units[result] != u16(`\n`) {
		result++
	}
	return result
}

fn grapheme_count_before_offset(text string, offset int) int {
	mut count := 0
	for boundary in segmenter_grapheme_boundaries(text) {
		if boundary == 0 {
			continue
		}
		if boundary > offset {
			break
		}
		count++
	}
	return count
}

fn translate_grapheme_position(target_line string, target_width int) int {
	mut tracker := GraphemeEdgeTracker.new(f32(target_width))
	mut previous := 0
	for boundary in segmenter_grapheme_boundaries(target_line) {
		if boundary == 0 {
			continue
		}
		if tracker.update(boundary - previous, 1) == .@break {
			break
		}
		previous = boundary
	}
	return tracker.resolve()
}

pub fn compute_cursor_position_on_next_line(text string, current_offset int) ?int {
	units := utf16_code_units_from_string(text)
	current_line_end := find_line_end(text, current_offset)
	if current_line_end >= units.len {
		return units.len
	}
	current_line_start := find_line_start(text, current_offset)
	source := string_from_utf16_code_units(units[current_line_start..current_offset])
	next_line_start := current_line_end + 1
	next_line_end := find_line_end(text, next_line_start)
	target := string_from_utf16_code_units(units[next_line_start..next_line_end])
	return next_line_start +
		translate_grapheme_position(target, grapheme_count_before_offset(source, utf16_code_unit_length(source)))
}

pub fn compute_cursor_position_on_previous_line(text string, current_offset int) ?int {
	units := utf16_code_units_from_string(text)
	current_line_start := find_line_start(text, current_offset)
	if current_line_start == 0 {
		return 0
	}
	source := string_from_utf16_code_units(units[current_line_start..current_offset])
	previous_line_start := find_line_start(text, current_line_start - 1)
	previous_line_end := current_line_start - 1
	target := string_from_utf16_code_units(units[previous_line_start..previous_line_end])
	return previous_line_start +
		translate_grapheme_position(target, grapheme_count_before_offset(source, utf16_code_unit_length(source)))
}
