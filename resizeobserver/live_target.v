module resizeobserver

import dom

// Read the committed DOM/layout boundary at gathering and broadcasting time.
// Never force layout here: an earlier observer may have dirtied it during the
// same rendering update, and upstream deliberately reads the last committed box.
pub fn ResizeTarget.for_element(element &dom.Element) &ResizeTarget {
	return &ResizeTarget{ element: element, live_metrics_: true }
}

fn (target &ResizeTarget) resolved_metrics() ResizeTargetMetrics {
	if !target.live_metrics_ { return target.metrics }
	node := target.element.as_node().layout_node() or { return ResizeTargetMetrics{} }
	if !node.has_geometry_ || node.display_.is_none() || node.display_.is_contents()
		|| (node.display_.is_inline_outside() && node.display_.is_flow_inside()
			&& !node.is_atomic_inline_ && !node.is_replaced_box_) {
		return ResizeTargetMetrics{}
	}
	document := target.element.document()
	scale := document.layout_coordinate_scale()
	edges := node.box_model()
	return ResizeTargetMetrics{
		has_layout_box:     true
		is_svg_element:     target.element.is_svg_element()
		border_width:       (node.content_width_ + edges.padding_left + edges.padding_right + edges.border_left + edges.border_right) / scale
		border_height:      (node.content_height_ + edges.padding_top + edges.padding_bottom + edges.border_top + edges.border_bottom) / scale
		content_width:      node.content_width_ / scale
		content_height:     node.content_height_ / scale
		device_pixel_ratio: document.display_device_pixel_ratio()
		absolute_padding_x: edges.padding_left / scale
		absolute_padding_y: edges.padding_top / scale
	}
}
