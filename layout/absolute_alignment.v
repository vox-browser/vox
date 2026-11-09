module layout

import css

struct AbsoluteSelfAlignment {
	position string = 'normal'
	overflow string
}

fn absolute_self_alignment(box &Node, containing &Node, horizontal bool) AbsoluteSelfAlignment {
	inline_axis := horizontal == (containing.computed_values().writing_mode() == .horizontal_tb)
	property := if inline_axis { css.PropertyID.justify_self } else { css.PropertyID.align_self }
	value := unsafe { &css.ComputedProperties(box.computed_values()) }.property(property, .yes) or {
		return AbsoluteSelfAlignment{}
	}
	words := value.css_text.split(' ')
	if words.len == 2 {
		return AbsoluteSelfAlignment{
			position: if words[0] == 'last' { 'end' } else { words[1] }
			overflow: if words[0] in ['safe', 'unsafe'] { words[0] } else { '' }
		}
	}
	return AbsoluteSelfAlignment{position: value.css_text}
}

fn (alignment AbsoluteSelfAlignment) stretches() bool {
	return alignment.position in ['auto', 'normal', 'stretch']
}

// CSS Align's start/end are relative to the containing block; self-start/end
// use the subject's writing mode and direction on the same physical axis.
fn absolute_axis_starts_low(node &Node, horizontal bool) bool {
	computed := node.computed_values()
	if horizontal {
		return if computed.writing_mode() == .horizontal_tb { computed.direction() == .ltr }
			else { computed.writing_mode() !in [.vertical_rl, .sideways_rl] }
	}
	return if computed.writing_mode() == .horizontal_tb { true }
		else { (computed.direction() == .ltr) != (computed.writing_mode() == .sideways_lr) }
}

fn absolute_aligned_axis_offset(alignment AbsoluteSelfAlignment, box &Node, containing &Node,
	horizontal bool, start CSSPixels, end CSSPixels, extent CSSPixels, outer_size CSSPixels) CSSPixels {
	available := extent.minus(start).minus(end)
	free := available.minus(outer_size)
	starts_low := absolute_axis_starts_low(containing, horizontal)
	mut low := starts_low
	mut center := false
	match alignment.position {
		'center' { center = true }
		'end', 'flex-end', 'flow-end' { low = !starts_low }
		'self-start' { low = absolute_axis_starts_low(box, horizontal) }
		'self-end' { low = !absolute_axis_starts_low(box, horizontal) }
		'left' { low = true }
		'right' { low = false }
		else {}
	}
	if alignment.overflow == 'safe' && free.raw_value() < 0 {
		low = starts_low
		center = false
	}
	mut offset := start.plus(if center { free.divided_by_float(2) } else if low { CSSPixels.new(0) } else { free })
	// Default overflow alignment allows crossing an inset, but shifts back into
	// the union of the inset-modified and original containing blocks when possible.
	if alignment.overflow == '' && free.raw_value() < 0 {
		low_edge := css_pixels_min(CSSPixels.new(0), start)
		high_edge := css_pixels_max(extent, extent.minus(end))
		if outer_size.raw_value() <= high_edge.minus(low_edge).raw_value() {
			offset = css_pixels_max(low_edge, css_pixels_min(offset, high_edge.minus(outer_size)))
		} else {
			offset = if starts_low { low_edge } else { high_edge.minus(outer_size) }
		}
	}
	return offset
}

fn absolute_anchor_center_offset(anchor_start CSSPixels, anchor_extent CSSPixels,
	containing_start CSSPixels, containing_extent CSSPixels, start CSSPixels, end CSSPixels,
	outer_size CSSPixels) CSSPixels {
	centered := anchor_start.plus(anchor_extent.minus(outer_size).divided_by_float(2))
	low := containing_start.plus(start)
	high := containing_start.plus(containing_extent).minus(end).minus(outer_size)
	return css_pixels_max(low, css_pixels_min(centered, css_pixels_max(low, high)))
}
