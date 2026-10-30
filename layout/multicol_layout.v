module layout

// CSS Multi-column Layout for a multi-column container whose content is one
// inline formatting context. The lines are laid out at the used column width,
// then distributed over the columns at the smallest block size that holds
// them, and each line moves into its column.
// https://drafts.csswg.org/css-multicol/#cf
//
// Fragmentation is enabled under the Chromium policy; LibWeb does not fragment
// columns yet. multicol_blocks.v also handles atomic block children, including
// their intrinsic height at a definite inline size. Floats, vertical writing
// modes and intrinsic width measurements keep a single column.

// The initial values of orphans and widows (CSS Fragmentation 3 §5.2).
const multicol_orphans = 2
const multicol_widows = 2

struct MulticolColumns {
	count int
	width CSSPixels
	gap   CSSPixels
}

fn multicol_columns_for_content(box &Node, box_state &UsedValues, layout_mode LayoutMode) ?MulticolColumns {
	if layout_mode != .normal || box.computed_values().writing_mode() != .horizontal_tb
		|| box.document().font_rendering_policy() != .chromium {
		return none
	}
	available := box_state.content_width()
	count := determine_used_multicol_column_count(box, available) or { return none }
	if count < 2 {
		return none
	}
	return MulticolColumns{
		count: count
		width: determine_used_multicol_column_width(box, available, count)
		gap: multicol_column_gap(box, available)
	}
}

struct MulticolLineBreaks {
	// The first line of each column.
	starts     []int
	block_size CSSPixels
}

// Fill columns of `block_size` in order, breaking before the line that does
// not fit. A break that leaves fewer than the orphans in its column or fewer
// than the widows after it moves to the last earlier break that does not
// (LayoutNG prefers the latest break with the best appeal). Returns the
// breaks, whether the lines fit in `column_count` columns, and the smallest
// extra block size that would let a column take its next line.
fn fill_multicol_lines(tops []CSSPixels, bottoms []CSSPixels, column_count int, block_size CSSPixels) ([]int, bool, CSSPixels) {
	line_count := tops.len
	mut starts := [0]
	mut shortage := CSSPixels.max()
	mut column_start := 0
	for {
		start_top := tops[column_start]
		mut end := column_start
		for end < line_count && bottoms[end].minus(start_top).raw_value() <= block_size.raw_value() {
			end++
		}
		if end == line_count {
			break
		}
		needed := bottoms[end].minus(start_top).minus(block_size)
		if needed.raw_value() < shortage.raw_value() {
			shortage = needed
		}
		if end == column_start {
			// A line taller than the column still occupies a column of its own.
			end = column_start + 1
			if end == line_count {
				break
			}
		}
		mut next := end
		for next > column_start + 1 && !(next - column_start >= multicol_orphans
			&& line_count - next >= multicol_widows) {
			next--
		}
		if !(next - column_start >= multicol_orphans && line_count - next >= multicol_widows) {
			next = end
		}
		starts << next
		column_start = next
		if starts.len > column_count {
			return starts, false, shortage
		}
	}
	return starts, true, shortage
}

// Column balancing: start from an even share of the content (or its tallest
// line) and grow by the minimal space shortage until every line fits.
fn balance_multicol_lines(tops []CSSPixels, bottoms []CSSPixels, column_count int) MulticolLineBreaks {
	line_count := tops.len
	mut block_size := CSSPixels.from_raw(bottoms[line_count - 1].minus(tops[0]).raw_value() / column_count)
	for index in 0 .. line_count {
		height := bottoms[index].minus(tops[index])
		if height.raw_value() > block_size.raw_value() {
			block_size = height
		}
	}
	for _ in 0 .. line_count + 1 {
		starts, fits, shortage := fill_multicol_lines(tops, bottoms, column_count, block_size)
		if fits || shortage.raw_value() <= 0 || shortage == CSSPixels.max() {
			return MulticolLineBreaks{
				starts: starts
				block_size: block_size
			}
		}
		block_size = block_size.plus(shortage)
	}
	starts, _, _ := fill_multicol_lines(tops, bottoms, column_count, block_size)
	return MulticolLineBreaks{
		starts: starts
		block_size: block_size
	}
}

// Moves each line of `box_state` into its column and returns the balanced
// column block size. Lines were laid out at the column width from x = 0.
fn distribute_lines_into_columns(mut state LayoutState, box &Node, mut box_state UsedValues, columns MulticolColumns, container_width CSSPixels) ?CSSPixels {
	line_count := box_state.line_boxes.len
	if line_count == 0 {
		return none
	}
	box_state.ensure_mutable_line_boxes()
	mut tops := []CSSPixels{cap: line_count}
	mut bottoms := []CSSPixels{cap: line_count}
	for line in box_state.line_boxes {
		tops << line.bottom().minus(line.height())
		bottoms << line.bottom()
	}
	breaks := balance_multicol_lines(tops, bottoms, columns.count)
	rtl := box.computed_values().direction() == .rtl
	pitch := columns.width.plus(columns.gap)
	for column in 0 .. breaks.starts.len {
		first := breaks.starts[column]
		last := if column + 1 < breaks.starts.len { breaks.starts[column + 1] } else { line_count }
		mut dx := CSSPixels.new(0)
		for _ in 0 .. column {
			dx = dx.plus(pitch)
		}
		if rtl {
			dx = container_width.minus(columns.width).minus(dx)
		}
		dy := tops[0].minus(tops[first])
		for index in first .. last {
			shift_line_box(mut state, mut box_state.line_boxes[index], dx, dy)
		}
	}
	return breaks.block_size
}

fn shift_line_box(mut state LayoutState, mut line LineBox, dx CSSPixels, dy CSSPixels) {
	line.bottom_ = line.bottom_.plus(dy)
	for index in 0 .. line.fragments_.len {
		line.fragments_[index].inline_offset_ = line.fragments_[index].inline_offset_.plus(dx)
		line.fragments_[index].block_offset_ = line.fragments_[index].block_offset_.plus(dy)
		fragment := line.fragments_[index]
		if fragment.layout_node_.is_inline_block() || fragment.layout_node_.is_list_item_marker_box() {
			if styled := fragment.layout_node_.as_node_with_style() {
				mut fragment_state := state.get_mutable(styled)
				fragment_state.set_content_offset(fragment.offset())
			}
		}
	}
	for index in 0 .. line.static_position_markers_.len {
		line.static_position_markers_[index].inline_offset = line.static_position_markers_[index].inline_offset.plus(dx)
		line.static_position_markers_[index].block_offset = line.static_position_markers_[index].block_offset.plus(dy)
	}
}
