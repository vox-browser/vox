module layout

import css

fn resolved_anchor_size_style_value(state &LayoutState, node &Node, containing &UsedValues, value css.StyleValue, basis CSSPixels, horizontal bool) ?css.StyleValue {
	if value is css.AnchorSizeStyleValue {
		name := value.anchor_name() or { node.computed_values().position_anchor() or { '' } }
		if node.is_absolutely_positioned() && name != '' {
			if _ := resolve_named_anchor_rect(state,node,containing,name) {
				if pixels := resolve_anchor_size_value(state,node,containing,value,basis,horizontal) {
					return css.StyleValue(css.LengthStyleValue.create(css.Length.make_css_px(pixels)))
				}
			}
		}
		fallback := value.fallback_value() or { return none }
		return resolved_anchor_size_style_value(state,node,containing,fallback,basis,horizontal)
	}
	if value is css.CalculatedStyleValue {
		pixels := resolve_anchor_size_value(state,node,containing,value,basis,horizontal) or { return none }
		return css.StyleValue(css.LengthStyleValue.create(css.Length.make_css_px(pixels)))
	}
	if value is css.AnchorStyleValue { return none }
	return value
}

fn layout_resolved_anchor_size_property(handle voidptr, name string) ?string {
	node := unsafe { &Node(handle) }
	property := css.property_id_from_string(name) or { return none }
	value := unsafe { &css.ComputedProperties(node.computed_values()) }.typed_property_value(property) or { return none }
	document := node.document()
	if document.layout_engine_handle() == unsafe { nil } { return none }
	result := unsafe { &DocumentLayoutResult(document.layout_engine_handle()) }
	styled := node.as_node_with_style() or { return none }
	used := result.state.try_get(styled) or { return none }
	containing := used.containing_block_used_values() or { return none }
	horizontal := property in [.min_width,.max_width]
	resolved := resolved_anchor_size_style_value(result.state,node,containing,value,if horizontal { containing.content_width() } else { containing.content_height() },horizontal) or { return none }
	return resolved.serialize(.resolved_value)
}
