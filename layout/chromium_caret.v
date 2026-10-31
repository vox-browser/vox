module layout

import math

// Blink's caret uses the font's integer ascent and descent in CSS pixels.
// Preserve the fragment's center when its unrounded metrics span another pixel.
fn caret_rect_for_rendering(rect LayoutRect, node &Node) LayoutRect {
	document := node.document()
	if document.font_rendering_policy() != .chromium { return rect }
	metrics := node.first_available_font().pixel_metrics()
	scale := document.layout_coordinate_scale()
	height := math.min(rect.height,
		(math.round(f64(metrics.ascent) / scale) + math.round(f64(metrics.descent) / scale)) * scale)
	return LayoutRect{rect.x, rect.y + (rect.height - height) / 2, rect.width, height}
}
