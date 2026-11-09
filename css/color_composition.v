module css

// Share interpolation-space selection, missing channels and legacy output
// with ordinary interpolation, then add the premultiplied components.
fn composite_colors(from StyleValue, to StyleValue, context ColorResolutionContext) ?StyleValue {
	base := perform_color_interpolation(from, to, 0, none, context) or { return none }
	state := base.state
	first := premultiply_color_components(state.from_components, state.is_polar, state.hue_index)
	second := premultiply_color_components(state.to_components, state.is_polar, state.hue_index)
	alpha := image_color_clamp(state.from_components.alpha() + state.to_components.alpha(), 0, 1)
	mut components := interpolation_color_components(0, 0, 0, alpha)
	if alpha != 0 {
		for index in 0 .. 3 { components.set_component(index, (first.component(index) + second.component(index)) / alpha) }
	}
	return style_value_for_interpolated_color(InterpolatedColor{...base, components:components})
}
