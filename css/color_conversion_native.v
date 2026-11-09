module css

// Preserve native Lab/XYZ coordinates instead of round-tripping through an RGB
// matrix and transfer function. Tiny chroma values otherwise acquire spurious
// hues, and a missing Cartesian component no longer gives an exact polar zero.
fn convert_native_color_components(value InterpolationColorComponents, source ConcreteColorType, target ConcreteColorType) InterpolationColorComponents {
	if source == target { return value }
	if source == .lab && target == .lch { return ci_rectangular_to_polar(value) }
	if source == .lch && target == .lab { return ci_polar_to_rectangular(value) }
	if source == .oklab && target == .oklch { return ci_rectangular_to_polar(value) }
	if source == .oklch && target == .oklab { return ci_polar_to_rectangular(value) }
	xyz := match source {
		.lab { ci_xyz50_to_xyz65(ci_lab_to_xyz50(value)) }
		.lch { ci_xyz50_to_xyz65(ci_lab_to_xyz50(ci_polar_to_rectangular(value))) }
		.oklab { ci_oklab_to_xyz65(value) }
		.oklch { ci_oklab_to_xyz65(ci_polar_to_rectangular(value)) }
		.xyzd50 { ci_xyz50_to_xyz65(value) }
		.xyzd65 { value }
		.display_p3 { ci_linear_display_p3_to_xyz65(ci_srgb_to_linear(value)) }
		.display_p3_linear { ci_linear_display_p3_to_xyz65(value) }
		else { ci_linear_srgb_to_xyz65(ci_srgb_to_linear(native_components_to_srgb(value,source))) }
	}
	return match target {
		.lab { ci_xyz50_to_lab(ci_xyz65_to_xyz50(xyz)) }
		.lch { ci_rectangular_to_polar(ci_xyz50_to_lab(ci_xyz65_to_xyz50(xyz))) }
		.oklab { ci_xyz65_to_oklab(xyz) }
		.oklch { ci_rectangular_to_polar(ci_xyz65_to_oklab(xyz)) }
		.xyzd50 { ci_xyz65_to_xyz50(xyz) }
		.xyzd65 { xyz }
		else { srgb_to_relative_color_target(native_components_to_srgb(value,source),target) }
	}
}
