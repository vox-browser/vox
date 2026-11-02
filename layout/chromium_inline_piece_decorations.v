module layout

import css
import painting

// Blink paints an inline box's background, borders, shadow and outline over
// the box fragment it generates on each line, which spans its nested inline
// boxes too. The compatibility painter joins only the text fragments a box
// directly parents, so under the Chromium policy a decorated box that contains
// nested inline boxes on a line paints from its inline box piece instead.

fn inline_box_paints_decorations(node &Node, used &UsedValues) bool {
	style := node.computed_values()
	return used.border_left.raw_value() != 0 || used.border_right.raw_value() != 0
		|| used.border_top.raw_value() != 0 || used.border_bottom.raw_value() != 0
		|| style.background_color().a != 0
		|| style.background_layers().any(it.image != '' && it.image != 'none')
		|| style.box_shadow().len > 0 || style.outline_style() != .none_
}

// Text paints its nearest inline owner's decoration from the text fragment.
// Atomic inlines have no such text fragment, so include their nearest owner.
fn nested_decorated_inline_ancestors(fragment_node &Node, state &LayoutState) []&Node {
	mut result := []&Node{}
	mut ancestor := fragment_node.parent()
	mut is_nearest := !fragment_node.is_atomic_inline()
	for ancestor != none {
		current := ancestor or { break }
		if !current.is_inline_node() || current.is_atomic_inline() {
			break
		}
		if !is_nearest {
			if styled := current.as_node_with_style() {
				if used := state.try_get(styled) {
					if inline_box_paints_decorations(current, used) {
						result << current
					}
				}
			}
		}
		is_nearest = false
		ancestor = current.parent()
	}
	return result
}

fn inline_piece_decoration_fragment(piece InlineBoxPiece, container_position css.CSSPixelPoint, state &LayoutState) ?TextFragment {
	node := piece.node
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	owner := painted_owner_element(node) or { return none }
	computed := node.computed_values()
	mut color_context := color_resolution_context_for_typed_node(node, computed.color())
	color_context.current_color = computed.color()
	own_relative := if computed.position() == .relative {
		css.CSSPixelPoint.from_values(used.inset_left.to_double(), used.inset_top.to_double())
	} else {
		css.CSSPixelPoint.from_values(0, 0)
	}
	origin := css_pixel_point_add(css_pixel_point_add(container_position, own_relative),
		inline_relative_offset(node, state))
	border_x := origin.x().plus(piece.border_box_rect.x).to_double()
	border_y := origin.y().plus(piece.border_box_rect.y).to_double()
	border := BoxEdges{used.border_top.to_double(), used.border_right.to_double(), used.border_bottom.to_double(), used.border_left.to_double()}
	low_padding := if piece.has_low_edge { used.padding_left.to_double() } else { 0.0 }
	high_padding := if piece.has_high_edge { used.padding_right.to_double() } else { 0.0 }
	low_border := if piece.has_low_edge { border.left } else { 0.0 }
	high_border := if piece.has_high_edge { border.right } else { 0.0 }
	padding := BoxEdges{used.padding_top.to_double(), high_padding, used.padding_bottom.to_double(), low_padding}
	border_width := piece.border_box_rect.width.to_double()
	border_height := piece.border_box_rect.height.to_double()
	border_colors := computed_border_colors(computed)
	radii := paintable_box_border_radii_data(computed, piece.border_box_rect.width,
		piece.border_box_rect.height)
	shadows := computed_box_shadows(node, computed)
	mut outline_width := 0.0
	mut outline_style := painting.LineStyle.none
	mut outline_color := css.Color{}
	if outline := paintable_box_outline_data(computed) {
		outline_width = outline.top.width
		outline_style = outline.top.line_style
		outline_color = css.Color{outline.top.color.r, outline.top.color.g, outline.top.color.b, outline.top.color.a}
	}
	outline_offset_value := computed.typed_property_value(.outline_offset) or {
		css.StyleValue(css.LengthStyleValue.create(css.Length.make_px(0)))
	}
	return TextFragment{
		x: border_x + low_border + low_padding
		y: border_y + border.top + padding.top
		width: border_width - low_border - low_padding - high_border - high_padding
		height: border_height - border.top - padding.top - border.bottom - padding.bottom
		inline_node_id: i64(owner.as_node().unique_id())
		fragment_left_edge_away: !piece.has_low_edge
		fragment_right_edge_away: !piece.has_high_edge
		background_color: computed_paint_color(computed, .background_color, color_context, css.Color{})
		background_color_clip: background_box_name(computed.background_color_clip())
		background_images: computed_background_image_layers(node, owner, computed, color_context)
		border: border
		padding: padding
		border_color: border_colors.top
		border_colors: border_colors
		border_styles: computed_border_styles(computed)
		border_radius: radii.top_left.x
		border_radii: radii
		outline_width: outline_width
		outline_offset: computed.resolve_length_percentage_value_px(outline_offset_value, 0) or { 0.0 }
		outline_color: outline_color
		outline_style: outline_style
		outline_is_auto: computed.outline_style() == .auto_
		shadow: if shadows.len > 0 { ?BoxShadow(shadows[0]) } else { none }
		shadows: shadows
		chromium_decorations: true
	}
}
