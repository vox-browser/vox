module painting

import css

// Translation of Painting::get_replaced_box_painting_area(). Keep all
// object-fit/object-position arithmetic in CSS pixels and round the completed
// destination rectangle once. Rounding its origin and offset independently
// makes fractional replaced elements drift by a device pixel.
pub fn get_replaced_box_painting_area(paintable_rect Rect, content_size Size,
	object_fit_value css.ObjectFit, object_position css.Position,
	resolution_context css.LengthResolutionContext, converter DevicePixelConverter) ?IntRect {
	return converter.rounded_device_rect(get_replaced_box_painting_rect(paintable_rect,
		content_size, object_fit_value, object_position, resolution_context)?)
}

// The unsnapped object-fit rectangle is also the container size used to lay
// out a Chromium SVG image. Raster snapping must not change its viewBox.
pub fn get_replaced_box_painting_rect(paintable_rect Rect, content_size Size,
	object_fit_value css.ObjectFit, object_position css.Position,
	resolution_context css.LengthResolutionContext) ?Rect {
	if content_size.width <= 0 || content_size.height <= 0 || paintable_rect.width <= 0
		|| paintable_rect.height <= 0 {
		return none
	}

	content_width := css.CSSPixels.nearest_value_for(content_size.width)
	content_height := css.CSSPixels.nearest_value_for(content_size.height)
	paintable_width := css.CSSPixels.nearest_value_for(paintable_rect.width)
	paintable_height := css.CSSPixels.nearest_value_for(paintable_rect.height)
	content_aspect_ratio := content_height.to_double() / content_width.to_double()
	paintable_aspect_ratio := paintable_height.to_double() / paintable_width.to_double()

	mut object_fit := object_fit_value
	if object_fit == .scale_down {
		object_fit = if content_width.to_double() > paintable_width.to_double()
			|| content_height.to_double() > paintable_height.to_double() {
			css.ObjectFit.contain
		} else {
			css.ObjectFit.none_
		}
	}

	mut scale_x := 1.0
	mut scale_y := 1.0
	match object_fit {
		.fill {
			scale_x = paintable_width.to_double() / content_width.to_double()
			scale_y = paintable_height.to_double() / content_height.to_double()
		}
		.contain {
			scale_x = if content_aspect_ratio >= paintable_aspect_ratio {
				paintable_height.to_double() / content_height.to_double()
			} else {
				paintable_width.to_double() / content_width.to_double()
			}
			scale_y = scale_x
		}
		.cover {
			scale_x = if content_aspect_ratio >= paintable_aspect_ratio {
				paintable_width.to_double() / content_width.to_double()
			} else {
				paintable_height.to_double() / content_height.to_double()
			}
			scale_y = scale_x
		}
		.none_ {}
		.scale_down {
			return none
		}
	}

	mut scaled_width := css.CSSPixels.nearest_value_for(content_width.to_double() * scale_x)
	mut scaled_height := css.CSSPixels.nearest_value_for(content_height.to_double() * scale_y)
	if resolution_context.use_chromium_geometry {
		if content_width.raw_value() <= 0 || content_height.raw_value() <= 0 { return none }
		scaled_width, scaled_height = chromium_object_fit_size(paintable_width, paintable_height,
			content_width, content_height, object_fit_value)
	}
	residual_horizontal := paintable_width.minus(scaled_width)
	residual_vertical := paintable_height.minus(scaled_height)
	offset_x := object_position.offset_x.to_px(resolution_context, residual_horizontal)
	offset_y := object_position.offset_y.to_px(resolution_context, residual_vertical)
	return Rect{
		x:      paintable_rect.x + offset_x.to_double()
		y:      paintable_rect.y + offset_y.to_double()
		width:  scaled_width.to_double()
		height: scaled_height.to_double()
	}
}

// Blink PhysicalSize::FitToAspectRatio compares the already truncated height.
// A sub-LayoutUnit ratio difference must not switch the constrained axis.
fn chromium_object_fit_size(width css.CSSPixels, height css.CSSPixels,
	intrinsic_width css.CSSPixels, intrinsic_height css.CSSPixels,
	fit css.ObjectFit) (css.CSSPixels, css.CSSPixels) {
	if fit == .fill { return width, height }
	if fit == .none_ { return intrinsic_width, intrinsic_height }
	constrained_height := chromium_object_fit_mul_div(width, intrinsic_height, intrinsic_width)
	grow := fit == .cover
	mut result_width := width
	mut result_height := constrained_height
	if (grow && constrained_height.compare(height) < 0)
		|| (!grow && constrained_height.compare(height) > 0) {
		result_width = chromium_object_fit_mul_div(height, intrinsic_width, intrinsic_height)
		result_height = height
	}
	if fit == .scale_down && result_width.compare(intrinsic_width) > 0 {
		return intrinsic_width, intrinsic_height
	}
	return result_width, result_height
}

fn chromium_object_fit_mul_div(value css.CSSPixels, numerator css.CSSPixels,
	denominator css.CSSPixels) css.CSSPixels {
	// Positive signed 32-bit raw operands fit their product in i64. Saturate
	// the quotient before returning to the fixed-point representation.
	raw := i64(value.raw_value()) * i64(numerator.raw_value()) / i64(denominator.raw_value())
	maximum := i64(css.CSSPixels.max().raw_value())
	return css.CSSPixels.from_raw(int(if raw > maximum { maximum } else { raw }))
}
