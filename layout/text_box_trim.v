module layout

// Trim the outer leading of a horizontal text-only formatting context. The
// line-to-line baseline distance is preserved. The font's metrics, rather
// than glyph ink or a page-specific offset, define both requested edges.
// Block-child propagation, vertical text and atomic inline edges are pending.
fn apply_text_box_trim(container &BlockContainer, mut used UsedValues) bool {
	style := container.computed_values()
	trim := style.text_box_trim()
	if trim == .none_ || style.writing_mode() != .horizontal_tb || used.line_boxes.len == 0 {
		return false
	}
	for line in used.line_boxes {
		if line.has_block_level_box_ { return false }
		for fragment in line.fragments_ {
			if fragment.layout_node_.is_break_node() { continue }
			if !fragment.layout_node_.is_text_node() { return false }
			source := fragment_alignment_style_source(&fragment)
			if source.computed_values().vertical_align() != .baseline
				|| source.computed_values().vertical_align_length_percentage() != none {
				return false
			}
		}
	}
	edge := style.text_box_edge()
	metrics := layout_font_metrics_for_node(unsafe { &Node(container) })
	over := CSSPixels.nearest_value_for(f64(match edge.over {
		.text { metrics.ascent }
		.cap { metrics.cap_height }
		.ex { metrics.x_height }
	}))
	under := if edge.alphabetic_under {
		CSSPixels.new(0)
	} else {
		CSSPixels.nearest_value_for(f64(metrics.descent))
	}
	first := &used.line_boxes[0]
	last_index := used.line_boxes.len - 1
	last := &used.line_boxes[last_index]
	start := if trim in [.trim_start, .trim_both] {
		css_pixels_max(CSSPixels.new(0), first.baseline().minus(over))
	} else {
		CSSPixels.new(0)
	}
	end := if trim in [.trim_end, .trim_both] {
		css_pixels_max(CSSPixels.new(0), last.height().minus(last.baseline()).minus(under))
	} else {
		CSSPixels.new(0)
	}
	if start.raw_value() == 0 && end.raw_value() == 0 { return false }
	for mut line in used.line_boxes {
		line.bottom_ = line.bottom_.minus(start)
		if baseline := line.font_box_baseline_ { line.font_box_baseline_ = baseline.minus(start) }
		for mut fragment in line.fragments_ {
			fragment.block_offset_ = fragment.block_offset_.minus(start)
		}
		for mut marker in line.static_position_markers_ {
			marker.block_offset = marker.block_offset.minus(start)
		}
	}
	used.line_boxes[0].block_length_ = used.line_boxes[0].block_length_.minus(start)
	used.line_boxes[0].baseline_ = used.line_boxes[0].baseline_.minus(start)
	used.line_boxes[0].trimmed_block_start_ = start
	used.line_boxes[last_index].block_length_ = used.line_boxes[last_index].block_length_.minus(end)
	used.line_boxes[last_index].bottom_ = used.line_boxes[last_index].bottom_.minus(end)
	return true
}
