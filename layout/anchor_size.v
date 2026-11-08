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
	if value is css.CalculatedStyleValue {
		containing := box.containing_block() or { return none }
		context := AnchorInsetCalculationContext{state:state, box:box, containing_box:unsafe { &Node(containing) },
			containing_state:containing_state, containing_extent:basis, is_horizontal_axis:horizontal}
		length_context := layout_length_resolution_context(box)
		resolved := value.resolve_length(css.CalculationResolutionContext{
			percentage_basis:css.Length.make_css_px(basis), length_resolution_context:length_context,
			anchor_size_resolver:resolve_anchor_size_for_calculation, anchor_resolver_context:voidptr(&context)
		}) or { return none }
		return CSSPixels.truncated_value_for(resolved.to_px_without_rounding(length_context))
	}
	return resolve_layout_size(box, css.Size.from_style_value(value), basis)
}

fn resolve_anchor_size_for_calculation(pointer voidptr, anchor css.AnchorSizeStyleValue) ?css.CSSPixels {
	context := unsafe { &AnchorInsetCalculationContext(pointer) }
	return resolve_anchor_size_value(context.state,context.box,context.containing_state,css.StyleValue(anchor),context.containing_extent,context.is_horizontal_axis)
}

fn absolute_anchor_size_property(state &LayoutState, box &Node, containing_state &UsedValues,
	property css.PropertyID, basis CSSPixels, horizontal bool) ?CSSPixels {
	value := unsafe { &css.ComputedProperties(box.computed_values()) }.typed_property_value(property) or { return none }
	if value !is css.AnchorSizeStyleValue && value !is css.CalculatedStyleValue { return none }
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
