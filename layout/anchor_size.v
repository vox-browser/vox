module layout

import css

fn resolve_anchor_size_value(state &LayoutState, box &Node, containing_state &UsedValues,
	value css.StyleValue, basis CSSPixels, horizontal bool) ?CSSPixels {
	if value is css.AnchorSizeStyleValue {
		name := value.anchor_name() or { box.computed_values().position_anchor() or { '' } }
		if name != '' {
			if rect := resolve_named_anchor_rect(state, box, containing_state, name) {
				containing := box.containing_block() or { return none }
				container_horizontal := containing.computed_values().writing_mode() == .horizontal_tb
				self_horizontal := box.computed_values().writing_mode() == .horizontal_tb
				width := if size := value.anchor_size() {
					match size {
						.width { true }
						.height { false }
						.inline_ { container_horizontal }
						.block { !container_horizontal }
						.self_inline { self_horizontal }
						.self_block { !self_horizontal }
					}
				} else { horizontal }
				return if width { rect.width } else { rect.height }
			}
		}
		fallback := value.fallback_value() or { return none }
		return resolve_anchor_size_value(state, box, containing_state, fallback, basis, horizontal)
	}
	return resolve_layout_size(box, css.Size.from_style_value(value), basis)
}

fn absolute_anchor_size_property(state &LayoutState, box &Node, containing_state &UsedValues,
	property css.PropertyID, basis CSSPixels, horizontal bool) ?CSSPixels {
	value := unsafe { &css.ComputedProperties(box.computed_values()) }.typed_property_value(property) or { return none }
	if value !is css.AnchorSizeStyleValue { return none }
	return resolve_anchor_size_value(state, box, containing_state, value, basis, horizontal)
}

fn resolve_absolute_content_size(state &LayoutState, box &Node, containing_state &UsedValues,
	property css.PropertyID, basis CSSPixels, used &UsedValues, horizontal bool) ?CSSPixels {
	if resolved := absolute_anchor_size_property(state, box, containing_state, property, basis, horizontal) {
		return resolve_layout_content_size(box, css.Size.make_px(resolved), basis, used, horizontal)
	}
	return resolve_layout_content_size(box, box.computed_values().size_value(property), basis, used, horizontal)
}

fn resolve_absolute_anchor_margins(state &LayoutState, box &Node, containing_state &UsedValues,
	mut used UsedValues, basis CSSPixels) {
	for property in [css.PropertyID.margin_left, .margin_right, .margin_top, .margin_bottom] {
		horizontal := property in [.margin_left, .margin_right]
		if value := absolute_anchor_size_property(state, box, containing_state, property, basis, horizontal) {
			match property {
				.margin_left { used.margin_left = value }
				.margin_right { used.margin_right = value }
				.margin_top { used.margin_top = value }
				.margin_bottom { used.margin_bottom = value }
				else {}
			}
		}
	}
}
