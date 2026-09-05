module painting

import css

pub struct CanvasPaintable {
pub:
	canvas_rect     Rect
	border_radii    BorderRadiiData
	border_widths   PixelBox
	image_rendering css.ImageRendering
}

pub struct CanvasPaintResult {
pub:
	content    DrawExternalContent
	clip_rect  IntRect
	clip_radii CornerRadii
}

// Translation of CanvasPaintable::paint()'s foreground phase after the
// element has presented its surface to ExternalContentSource.
pub fn (paintable CanvasPaintable) paint(source_id string, surface_size IntSize,
	converter DevicePixelConverter) ?CanvasPaintResult {
	if surface_size.width <= 0 || surface_size.height <= 0 {
		return none
	}
	canvas_rect := converter.rounded_device_rect(paintable.canvas_rect)
	if canvas_rect.is_empty() {
		return none
	}
	mut clip_radii := paintable.border_radii
	clip_radii.shrink(paintable.border_widths.top, paintable.border_widths.right, paintable.border_widths.bottom, paintable.border_widths.left)
	return CanvasPaintResult{
		content: DrawExternalContent{
			destination: canvas_rect
			source_id: source_id
			scaling: to_gfx_scaling_mode(paintable.image_rendering, surface_size, IntSize{canvas_rect.width, canvas_rect.height})
		}
		clip_rect: canvas_rect
		clip_radii: clip_radii.as_corners(converter)
	}
}
