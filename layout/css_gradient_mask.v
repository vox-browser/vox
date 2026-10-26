module layout

import css
import painting

// Generated mask images share the background gradient resolver. Keep them in
// the mask operation stream so even an opaque image establishes a mask group;
// dropping it changes how rounded descendants composite at the group's edge.
fn css_gradient_mask_operation(source css.StyleValue, rect painting.Rect,
	resolution css.LengthResolutionContext,
	colors css.ColorResolutionContext) ?painting.SVGMaskPaintOperation {
	if source !is css.LinearGradientStyleValue && source !is css.RadialGradientStyleValue {
		return none
	}
	if rect.width <= 0 || rect.height <= 0 { return none }
	gradient := resolve_background_gradient(source, rect.width, rect.height, resolution, colors) or {
		return none
	}
	mut stops := []painting.ColorStop{}
	for stop in css_gradient_svg_stops(gradient, gradient_stops_or_fallback(gradient)) {
		stops << painting.ColorStop{
			color:    painting.Color{stop.color.r, stop.color.g, stop.color.b, stop.color.a}
			position: stop.offset
		}
	}
	method := gradient.interpolation_method or {
		css.ColorInterpolationMethod(css.RectangularColorSpace.srgb)
	}
	color_space := if method is css.RectangularColorSpace && method == css.RectangularColorSpace.srgb_linear {
		painting.ColorInterpolationMethod.linear_srgb
	} else {
		painting.ColorInterpolationMethod.srgb
	}
	points := [painting.Point{rect.x, rect.y}, painting.Point{rect.right(), rect.y},
		painting.Point{rect.right(), rect.bottom()}, painting.Point{rect.x, rect.bottom()}]
	path := painting.ClipPathVisualData{
		segments: [
			painting.ClipPathSegment{ kind: .move_to, point: points[0] },
			painting.ClipPathSegment{ kind: .line_to, point: points[1] },
			painting.ClipPathSegment{ kind: .line_to, point: points[2] },
			painting.ClipPathSegment{ kind: .line_to, point: points[3] },
			painting.ClipPathSegment{ kind: .close_path },
		]
		polygon:  points
	}
	if gradient.kind == 'radial' {
		return painting.SVGMaskPaintOperation{
			kind:                 .path
			path:                 path
			has_fill:             true
			fill_radial_gradient: painting.SVGRadialGradientPaintStyle{
				gradient:   painting.SVGGradientPaintStyle{
					color_stops:        stops
					color_space:        color_space
					gradient_transform: painting.Affine{
						a: gradient.radius_x * rect.width
						d: gradient.radius_y * rect.height
						e: rect.x + gradient.center_x * rect.width
						f: rect.y + gradient.center_y * rect.height
					}
				}
				end_radius: 1
			}
		}
	}
	return painting.SVGMaskPaintOperation{
		kind:                 .path
		path:                 path
		has_fill:             true
		fill_linear_gradient: painting.SVGLinearGradientPaintStyle{
			gradient:    painting.SVGGradientPaintStyle{ color_stops: stops, color_space: color_space }
			start_point: painting.Point{rect.x + gradient.x1 * rect.width, rect.y + gradient.y1 * rect.height}
			end_point:   painting.Point{rect.x + gradient.x2 * rect.width, rect.y + gradient.y2 * rect.height}
		}
	}
}
