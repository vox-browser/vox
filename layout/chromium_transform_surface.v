module layout

import css

// Blink retains a composited surface for transform will-change hints and for
// non-perspective 3D operations even when their matrix is affine. Painting the
// descendants directly onto the page changes their premultiplied rounding.
// See CompositingReasonFinder's will-change and 3D transform reasons.
fn chromium_transform_needs_surface(node &Node) bool {
	if node.document().font_rendering_policy() != .chromium || !node.is_transformable() {
		return false
	}
	computed := node.computed_values()
	if chromium_will_change_transform_needs_surface(node) {
		return true
	}
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

fn chromium_will_change_transform_needs_surface(node &Node) bool {
	will_change := node.computed_values().will_change()
	if !(will_change.has_property(.transform) || will_change.has_property(.translate)
		|| will_change.has_property(.rotate) || will_change.has_property(.scale)
		|| will_change.has_property(.perspective) || will_change.has_property(.transform_style)) {
		return false
	}
	// Blink suppresses these hints under will-change: contents. Check DOM
	// flat-tree ancestry too: display: contents ancestors have no layout node.
	if will_change.has_contents() { return false }
	if dom_node := node.dom_node() {
		mut ancestor := dom_node.flat_tree_parent_element()
		for ancestor != none {
			current := ancestor or { break }
			if style := css.computed_properties_for_element(current) {
				if style.will_change().has_contents() { return false }
			}
			ancestor = current.as_node().flat_tree_parent_element()
		}
	} else {
		mut ancestor := node.parent()
		for ancestor != none {
			current := ancestor or { break }
			if current.has_style() && current.computed_values().will_change().has_contents() {
				return false
			}
			ancestor = current.parent()
		}
	}
	return true
}
