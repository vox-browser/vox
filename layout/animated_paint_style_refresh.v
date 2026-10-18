module layout

import css

// This path is used only for samples whose changed-property union was checked
// by CSS before its shared computed style was mutated. General style updates
// keep the conservative comparison and full-refresh fallback.
fn compositor_style_refresh_supports_node(node &Node) bool {
	if node.is_svg_svg_box() {
		// An outer SVG viewport is a CSS replaced box. Without a presentation
		// transform its CSS transform belongs to the ordinary visual context,
		// outside the retained SVG paths' user-space CTM.
		element := node.dom_node() or { return false }
		svg_element := element.as_element() or { return false }
		if svg_element.has_attribute('transform') { return false }
		mut ancestor := node.parent()
		for ancestor != none {
			current := ancestor or { break }
			if current.is_svg_box() || current.is_svg_svg_box() { return false }
			ancestor = current.parent()
		}
	} else if node.is_svg_box() || node.is_svg_foreign_object_box() { return false }
	if node.is_viewport() || node.display().is_internal_table()
		|| node.display().is_table_inside() { return false }
	if node.is_generated_for_pseudo_element()
		&& !node.is_generated_for_before_pseudo_element()
		&& !node.is_generated_for_after_pseudo_element() { return false }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			// Not `in` with an array literal, which allocates on every call;
			// this runs for each animated box on every frame.
			name := element.local_name()
			if name == 'html' || name == 'body' { return false }
		}
	}
	return true
}

fn compositor_style_refresh_preserves_box_categories(box &BlockBox, changed &HandleSet) bool {
	if changed.len() == 0 { return true }
	if changed.contains(u64(box.layout_handle)) {
		node := unsafe { &Node(box.layout_handle) }
		computed := node.computed_values()
		if !compositor_style_refresh_supports_node(node)
			|| box.stacking_context != node.establishes_stacking_context()
			|| box.uses_own_paint_transform_4x4 == computed_transform_is_none(computed)
			|| (box.opacity < 1) != (computed.opacity() < 1) { return false }
	}
	for child in box.children {
		if !compositor_style_refresh_preserves_box_categories(&child, changed) { return false }
	}
	return true
}

// Paint-step membership and the retained paint order depend on compositor
// values only through opacity (cumulative entry opacity and opacity zero) and
// non-invertible cumulative transforms. Other transform samples leave both
// plans intact; only visual contexts and the flattened display list change.
struct CompositorPaintStyleRefresh {
mut:
	changed                bool
	invalidates_paint_plan bool
	// A nonzero opacity changed to another nonzero value. Paint-step
	// membership is unchanged; only the paint order's cumulative opacities
	// are stale, and replay scales the cached commands (see
	// viewport_entry_opacity_scales).
	entry_opacities_changed bool
	// Boxes whose opacity or own transform changed.
	boxes []&BlockBox
}

fn refresh_compositor_paint_styles_in_box(mut box BlockBox, state &LayoutState,
	changed &HandleSet, ancestor_transform [6]f64, mut refresh CompositorPaintStyleRefresh) {
	if changed.len() == 0 { return }
	was_noninvertible := box.has_noninvertible_paint_transform()
	if changed.contains(u64(box.layout_handle)) {
		node := unsafe { &Node(box.layout_handle) }
		if styled := node.as_node_with_style() {
			if used := state.try_get(styled) {
				computed := styled.computed_values()
				position := paint_cumulative_offset(node, state, used)
				mut transform := [6]f64{}
				mut matrix := css.FloatMatrix4x4.identity()
				uses_matrix := !computed_transform_is_none(computed)
				if uses_matrix {
					reference_box := paintable_box_transform_reference_box(node, computed, used, position, state)
					matrix = resolved_computed_transform_4x4_matrix(computed, reference_box.x,
						reference_box.y, reference_box.width, reference_box.height)
					transform = css.project_plane_to_affine_transform(matrix) or { [f64(0), 0, 0, 0, 0, 0]! }
				}
				opacity_changed := box.opacity != f64(computed.opacity())
				if opacity_changed || box.own_paint_transform != transform
					|| box.own_paint_transform_4x4 != matrix || box.uses_own_paint_transform_4x4 != uses_matrix {
					refresh.changed = true
					refresh.boxes << unsafe { &box }
				}
				if opacity_changed {
					// Opacity zero removes a context from the paint plan.
					if (box.opacity == 0) != (computed.opacity() == 0) {
						refresh.invalidates_paint_plan = true
					} else {
						refresh.entry_opacities_changed = true
					}
				}
				box.opacity = f64(computed.opacity())
				box.own_paint_transform = transform
				box.own_paint_transform_4x4 = matrix
				box.uses_own_paint_transform_4x4 = uses_matrix
			}
		}
	}
	box.paint_transform = if affine_is_compact_identity(ancestor_transform) {
		box.own_paint_transform
	} else if affine_is_compact_identity(box.own_paint_transform) {
		ancestor_transform
	} else { multiply_affine(ancestor_transform, box.own_paint_transform) }
	if box.has_noninvertible_paint_transform() != was_noninvertible {
		refresh.invalidates_paint_plan = true
	}
	for mut child in box.children {
		refresh_compositor_paint_styles_in_box(mut child, state, changed, box.paint_transform, mut refresh)
	}
}
