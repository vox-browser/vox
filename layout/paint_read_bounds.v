module layout

import dom
import math
import painting

// Conservative source dependencies of ordinary CSS backdrop filters, in the
// same current viewport coordinates as DOM client rectangles. Unknown filter
// graphs, nested documents, perspective and non-uniform transforms decline.
pub fn document_backdrop_filter_read_regions(document &dom.Document) ?[]LayoutRect {
	if !document.layout_is_up_to_date() { return none }
	mut result := document_layout_result(document) or { return none }
	restore_complete_paint_projection(mut result)
	mut regions := []LayoutRect{}
	if !collect_backdrop_filter_read_regions(&result.paint_tree, result, false, mut regions) { return none }
	return regions
}

fn collect_backdrop_filter_read_regions(box &BlockBox, result &DocumentLayoutResult,
	ancestor_filter bool, mut regions []LayoutRect) bool {
	if box.opacity <= 0 { return true }
	if box.media().nested_viewport_document != none { return false }
	regular_filter := box.filters().filter.to_gfx_filter(1.0) != none
	if filter := box.filters().backdrop_filter.to_gfx_filter(1.0) {
		if !box.visible {
			for child in box.children {
				if !collect_backdrop_filter_read_regions(&child, result, ancestor_filter || regular_filter, mut regions) { return false }
			}
			return true
		}
		if ancestor_filter || regular_filter || filter.root_id != none || filter.nodes.len > 0 { return false }
		mut padding := 0.0
		for operation in filter.operations {
			match operation.kind {
				'blur' {
					if !math.is_finite(operation.first) || !math.is_finite(operation.second)
						|| operation.first < 0 || operation.second < 0 { return false }
					// The native blur uses a three-sigma input extent. Keep an
					// eight-sigma bound plus a rounding fringe for dependency tests.
					padding += 8 * math.max(operation.first, operation.second) + 8
				}
				'color', 'hue-rotate' {}
				else { return false }
			}
		}
		mut index := box.accumulated_visual_context_index
		for index > 0 {
			context := result.visual_context_tree.node_at(index)
			match context.data {
				painting.PerspectiveVisualData { return false }
				painting.TransformVisualData {
					matrix := context.data.matrix_including_origin_4x4()
					if matrix.m12 != 0 || matrix.m13 != 0 || matrix.m21 != 0 || matrix.m23 != 0
						|| matrix.m31 != 0 || matrix.m32 != 0 || matrix.m34 != 0
						|| matrix.m41 != 0 || matrix.m42 != 0 || matrix.m43 != 0
						|| matrix.m33 != 1 || matrix.m44 != 1 || matrix.m11 <= 0
						|| matrix.m11 != matrix.m22 { return false }
				}
				else {}
			}
			index = context.parent_index
		}
		border := box.border_box()
		region := paintable_box_transform_rect_to_viewport(box,
			LayoutRect{border.x - padding, border.y - padding,
				border.width + padding * 2, border.height + padding * 2},
			result.document.device_pixels_per_css_pixel(), result.visual_context_tree, result.scroll_state_snapshot)
		for value in [region.x, region.y, region.width, region.height] {
			if !math.is_finite(value) { return false }
		}
		regions << region
	}
	for child in box.children {
		if !collect_backdrop_filter_read_regions(&child, result, ancestor_filter || regular_filter, mut regions) { return false }
	}
	return true
}
