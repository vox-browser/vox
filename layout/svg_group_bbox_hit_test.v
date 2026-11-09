module layout

import dom
import html

fn svg_container_target_is_hit(mut document dom.Document, target &dom.Element, x f64, y f64) bool {
	hit := document.element_from_point(x, y) or { return false }
	return hit.as_node().unique_id() == target.as_node().unique_id()
}

fn test_svg_container_bounding_box_hits_include_the_transformed_gaps_in_both_rendering_policies() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for scale in [f64(1), 2] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{display:block}</style><svg width="300" height="300" opacity="0"><g id="group" transform="rotate(15)" pointer-events="bounding-box"><circle cx="50" cy="50" r="10"/><g><circle cx="150" cy="150" r="10"/></g></g></svg>')
			document.set_font_rendering_policy(policy)
			document.set_layout_coordinate_scale(scale)
			document.set_display_device_pixel_ratio(scale)
			_ = layout_document_typed_in_viewport(document, 400, 400)
			mut group := document.get_element_by_id('group') or { panic('group') }
			for point in [[f64(100), 100], [f64(137), 84], [f64(51), 156], [f64(70), 120]] {
				assert svg_container_target_is_hit(mut document, group, point[0], point[1]), 'policy=${policy} scale=${scale} point=${point}'
			}
			assert !svg_container_target_is_hit(mut document, group, 10, 10)
			group.set_attribute_value('pointer-events', 'fill')
			assert !svg_container_target_is_hit(mut document, group, 100, 100)
			group.set_attribute_value('pointer-events', 'none')
			assert !svg_container_target_is_hit(mut document, group, 100, 100)
			document.finalize()
		}
	}
}
