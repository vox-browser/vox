module layout

import css

struct PositionAreaRange {
	first int
	last int
}

fn position_area_axis(word string, container &Node, subject &Node) ?bool {
	base := word.trim_string_left('span-')
	owner := if base.starts_with('self-') { subject } else { container }
	name := base.trim_string_left('self-')
	if name in ['left', 'right', 'x-start', 'x-end'] { return true }
	if name in ['top', 'bottom', 'y-start', 'y-end'] { return false }
	if name.starts_with('inline-') { return owner.computed_values().writing_mode() == .horizontal_tb }
	if name.starts_with('block-') { return owner.computed_values().writing_mode() != .horizontal_tb }
	return none
}

fn position_area_range(word string, horizontal bool, container &Node, subject &Node) PositionAreaRange {
	span := word.starts_with('span-')
	base := word.trim_string_left('span-')
	owner := if base.starts_with('self-') { subject } else { container }
	name := base.trim_string_left('self-')
	mut first := 1
	mut last := 1
	if name == 'all' { first = 0; last = 2 }
	else if name in ['left', 'top', 'start'] || name.ends_with('-start') {
		first = 0; last = if span { 1 } else { 0 }
	} else if name in ['right', 'bottom', 'end'] || name.ends_with('-end') {
		first = if span { 1 } else { 2 }; last = 2
	}
	physical := name in ['left', 'right', 'top', 'bottom']
	if !physical && !absolute_axis_starts_low(owner, horizontal) {
		return PositionAreaRange{2 - last, 2 - first}
	}
	return PositionAreaRange{first, last}
}

// abspos_engine.rs resolve_position_area_tracks(): ambiguous single values
// repeat; a single axis-specific value gets span-all on the other axis.
fn position_area_tracks(text string, container &Node, subject &Node) ?(PositionAreaRange, PositionAreaRange) {
	mut words := text.split(' ')
	if words.len == 0 || text == 'none' { return none }
	if words.len == 1 {
		words << if position_area_axis(words[0], container, subject) != none { 'span-all' } else { words[0] }
	}
	if words.len != 2 { return none }
	first_axis := position_area_axis(words[0], container, subject)
	second_axis := position_area_axis(words[1], container, subject)
	owner := if words[0].contains('self-') { subject } else { container }
	first_horizontal := first_axis or { if other := second_axis { !other } else { owner.computed_values().writing_mode() != .horizontal_tb } }
	first := position_area_range(words[0], first_horizontal, container, subject)
	second := position_area_range(words[1], !first_horizontal, container, subject)
	return if first_horizontal { first, second } else { second, first }
}

fn resolved_position_area(state &LayoutState, box &Node, containing_state &UsedValues, computed &css.ComputedValues, original css.CSSPixelRect) ?SpanAllPositionArea {
	value := unsafe { &css.ComputedProperties(computed) }.property(.position_area, .yes) or { return none }
	containing := box.containing_block() or { return none }
	x_tracks, y_tracks := position_area_tracks(value.css_text, unsafe { &Node(containing) }, box) or { return none }
	name := computed.position_anchor() or { return none }
	padding_anchor := resolve_named_anchor_rect(state, box, containing_state, name) or { return none }
	anchor := css.CSSPixelRect{ x: padding_anchor.x.minus(containing_state.padding_left),
		y: padding_anchor.y.minus(containing_state.padding_top), width: padding_anchor.width, height: padding_anchor.height }
	x_lines := [css_pixels_min(original.left(), anchor.left()), anchor.left(), anchor.right(), css_pixels_max(original.right(), anchor.right())]
	y_lines := [css_pixels_min(original.top(), anchor.top()), anchor.top(), anchor.bottom(), css_pixels_max(original.bottom(), anchor.bottom())]
	return SpanAllPositionArea{rect: css.CSSPixelRect{x:x_lines[x_tracks.first], y:y_lines[y_tracks.first],
		width:x_lines[x_tracks.last+1].minus(x_lines[x_tracks.first]), height:y_lines[y_tracks.last+1].minus(y_lines[y_tracks.first])},
		anchor_rect:anchor, x_tracks:x_tracks, y_tracks:y_tracks}
}

fn position_area_alignment(alignment AbsoluteSelfAlignment, tracks PositionAreaRange) AbsoluteSelfAlignment {
	if alignment.position !in ['auto', 'normal'] { return alignment }
	position := if tracks.first == 1 && tracks.last == 1 { 'center' }
		else if tracks.first == 0 && tracks.last == 2 { 'anchor-center' }
		else if tracks.first == 0 { 'right' } else { 'left' }
	return AbsoluteSelfAlignment{position:position}
}

fn position_area_default_overflow_offset(offset CSSPixels, margin CSSPixels, size CSSPixels, original_start CSSPixels, original_extent CSSPixels, area_start CSSPixels, area_extent CSSPixels, starts_low bool) CSSPixels {
	if size.raw_value() <= area_extent.raw_value() { return offset }
	low := css_pixels_min(original_start,area_start)
	high := css_pixels_max(original_start.plus(original_extent),area_start.plus(area_extent))
	if size.raw_value() > high.minus(low).raw_value() { return (if starts_low { low } else { high.minus(size) }).plus(margin) }
	return css_pixels_max(low,css_pixels_min(offset.minus(margin),high.minus(size))).plus(margin)
}
