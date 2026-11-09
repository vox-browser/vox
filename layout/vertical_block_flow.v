module layout

import css

// Physical box sizes remain physical; vertical writing changes the normal
// block progression and the inline-start edge used to place each child.
fn layout_vertical_block_children(mut state LayoutState, container &NodeWithStyle, content_width f64, available_height ?f64, mode LayoutMode) f64 {
	root := unsafe { &Node(container) }
	mut used := state.get_mutable(container)
	height := css_px(available_height or { used.content_height().to_double() })
	reverse_block := container.computed_values().writing_mode() in [.vertical_rl,.sideways_rl]
	reverse_inline := !absolute_axis_starts_low(root,false)
	mut cursor := CSSPixels.new(0)
	mut bottom := CSSPixels.new(0)
	for child in root.children() {
		styled := child.as_node_with_style() or { continue }
		if child.is_absolutely_positioned() {
			mut child_values := state.get_mutable(styled)
			child_values.set_containing_block_used_values(used)
			child_values.set_static_position_rect(StaticPositionRect{rect:css.CSSPixelRect{
				x:if reverse_block { css_px(content_width).minus(cursor) } else { cursor },height:height}})
			continue
		}
		mut context := BlockFormattingContext.for_root(root,mode,used.has_definite_width())
		_ = context.layout_block_level_box(mut state,styled,container,content_width,available_height)
		mut child_values := state.get_mutable(styled)
		computed := styled.computed_values()
		// The horizontal block algorithm may distribute horizontal underflow.
		// Vertical blocks instead align and stretch on the physical y axis.
		child_values.margin_left = css_px(computed.length_percentage_to_px(.margin_left,content_width) or { 0.0 })
		child_values.margin_right = css_px(computed.length_percentage_to_px(.margin_right,content_width) or { 0.0 })
		child_values.margin_top = css_px(computed.length_percentage_to_px(.margin_top,content_width) or { 0.0 })
		child_values.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom,content_width) or { 0.0 })
		x := if reverse_block { css_px(content_width).minus(cursor).minus(child_values.margin_box_right()).minus(child_values.content_width()) }
			else { cursor.plus(child_values.margin_box_left()) }
		y := if reverse_inline { height.minus(child_values.margin_box_bottom()).minus(child_values.content_height()) }
			else { child_values.margin_box_top() }
		child_values.set_content_offset(css.CSSPixelPoint.new(x,y))
		cursor = cursor.plus(child_values.margin_box_width())
		bottom = css_pixels_max(bottom,y.plus(child_values.content_height()).plus(child_values.margin_box_bottom()))
	}
	return bottom.to_double()
}
