module layout

import platform

// Resolve separate text/font fragments together. Reversing every fragment in
// an RTL line also reverses adjacent LTR spans, including split number runs.
// Leave mixed-direction fragments to their existing glyph-run ordering. Inline
// embeddings and boxes with edges need a full inline-box bidi tree first.
fn chromium_rtl_fragment_offsets(line &LineBox) []CSSPixels {
	if line.direction_ != .rtl || line.writing_mode_ != .horizontal_tb || line.fragments_.len < 2 {
		return []CSSPixels{}
	}
	mut text := []u16{}
	mut starts := []int{}
	for fragment in line.fragments_ {
		node := fragment.layout_node_.as_text_node() or { return []CSSPixels{} }
		if node.Node.document().font_rendering_policy() != .chromium
			|| !chromium_numeric_direction_is_not_overridden(node) {
			return []CSSPixels{}
		}
		mut parent := fragment.layout_node_.parent()
		for parent != none {
			current := parent or { break }
			if !current.is_inline() { break }
			if styled := current.as_node_with_style() {
				if styled.computed_values().unicode_bidi() != .normal { return []CSSPixels{} }
			}
			parent = current.parent()
		}
		starts << text.len
		text << utf16_code_units_for_line_box(fragment.text() or { return []CSSPixels{} })
	}
	levels := platform.bidi_paragraph_levels(text, true)
	if levels.len != text.len { return []CSSPixels{} }
	mut fragment_levels := []u8{}
	for index, start in starts {
		end := if index + 1 < starts.len { starts[index + 1] } else { text.len }
		if start == end { return []CSSPixels{} }
		level := levels[start]
		for offset in start .. end {
			if text[offset] != u16(` `) && levels[offset] != level { return []CSSPixels{} }
		}
		fragment_levels << level
	}
	order := platform.bidi_visual_order(fragment_levels)
	mut result := []CSSPixels{len: starts.len}
	mut position := CSSPixels.new(0)
	for index in order {
		result[index] = position
		position = position.plus(line.fragments_[index].inline_length())
	}
	// Non-text edges/gaps must retain the inline box model's original geometry.
	if position != line.inline_length() { return []CSSPixels{} }
	return result
}
