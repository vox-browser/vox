module layout

import css

// Blink retains a composited surface for non-perspective 3D operations even
// when their matrix is affine (for example translateZ(0)). Painting those
// descendants directly onto the page changes their premultiplied rounding.
// See CompositingReasonFinder::PotentialCompositingReasonsFor3DTransform.
fn chromium_transform_needs_surface(node &Node) bool {
	if node.document().font_rendering_policy() != .chromium || !node.is_transformable() {
		return false
	}
	computed := node.computed_values()
	value := computed.typed_property_value(.transform) or { return false }
	if value is css.StyleValueList {
		for operation in value.values() {
			if operation is css.TransformationStyleValue {
				if operation.transform_function() in [.matrix3d, .translate3d, .translate_z, .scale3d,
					.scale_z, .rotate3d, .rotate_x, .rotate_y] {
					return true
				}
			}
		}
	}
	return false
}
