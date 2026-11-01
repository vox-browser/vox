module layout

import dom
import svg

pub struct CssSvgFilterGeometry {
pub:
	origin_x f64
	origin_y f64
	bounds   LayoutRect
}

pub fn css_svg_filter_geometry(document &dom.Document, scope u64) ?CssSvgFilterGeometry {
	result := document_layout_result(document) or { return none }
	for entry in result.paint_order {
		box := entry.box
		if scope == 0 || u64(box.own_effects_visual_context_idx) != scope || box.layout_handle == unsafe { nil } {
			continue
		}
		node := unsafe { &Node(box.layout_handle) }
		if !node.is_svg_svg_box() { return none }
		styled := node.as_node_with_style() or { return none }
		used := result.state.try_get(styled) or { return none }
		element := svg_element_for_layout_node(node) or { return none }
		view_box := svg.parse_viewbox(element.get_attribute_value('viewBox')) or { return none }
		transform := used.svg_viewport_transform() or { return none }
		position := svg_root_position_for_paint(node, result.state, used)
		bounds := compatibility_affine_map_rect([transform.a, transform.b, transform.c, transform.d,
			transform.e, transform.f]!, LayoutRect{view_box.min_x, view_box.min_y, view_box.width, view_box.height})
		return CssSvgFilterGeometry{position.x().to_double(), position.y().to_double(), bounds}
	}
	return none
}

// Restrict local SVG filter replay to the viewport that owns the effect.
// A filter on an HTML ancestor can use a different space from its SVG child.
pub fn css_filter_scope_is_svg_viewport(document &dom.Document, scope u64) bool {
	if scope == 0 { return false }
	result := document_layout_result(document) or { return false }
	for entry in result.paint_order {
		box := entry.box
		if u64(box.own_effects_visual_context_idx) != scope { continue }
		if box.layout_handle == unsafe { nil } { return false }
		node := unsafe { &Node(box.layout_handle) }
		return node.is_svg_svg_box()
	}
	return false
}
