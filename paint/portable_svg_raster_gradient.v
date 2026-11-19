module main

import cpuraster
import layout
import math
import painting

fn portable_svg_raster_linear_supported(linear &painting.SVGLinearGradientPaintStyle,
	uses_rgb bool) bool {
	return portable_svg_raster_stops_supported(&linear.gradient, uses_rgb)
		&& [linear.start_point.x, linear.start_point.y, linear.end_point.x,
			linear.end_point.y]!.all(math.is_finite(f64(f32(it))))
}

fn portable_svg_raster_radial_supported(radial &painting.SVGRadialGradientPaintStyle,
	uses_rgb bool) bool {
	if !portable_svg_raster_stops_supported(&radial.gradient, uses_rgb)
		|| ![radial.start_center.x, radial.start_center.y, radial.end_center.x, radial.end_center.y,
			radial.start_radius, radial.end_radius]!.all(math.is_finite(f64(f32(it)))) {
		return false
	}
	// Use the two-point shader when the resolved focal circle fits as supplied.
	dx := radial.start_center.x - radial.end_center.x
	dy := radial.start_center.y - radial.end_center.y
	return radial.start_radius >= 0 && radial.end_radius > radial.start_radius
		&& math.sqrt(dx * dx + dy * dy) + radial.start_radius <= radial.end_radius
}

fn portable_svg_raster_stops_supported(gradient &painting.SVGGradientPaintStyle, uses_rgb bool) bool {
	if gradient.repeat_length != none || gradient.color_stops.len == 0
		|| (uses_rgb && gradient.color_space != .srgb) {
		return false
	}
	if local := portable_svg_raster_gradient_transform(gradient) {
		if !local.all(math.is_finite(f64(it))) || local[0] * local[3] == local[1] * local[2] {
			return false
		}
	}
	return gradient.color_stops.all(it.position >= 0 && it.position <= 1)
}

fn portable_svg_raster_spread(gradient &painting.SVGGradientPaintStyle) cpuraster.CanvasGradientSpread {
	return match gradient.spread_method {
		.pad { .pad }
		.repeat { .repeat }
		.reflect { .reflect }
	}
}

fn portable_svg_raster_gradient_transform(gradient &painting.SVGGradientPaintStyle) ?[6]f32 {
	local := gradient.gradient_transform or { return none }
	return [f32(local.a), f32(local.b), f32(local.c), f32(local.d), f32(local.e), f32(local.f)]!
}

fn portable_svg_raster_gradient_stops(gradient &painting.SVGGradientPaintStyle, uses_rgb bool) []f32 {
	mut stops := []f32{cap: gradient.color_stops.len * 5}
	for stop in gradient.color_stops {
		stops << f32(stop.position)
		stops << if uses_rgb { f32(stop.color.r) / 255 } else { f32(1) }
		stops << if uses_rgb { f32(stop.color.g) / 255 } else { f32(1) }
		stops << if uses_rgb { f32(stop.color.b) / 255 } else { f32(1) }
		stops << f32(stop.color.a) / 255
	}
	return stops
}

fn portable_svg_raster_linear_gradient(linear &painting.SVGLinearGradientPaintStyle,
	uses_rgb bool) cpuraster.CanvasGradient {
	return cpuraster.CanvasGradient{
		kind: 1
		x0: f32(linear.start_point.x)
		y0: f32(linear.start_point.y)
		x1: f32(linear.end_point.x)
		y1: f32(linear.end_point.y)
		spread: portable_svg_raster_spread(&linear.gradient)
		local_transform: portable_svg_raster_gradient_transform(&linear.gradient)
		stops: portable_svg_raster_gradient_stops(&linear.gradient, uses_rgb)
	}
}

fn portable_svg_raster_radial_gradient(radial &painting.SVGRadialGradientPaintStyle,
	uses_rgb bool) cpuraster.CanvasGradient {
	return cpuraster.CanvasGradient{
		kind: 2
		x0: f32(radial.start_center.x)
		y0: f32(radial.start_center.y)
		r0: f32(radial.start_radius)
		x1: f32(radial.end_center.x)
		y1: f32(radial.end_center.y)
		r1: f32(radial.end_radius)
		spread: portable_svg_raster_spread(&radial.gradient)
		local_transform: portable_svg_raster_gradient_transform(&radial.gradient)
		stops: portable_svg_raster_gradient_stops(&radial.gradient, uses_rgb)
	}
}

fn portable_svg_visible_gradient(command &layout.PaintCommand, stroke bool) ?cpuraster.CanvasGradient {
	linear := if stroke { command.stroke_linear_gradient() } else { command.fill_linear_gradient() }
	if gradient := linear {
		if !portable_svg_raster_linear_supported(&gradient, true) { return none }
		return portable_svg_raster_linear_gradient(&gradient, true)
	}
	radial := if stroke { command.stroke_radial_gradient() } else { command.fill_radial_gradient() }
	if gradient := radial {
		if !portable_svg_raster_radial_supported(&gradient, true) { return none }
		return portable_svg_raster_radial_gradient(&gradient, true)
	}
	return none
}

fn (mut app BrowserApp) draw_portable_svg_raster_gradient_fill(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
	if data.path_data.len < layout.compatibility_clip_path_segment_stride || data.fill_pattern != none {
		return false
	}
	gradient := portable_svg_visible_gradient(command, false) or { return false }
	opacity := f32(clamp(command.opacity * data.fill_opacity, 0.0, 1.0))
	if opacity == 0 { return true }
	return app.draw_portable_svg_raster_fill(command, data, page_x, page_y, gradient, opacity)
}
