module layout

// CSS Align 3, content distribution for ordinary horizontal block containers.
// Apply after final sizing, before positioned descendants and relative insets.
// Flex/grid/table/multicol contexts retain their own alignment algorithms.
fn align_block_contents(mut state LayoutState, root &Node) {
	if !root.is_block_container()
		|| (!root.display().is_flow_inside() && !root.display().is_flow_root_inside())
		|| root.is_replaced_box() || root.is_viewport() || root.is_table_wrapper()
		|| root.computed_values().writing_mode() != .horizontal_tb
		|| root.computed_values().establishes_multi_column_container() {
		return
	}
	align := root.computed_values().align_content()
	if align !in [.center, .end_, .flex_end, .space_around, .space_evenly] { return }
	styled := root.as_node_with_style() or { return }
	mut values := state.get_mutable(styled)
	mut extent := CSSPixels.new(0)
	if values.line_boxes.len > 0 {
		extent = values.line_boxes.last().bottom()
	} else {
		for child in root.children() {
			if child.is_absolutely_positioned() { continue }
			child_style := child.as_node_with_style() or { continue }
			child_values := state.try_get(child_style) or { continue }
			if child_values.is_invisible_for_line_clamp() { continue }
			extent = css_pixels_max(extent, child_values.offset.y()
				.plus(child_values.content_height()).plus(child_values.margin_box_bottom()))
		}
	}
	// Floats inside ordinary descendants still belong to this formatting
	// context, even when those descendants' automatic heights exclude them.
	extent = css_pixels_max(extent, block_alignment_float_bottom(state, root,
		values.cumulative_offset().y()))
	// Default overflow alignment for blocks is safe: overflowing content stays
	// at block-start. Distributed values align the whole contents as one unit.
	free_space := values.content_height().minus(extent)
	if free_space.raw_value() <= 0 { return }
	delta := if align in [.end_, .flex_end] { free_space } else { free_space.divided_by_float(2) }
	for index in 0 .. values.line_boxes.len {
		shift_line_box(mut state, mut values.line_boxes[index], CSSPixels.new(0), delta)
		for fragment in values.line_boxes[index].fragments_ {
			if fragment.layout_node_.is_replaced_box() && !fragment.layout_node_.is_inline_block() {
				if image_style := fragment.layout_node_.as_node_with_style() {
					mut image_values := state.get_mutable(image_style)
					image_values.set_content_offset(fragment.offset())
				}
			}
		}
	}
	for child in root.children() {
		child_style := child.as_node_with_style() or { continue }
		mut child_values := state.get_mutable(child_style)
		if child.is_absolutely_positioned() {
			if rare := child_values.rare_ {
				if position := rare.static_position_rect_ {
					mut shifted := position
					shifted.rect.y = shifted.rect.y.plus(delta)
					child_values.set_static_position_rect(shifted)
				}
			}
		} else if values.line_boxes.len == 0 || child.is_floating() {
			child_values.set_content_y(child_values.offset.y().plus(delta))
		}
	}
}

fn block_alignment_float_bottom(state &LayoutState, root &Node, origin CSSPixels) CSSPixels {
	mut bottom := CSSPixels.new(0)
	for child in root.children() {
		if child.is_absolutely_positioned() { continue }
		styled := child.as_node_with_style() or { continue }
		values := state.try_get(styled) or { continue }
		if child.is_floating() {
			bottom = css_pixels_max(bottom, values.cumulative_offset().y().minus(origin)
				.plus(values.content_height()).plus(values.margin_box_bottom()))
		}
		if !creates_block_formatting_context(styled) {
			bottom = css_pixels_max(bottom, block_alignment_float_bottom(state, child, origin))
		}
	}
	return bottom
}
