module layout

import css

// CSS Sizing: stretch fits the margin box, regardless of box-sizing. Auto
// margins contribute zero; computed margins are used before margin collapse.
fn stretch_fit_content_size(node &Node, used &UsedValues, available CSSPixels, width bool) CSSPixels {
	computed := node.computed_values()
	mut space := available
	if node.is_absolutely_positioned() {
		for side in if width { [css.PropertyID.left, .right] } else { [css.PropertyID.top, .bottom] } {
			space = space.minus(css_px(computed.length_percentage_to_px(side, available.to_double()) or { 0 }))
		}
	}
	start := if width { css.PropertyID.margin_left } else { css.PropertyID.margin_top }
	end := if width { css.PropertyID.margin_right } else { css.PropertyID.margin_bottom }
	mut first := if width { used.margin_left } else { used.margin_top }
	mut last := if width { used.margin_right } else { used.margin_bottom }
	if containing := used.containing_block_used_values_ {
		basis := containing.content_width().to_double()
		first = css_px(computed.length_percentage_to_px(start, basis) or { 0 })
		last = css_px(computed.length_percentage_to_px(end, basis) or { 0 })
	}
	if property_is_auto(computed, start) { first = CSSPixels.new(0) }
	if property_is_auto(computed, end) { last = CSSPixels.new(0) }
	edges := if width {
		used.border_left.plus(used.padding_left).plus(used.padding_right).plus(used.border_right)
	} else {
		used.border_top.plus(used.padding_top).plus(used.padding_bottom).plus(used.border_bottom)
	}
	return css_pixels_max(CSSPixels.new(0), space.minus(first).minus(last).minus(edges))
}

fn replaced_stretch_fit_content_size(node &Node, available CSSPixels, model ReplacedBoxModel, width bool) CSSPixels {
	mut edges := UsedValues{}
	resolve_box_model_edges(node.computed_values(), mut edges, model.percentage_basis.to_double())
	return stretch_fit_content_size(node, edges, available, width)
}
