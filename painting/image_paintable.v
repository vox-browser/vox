module painting

import css
import platform

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
	// The provider's intrinsic CSS size may differ from the decoded frame
	// bitmap (notably for SVG images). Object fitting uses this size.
	intrinsic_size      ?css.SizeWithAspectRatio
	renders_as_alt_text bool
	alt_text            string
	alt_text_color      Color
}

pub struct ImagePaintResult {
pub:
	bitmap     DrawScaledBitmap
	clip_radii CornerRadii
}

pub struct ImageAltTextPaintResult {
pub:
	outline   DrawRect
	glyph_run DrawGlyphRun
	text      string
	font_size f64
}

// Translation of ImagePaintable::paint()'s broken-image branch. The image
// content rectangle is outlined in black and the element's alternative text
// is shaped with the default 12px font, centered in that same rectangle.
pub fn (paintable ImagePaintable) paint_alt_text(converter DevicePixelConverter) ?ImageAltTextPaintResult {
	if !paintable.renders_as_alt_text || paintable.alt_text == '' {
		return none
	}
	enclosing_rect := converter.enclosing_device_rect(paintable.image_rect)
	if enclosing_rect.is_empty() {
		return none
	}
	font_size := f64(12)
	font := &platform.Font{
		family: 'sans-serif'
		point_size: f32(font_size)
	}
	glyph_run := platform.shape_text(0, 0, paintable.alt_text, font, .ltr)
	metrics := font.pixel_metrics()
	baseline_x := f64(enclosing_rect.x) + (f64(enclosing_rect.width) - f64(glyph_run.width())) / 2.0
	baseline_y := f64(enclosing_rect.y) + f64(metrics.ascent) + (f64(enclosing_rect.height) - f64(metrics.ascent + metrics.descent)) / 2.0
	return ImageAltTextPaintResult{
		outline: DrawRect{
			rect: enclosing_rect
			color: Color{}
		}
		glyph_run: DrawGlyphRun{
			glyph_run_id: u64(voidptr(glyph_run)).str()
			glyph_run: glyph_run
			rect: enclosing_rect
			translation: Point{baseline_x, baseline_y}
			color: paintable.alt_text_color
			orientation: .horizontal
		}
		text: paintable.alt_text
		font_size: font_size
	}
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
		bitmap: DrawScaledBitmap{
			destination: draw_rect
			clip_rect: image_rect_device_pixels
			bitmap_id: bitmap_id
			scaling: scaling_mode
		}
		clip_radii: clip_radii.as_corners(converter)
	}
}
