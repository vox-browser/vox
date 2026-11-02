module css

// Used edges stay in CSSPixels throughout layout. Resolving the complete box
// reads its typed style snapshot once and avoids a property dispatch and a
// fixed-point/double/fixed-point round trip for each individual side.
pub struct ResolvedBoxModelEdges {
pub:
	padding_left   CSSPixels
	padding_right  CSSPixels
	padding_top    CSSPixels
	padding_bottom CSSPixels
	border_left    CSSPixels
	border_right   CSSPixels
	border_top     CSSPixels
	border_bottom  CSSPixels
	margin_left    CSSPixels
	margin_right   CSSPixels
	margin_top     CSSPixels
	margin_bottom  CSSPixels
}

fn (values &ComputedValues) resolve_box_model_length(value LengthPercentageOrAuto, basis CSSPixels) CSSPixels {
	resolved := value.length_percentage_ or { return CSSPixels.new(0) }
	properties := unsafe { &ComputedProperties(values) }
	if resolved.is_length() {
		length := resolved.length()
		if length.is_absolute() { return properties.absolute_layout_length_to_px(length) }
	} else if resolved.is_percentage() {
		return resolved.to_px(LengthResolutionContext{}, basis)
	}
	// Relative units and calculations keep their live font, viewport and query
	// container context, exactly as the individual property accessor does.
	return resolved.to_px(properties.length_resolution_context(), basis)
}

pub fn (values &ComputedValues) resolved_box_model_edges(containing_block_width f64) ResolvedBoxModelEdges {
	cache := values.computed_layout_cache()
	padding := cache.computed_values_padding_
	margin := cache.computed_values_margin_
	basis := CSSPixels.nearest_value_for(containing_block_width)
	return ResolvedBoxModelEdges{
		padding_left:   values.resolve_box_model_length(padding.left(), basis)
		padding_right:  values.resolve_box_model_length(padding.right(), basis)
		padding_top:    values.resolve_box_model_length(padding.top(), basis)
		padding_bottom: values.resolve_box_model_length(padding.bottom(), basis)
		border_left:    cache.computed_values_border_left_.width
		border_right:   cache.computed_values_border_right_.width
		border_top:     cache.computed_values_border_top_.width
		border_bottom:  cache.computed_values_border_bottom_.width
		margin_left:    values.resolve_box_model_length(margin.left(), basis)
		margin_right:   values.resolve_box_model_length(margin.right(), basis)
		margin_top:     values.resolve_box_model_length(margin.top(), basis)
		margin_bottom:  values.resolve_box_model_length(margin.bottom(), basis)
	}
}
