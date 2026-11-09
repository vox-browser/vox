module layout

import css

// Physical box sizes remain physical; vertical writing changes the normal
// block progression and the inline-start edge used to place each child.
fn layout_vertical_block_children(mut state LayoutState, container &NodeWithStyle, content_width f64, available_height ?f64, mode LayoutMode) f64 {
	root := unsafe { &Node(container) }
	mut used := state.get_mutable(container)
	mut intrinsic_inline_extent := CSSPixels.new(0)
	reverse_block := container.computed_values().writing_mode() in [.vertical_rl,.sideways_rl]
	reverse_inline := !absolute_axis_starts_low(root,false)
 physical_block_measurement := mode == .intrinsic_sizing && used.width_constraint in [.min_content,.max_content]
 mut context := BlockFormattingContext.for_root(root,mode,has_definite_inline_size(root,used) || physical_block_measurement)
 mut natural_block_extent := CSSPixels.new(0)
	for child in root.children() {
		if child.as_box() == none || child.is_absolutely_positioned() { continue }
		styled := child.as_node_with_style() or { continue }
		context.laying_out_invisible_clamped_content = context.line_clamp_reached()
		_ = context.layout_block_level_box(mut state,styled,container,content_width,available_height)
		mut child_values := state.get_mutable(styled)
		computed := styled.computed_values()
		// The horizontal block algorithm may distribute horizontal underflow.
		// Vertical blocks instead align and stretch on the physical y axis.
		child_values.margin_left = css_px(computed.length_percentage_to_px(.margin_left,content_width) or { 0.0 })
		child_values.margin_right = css_px(computed.length_percentage_to_px(.margin_right,content_width) or { 0.0 })
		child_values.margin_top = css_px(computed.length_percentage_to_px(.margin_top,content_width) or { 0.0 })
		child_values.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom,content_width) or { 0.0 })
		if vertical_block_is_discarded_whitespace(child) {
			child_values.set_content_width(CSSPixels.new(0))
			child_values.set_content_height(CSSPixels.new(0))
		}
  if context.has_line_clamp() && property_is_auto(computed,.width) && child_values.line_boxes.len > 0 {
   mut extent := CSSPixels.new(0)
   for line in child_values.line_boxes { extent = css_pixels_max(extent,line.bottom_) }
   child_values.set_content_width(clamp_layout_content_size(child,extent,css_px(content_width),child_values,true))
  }
  if !child_values.is_invisible_for_line_clamp() { natural_block_extent = natural_block_extent.plus(child_values.margin_box_width()) }
		intrinsic_inline_extent = css_pixels_max(intrinsic_inline_extent,child_values.margin_box_height())
	}
 resolved_width := if physical_block_measurement && property_is_auto(container.computed_values(),.width) { natural_block_extent } else { css_px(content_width) }
 if physical_block_measurement { used.set_content_width(resolved_width) }
	height := if value := available_height { css_px(value) } else { intrinsic_inline_extent }
	mut cursor := CSSPixels.new(0)
	mut bottom := CSSPixels.new(0)
	for child in root.children() {
		// Inter-block whitespace text does not generate a block box.
		if child.as_box() == none { continue }
		styled := child.as_node_with_style() or { continue }
		mut child_values := state.get_mutable(styled)
		if child.is_absolutely_positioned() {
			child_values.set_containing_block_used_values(used)
			child_values.set_static_position_rect(StaticPositionRect{rect:css.CSSPixelRect{
				x:if reverse_block { resolved_width.minus(cursor) } else { cursor },height:height}})
			continue
		}
		if child_values.is_invisible_for_line_clamp() { continue }
		x := if reverse_block { resolved_width.minus(cursor).minus(child_values.margin_box_right()).minus(child_values.content_width()) }
			else { cursor.plus(child_values.margin_box_left()) }
		y := if reverse_inline { height.minus(child_values.margin_box_bottom()).minus(child_values.content_height()) }
			else { child_values.margin_box_top() }
		child_values.set_content_offset(css.CSSPixelPoint.new(x,y))
		cursor = cursor.plus(child_values.margin_box_width())
		bottom = css_pixels_max(bottom,y.plus(child_values.content_height()).plus(child_values.margin_box_bottom()))
	}
	return bottom.to_double()
}

fn vertical_block_is_discarded_whitespace(node &Node) bool {
	if !node.is_anonymous() { return false }
	for child in node.children() {
		if child.is_out_of_flow() { continue }
		if text := child.as_text_node() {
			if child.computed_values().white_space_collapse() == .collapse && text.text_for_rendering().trim_space() == '' { continue }
		}
		return false
	}
	return true
}
