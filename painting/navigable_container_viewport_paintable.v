module painting

// Renderer-independent inputs retained by
// NavigableContainerViewportPaintable::paint() for its foreground phase.
pub struct NavigableContainerViewportPaintable {
pub:
	viewport_rect Rect
	nested_rect   ?Rect
	// SVG image layout retains its CSS container size even when the painted
	// destination has been snapped to whole pixels.
	nested_layout_size ?Size
	border_radii  BorderRadiiData
	border_widths PixelBox
}

pub struct NavigableContainerViewportPaintResult {
pub:
	clip_rect   IntRect
	clip_radii  CornerRadii
	nested_rect IntRect
}

// Translation of NavigableContainerViewportPaintable::paint() after the
// hosted document has updated layout and produced its nested display list.
pub fn (paintable NavigableContainerViewportPaintable) paint(converter DevicePixelConverter) ?NavigableContainerViewportPaintResult {
	clip_rect := converter.rounded_device_rect(paintable.viewport_rect)
	if clip_rect.is_empty() {
		return none
	}
	mut clip_radii := paintable.border_radii
	clip_radii.shrink(paintable.border_widths.top, paintable.border_widths.right, paintable.border_widths.bottom, paintable.border_widths.left)
	return NavigableContainerViewportPaintResult{
		clip_rect: clip_rect
		clip_radii: clip_radii.as_corners(converter)
		nested_rect: converter.enclosing_device_rect(paintable.nested_rect or {
			paintable.viewport_rect
		})
	}
}
