module layout

// An auto-height, balanced multicol may break between block children that
// request break-inside:avoid. Lay out their contents at the column width,
// retain each complete box, and discard adjoining margins at column breaks.
// https://drafts.csswg.org/css-break/#adjoining-margins
fn multicol_atomic_child_supported(node &Node) bool {
	if node.is_floating() || node.is_absolutely_positioned() { return false }
	for child in node.children() {
		if !multicol_atomic_child_supported(child) { return false }
	}
	return true
}

fn fill_multicol_blocks(tops []CSSPixels, bottoms []CSSPixels, count int,
	height CSSPixels) ([]int, bool, CSSPixels) {
	mut starts := [0]
	mut shortage := CSSPixels.max()
	mut first := 0
	for {
		origin := if first == 0 { CSSPixels.new(0) } else { tops[first] }
		mut end := first
		for end < tops.len && bottoms[end].minus(origin).raw_value() <= height.raw_value() {
			end++
		}
		if end == tops.len { return starts, true, shortage }
		needed := bottoms[end].minus(origin).minus(height)
		shortage = css_pixels_min(shortage, needed)
		if end == first { return starts, false, shortage }
		starts << end
		if starts.len > count { return starts, false, shortage }
		first = end
	}
	return starts, true, shortage
}

fn balance_multicol_blocks(tops []CSSPixels, bottoms []CSSPixels, flow_height CSSPixels,
	count int) MulticolLineBreaks {
	mut height := CSSPixels.from_raw(flow_height.raw_value() / count)
	for index in 0 .. tops.len {
		height = css_pixels_max(height, bottoms[index].minus(tops[index]))
	}
	for _ in 0 .. tops.len + 1 {
		starts, fits, shortage := fill_multicol_blocks(tops, bottoms, count, height)
		if fits || shortage.raw_value() <= 0 || shortage == CSSPixels.max() {
			return MulticolLineBreaks{ starts: starts, block_size: height }
		}
		height = height.plus(shortage)
	}
	starts, _, _ := fill_multicol_blocks(tops, bottoms, count, height)
	return MulticolLineBreaks{ starts: starts, block_size: height }
}

fn layout_multicol_atomic_blocks(mut state LayoutState, box &Node, mut box_state UsedValues,
	mode LayoutMode, available AvailableSpace) ?FormattingContextResult {
	// A grid row measures its block item's height at a definite inline size.
	// That measurement must balance the columns too, rather than contributing
	// the height of the unfragmented list to the ancestor row.
	height_measurement := mode == .intrinsic_sizing && available.width.is_definite()
	columns := multicol_columns_for_content(box, box_state, if height_measurement {
		.normal
	} else {
		mode
	}) or { return none }
	computed := box.computed_values()
	// The measurement's available height can be definite even when the
	// authored multicol height is auto. It must still contribute its balanced
	// content height, rather than reuse a tentative grid-area height.
	if !computed.size_value(.height).is_auto()
		|| computed.column_fill() !in [.balance, .balance_all] {
		return none
	}
	mut children := []&Node{}
	for child in box.children() {
		if child.is_list_item_marker_box() { continue }
		if child.as_node_with_style() == none { return none }
		values := child.computed_values()
		if values.white_space_collapse() == .collapse && can_skip_anonymous_text_run(child) {
			continue
		}
		if !multicol_atomic_child_supported(child)
			|| (child.has_children() && !box_has_inline_content(child))
			|| values.break_before() != .auto || values.break_after() != .auto
			|| values.column_span() != .none_ {
			return none
		}
		children << child
	}
	if children.len == 0 { return none }
	styled := box.as_node_with_style() or { return none }
	container_width := box_state.content_width()
	box_state.set_content_width(columns.width)
	mut context := BlockFormattingContext.for_root(box, mode, box_state.has_definite_width())
	context.layout_marker_of_list_item_root(mut state, box, mut box_state)
	flow_height := context.layout_block_level_children(mut state, styled, columns.width.to_double(), none)
	box_state.set_content_width(container_width)
	mut tops := []CSSPixels{cap: children.len}
	mut bottoms := []CSSPixels{cap: children.len}
	for child in children {
		child_styled := child.as_node_with_style() or { return none }
		values := state.get(child_styled)
  // An ordinary block with a single line has no internal break point.
  // Multi-line blocks still need full fragmentation and keep the fallback.
  if children[tops.len].computed_values().break_inside() !in [.avoid,.avoid_column] && values.line_boxes.len>1 { return none }
		// Overlapping blocks need more than a sequence of atomic fragments.
		// The ordinary block pass will rerun at the full width on fallback.
		if values.margin_top.raw_value() < 0 || values.margin_bottom.raw_value() < 0 {
			return none
		}
		tops << values.offset.y().minus(values.border_box_top())
		bottoms << values.offset.y().plus(values.content_height()).plus(values.border_box_bottom())
	}
	breaks := balance_multicol_blocks(tops, bottoms, css_px(flow_height), columns.count)
	pitch := columns.width.plus(columns.gap)
	for column, first in breaks.starts {
		last := if column + 1 < breaks.starts.len {
			breaks.starts[column + 1]
		} else {
			children.len
		}
		mut dx := pitch.scaled(f64(column))
		if computed.direction() == .rtl { dx = container_width.minus(columns.width).minus(dx) }
		dy := if column == 0 { CSSPixels.new(0) } else { CSSPixels.new(0).minus(tops[first]) }
		for index in first .. last {
			child := children[index].as_node_with_style() or { continue }
			mut values := state.get_mutable(child)
			values.set_content_x(values.offset.x().plus(dx))
			values.set_content_y(values.offset.y().plus(dy))
		}
	}
	place_list_item_marker_at_first_baseline(mut state, box)
	return FormattingContextResult{
		automatic_content_width:  container_width
		automatic_content_height: breaks.block_size
	}
}
