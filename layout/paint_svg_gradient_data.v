module layout

import painting

// Only gradient-painted paths need these values. Retain one immutable snapshot
// through phase caches and recordings instead of embedding all four optional
// gradient styles in every text, border, image and solid-path command.
pub struct PaintSVGGradientData {
pub:
	fill_linear_gradient   ?painting.SVGLinearGradientPaintStyle = ?painting.SVGLinearGradientPaintStyle(none)
	stroke_linear_gradient ?painting.SVGLinearGradientPaintStyle = ?painting.SVGLinearGradientPaintStyle(none)
	fill_radial_gradient   ?painting.SVGRadialGradientPaintStyle = ?painting.SVGRadialGradientPaintStyle(none)
	stroke_radial_gradient ?painting.SVGRadialGradientPaintStyle = ?painting.SVGRadialGradientPaintStyle(none)
}

fn retained_svg_gradient_data(fill_linear ?painting.SVGLinearGradientPaintStyle,
	stroke_linear ?painting.SVGLinearGradientPaintStyle,
	fill_radial ?painting.SVGRadialGradientPaintStyle,
	stroke_radial ?painting.SVGRadialGradientPaintStyle) ?&PaintSVGGradientData {
	if fill_linear == none && stroke_linear == none && fill_radial == none
		&& stroke_radial == none {
		return none
	}
	return &PaintSVGGradientData{
		fill_linear_gradient: fill_linear
		stroke_linear_gradient: stroke_linear
		fill_radial_gradient: fill_radial
		stroke_radial_gradient: stroke_radial
	}
}

pub fn (command &PaintCommand) fill_linear_gradient() ?painting.SVGLinearGradientPaintStyle {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_gradient_data or { return none }
	return data.fill_linear_gradient
}

pub fn (command &PaintCommand) stroke_linear_gradient() ?painting.SVGLinearGradientPaintStyle {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_gradient_data or { return none }
	return data.stroke_linear_gradient
}

pub fn (command &PaintCommand) fill_radial_gradient() ?painting.SVGRadialGradientPaintStyle {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_gradient_data or { return none }
	return data.fill_radial_gradient
}

pub fn (command &PaintCommand) stroke_radial_gradient() ?painting.SVGRadialGradientPaintStyle {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_gradient_data or { return none }
	return data.stroke_radial_gradient
}
