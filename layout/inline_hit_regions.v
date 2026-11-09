module layout

import css
import dom
import painting

pub struct InlineHitRegion {
pub:
	layout_handle voidptr
	rect          painting.Rect
	radii         painting.BorderRadiiData
}

fn inline_hit_regions_for_line(container &Node, used &UsedValues, state &LayoutState, pieces []InlineBoxPiece, line int, origin css.CSSPixelPoint) []InlineHitRegion {
	mut regions := []InlineHitRegion{}
	horizontal := container.computed_values().writing_mode() == .horizontal_tb
	for piece in pieces {
		if piece.line_index != line || piece.is_geometry_only_placeholder { continue }
		node := piece.node
		computed := node.computed_values()
		if computed.visibility() != .visible || computed.pointer_events() == .none_ || node.establishes_stacking_context() {
			continue
		}
		values := state.get(node.as_node_with_style() or { continue })
		own_relative := if computed.position() == .relative {
			css.CSSPixelPoint.new(values.inset_left, values.inset_top)
		} else {
			css.CSSPixelPoint.new(CSSPixels.new(0), CSSPixels.new(0))
		}
		position := css_pixel_point_add(css_pixel_point_add(origin, own_relative), inline_relative_offset(node, state))
		rect := painting.Rect{position.x().plus(piece.border_box_rect.x).to_double(), position.y().plus(piece.border_box_rect.y).to_double(), piece.border_box_rect.width.to_double(), piece.border_box_rect.height.to_double()}
		raw := paintable_box_border_radii_data(computed, piece.border_box_rect.width, piece.border_box_rect.height)
		cut_low := computed.box_decoration_break() == .slice && !piece.has_low_edge
		cut_high := computed.box_decoration_break() == .slice && !piece.has_high_edge
		radii := BoxRadii{
			top_left:     if cut_low { CornerRadius{} } else { raw.top_left }
			top_right:    if (horizontal && cut_high) || (!horizontal && cut_low) {
				CornerRadius{}
			} else {
				raw.top_right
			}
			bottom_right: if cut_high { CornerRadius{} } else { raw.bottom_right }
			bottom_left:  if (horizontal && cut_low) || (!horizontal && cut_high) {
				CornerRadius{}
			} else {
				raw.bottom_left
			}
		}
		regions << InlineHitRegion{
			layout_handle: voidptr(node)
			rect:          rect
			radii:         painting.BorderRadiiData{
				top_left:     painting.BorderRadiusData{radii.top_left.x, radii.top_left.y}
				top_right:    painting.BorderRadiusData{radii.top_right.x, radii.top_right.y}
				bottom_right: painting.BorderRadiusData{radii.bottom_right.x, radii.bottom_right.y}
				bottom_left:  painting.BorderRadiusData{radii.bottom_left.x, radii.bottom_left.y}
			}
		}
	}
	_ = used
	return regions
}

fn inline_client_piece_rects(node &Node, state &LayoutState) []dom.CSSPixelRect_ {
	containing := node.containing_block() or { return []dom.CSSPixelRect_{} }
	styled := unsafe { &Node(containing) }.as_node_with_style() or { return []dom.CSSPixelRect_{} }
	values := state.try_get(styled) or { return []dom.CSSPixelRect_{} }
	own := state.try_get(node.as_node_with_style() or { return []dom.CSSPixelRect_{} }) or { return []dom.CSSPixelRect_{} }
	position := paint_cumulative_offset(unsafe { &Node(containing) }, state, values)
	own_relative := if node.computed_values().position() == .relative {
		css.CSSPixelPoint.new(own.inset_left, own.inset_top)
	} else {
		css.CSSPixelPoint.new(CSSPixels.new(0), CSSPixels.new(0))
	}
	origin := css_pixel_point_add(css_pixel_point_add(position, own_relative), inline_relative_offset(node, state))
	mut result := []dom.CSSPixelRect_{}
	for piece in compute_inline_box_pieces(unsafe { &Node(containing) }, values, state) {
		if !layout_nodes_same(piece.node, node) || piece.is_geometry_only_placeholder { continue }
		rect := piece.border_box_rect
		result << dom.CSSPixelRect_{ x_: origin.x().plus(rect.x).to_double(), y_: origin.y().plus(rect.y).to_double(), width_: rect.width.to_double(), height_: rect.height.to_double() }
	}
	return result
}
