module painting

import css

// The decoded-image part of Painting::ImagePaintable. Image loading and frame
// selection remain renderer responsibilities; this structure retains the CSS
// inputs which the C++ paintable consumes after a frame has been selected.
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
}

pub struct ImagePaintResult {
pub:
	bitmap     DrawScaledBitmap
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
	bitmap_aspect_ratio := f32(bitmap_rect.height) / f32(bitmap_rect.width)
	image_aspect_ratio := f32(paintable.image_rect.height) / f32(paintable.image_rect.width)

	mut object_fit := if paintable.is_svg_image {
		css.ObjectFit.contain
	} else {
		paintable.object_fit
	}
	if object_fit == .scale_down {
		object_fit = if f64(bitmap_rect.width) > paintable.image_rect.width
			|| f64(bitmap_rect.height) > paintable.image_rect.height {
			css.ObjectFit.contain
		} else {
			css.ObjectFit.none_
		}
	}

	mut scale_x := f32(0)
	mut scale_y := f32(0)
	match object_fit {
		.fill {
			scale_x = f32(paintable.image_rect.width) / f32(bitmap_rect.width)
			scale_y = f32(paintable.image_rect.height) / f32(bitmap_rect.height)
		}
		.contain {
			scale_x = if bitmap_aspect_ratio >= image_aspect_ratio {
				f32(paintable.image_rect.height) / f32(bitmap_rect.height)
			} else {
				f32(paintable.image_rect.width) / f32(bitmap_rect.width)
			}
			scale_y = scale_x
		}
		.cover {
			scale_x = if bitmap_aspect_ratio >= image_aspect_ratio {
				f32(paintable.image_rect.width) / f32(bitmap_rect.width)
			} else {
				f32(paintable.image_rect.height) / f32(bitmap_rect.height)
			}
			scale_y = scale_x
		}
		.none_ {
			scale_x = 1
			scale_y = 1
		}
		.scale_down {
			// Resolved above, exactly as in ImagePaintable.cpp.
			return none
		}
	}

	scaled_bitmap_width := css.CSSPixels.nearest_value_for(f64(bitmap_rect.width) * f64(scale_x))
	scaled_bitmap_height := css.CSSPixels.nearest_value_for(f64(bitmap_rect.height) * f64(scale_y))
	image_width := css.CSSPixels.nearest_value_for(paintable.image_rect.width)
	image_height := css.CSSPixels.nearest_value_for(paintable.image_rect.height)
	residual_horizontal := image_width.minus(scaled_bitmap_width)
	residual_vertical := image_height.minus(scaled_bitmap_height)
	offset_x := paintable.object_position.offset_x.to_px(paintable.resolution_context, residual_horizontal)
	offset_y := paintable.object_position.offset_y.to_px(paintable.resolution_context, residual_vertical)
	draw_rect := IntRect{
		x: image_rect_device_pixels.x + converter.rounded_device_pixels(offset_x.to_double())
		y: image_rect_device_pixels.y + converter.rounded_device_pixels(offset_y.to_double())
		width: converter.rounded_device_pixels(scaled_bitmap_width.to_double())
		height: converter.rounded_device_pixels(scaled_bitmap_height.to_double())
	}

	mut clip_radii := paintable.border_radii
	clip_radii.shrink(paintable.border_widths.top, paintable.border_widths.right, paintable.border_widths.bottom, paintable.border_widths.left)
	return ImagePaintResult{
		bitmap: DrawScaledBitmap{
			destination: draw_rect
			clip_rect: image_rect_device_pixels
			bitmap_id: bitmap_id
			scaling: scaling_mode
		}
		clip_radii: clip_radii.as_corners(converter)
	}
}
