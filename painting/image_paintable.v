module painting

import css

// Renderer-independent state consumed by Painting::ImagePaintable::paint().
// Image loading and frame selection remain renderer responsibilities.
pub struct ImagePaintable {
pub:
	image_rect         Rect
	border_radii       BorderRadiiData
	border_widths      PixelBox
	object_fit         css.ObjectFit
	object_position    css.Position
	resolution_context css.LengthResolutionContext
	image_rendering    css.ImageRendering
	is_svg_image       bool
	// Chromium's fixed-size, empty-alt failure presentation. Pending images
	// leave this zero, so fetches never flash the broken-image frame.
	broken_image_fallback_scale f64
	broken_image_fallback_rtl bool
	// The provider's intrinsic CSS size may differ from the decoded frame
	// bitmap (notably for SVG images). Object fitting uses this size.
	intrinsic_size ?css.SizeWithAspectRatio
}

pub struct ImagePaintResult {
pub:
	bitmap     DrawScaledDecodedImageFrame
	clip_radii CornerRadii
}

// Translation of ImagePaintable::paint()'s decoded-image branch. In
// particular, scaling mode is chosen from the image element's content box (not
// the fitted destination), object-fit is resolved before object-position, and
// every intermediate fitted size is quantized to CSSPixels.
pub fn (paintable ImagePaintable) paint(bitmap_id string, bitmap_rect IntRect,
	converter DevicePixelConverter) ?ImagePaintResult {
	image_rect_device_pixels := converter.rounded_device_rect(paintable.image_rect)
	if bitmap_rect.width <= 0 || bitmap_rect.height <= 0 || paintable.image_rect.width <= 0
		|| paintable.image_rect.height <= 0 {
		return none
	}

	scaling_mode := to_gfx_scaling_mode(paintable.image_rendering, IntSize{bitmap_rect.width, bitmap_rect.height}, IntSize{image_rect_device_pixels.width, image_rect_device_pixels.height})
	natural_size := paintable.intrinsic_size or {
		css.SizeWithAspectRatio{
			width: css.CSSPixels.new(bitmap_rect.width)
			height: css.CSSPixels.new(bitmap_rect.height)
			aspect_ratio: css.CSSPixelFraction.new(css.CSSPixels.new(bitmap_rect.width), css.CSSPixels.new(bitmap_rect.height))
		}
	}
	concrete_size := css.run_default_sizing_algorithm(none, none, natural_size, css.CSSPixelSize.new(css.CSSPixels.nearest_value_for(paintable.image_rect.width), css.CSSPixels.nearest_value_for(paintable.image_rect.height)))
	content_size := Size{concrete_size.width().to_double(), concrete_size.height().to_double()}
	draw_rect := get_replaced_box_painting_area(paintable.image_rect, content_size, paintable.object_fit, paintable.object_position, paintable.resolution_context, converter) or { return none }

	mut clip_radii := paintable.border_radii
	clip_radii.shrink(paintable.border_widths.top, paintable.border_widths.right, paintable.border_widths.bottom, paintable.border_widths.left)
	return ImagePaintResult{
		bitmap: DrawScaledDecodedImageFrame{
			destination: draw_rect
			clip_rect: image_rect_device_pixels
			bitmap_id: bitmap_id
			scaling: scaling_mode
		}
		clip_radii: clip_radii.as_corners(converter)
	}
}
