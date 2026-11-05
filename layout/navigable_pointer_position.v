module layout

import dom
import painting

// Map a hit on a navigable container to its embedded viewport. Use the same
// retained visual contexts as painting, including ancestor scroll and clips.
pub fn navigable_container_pointer_position(element &dom.Element, position painting.Point) ?painting.Point {
	layout_node := element.as_node().layout_node() or { return none }
	mut result := document_layout_result(element.document()) or { return none }
	viewport_build_hit_test_display_list(voidptr(result))
	box := result.retained_box_for_layout(layout_node.real_layout_handle()) or { return none }
	local := paintable_box_transform_point_to_local_for_descendants(box, position, 1.0,
		result.visual_context_tree, result.scroll_state_snapshot) or { return none }
	point := painting.Point{local.x - box.x, local.y - box.y}
	if point.x < 0 || point.y < 0 || point.x >= box.width || point.y >= box.height { return none }
	return point
}
