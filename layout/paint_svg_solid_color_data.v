module layout

import css
import math

// Keep resolved RGB bytes and unquantized solid paint channels with their exact
// transport strings. Shared recordings remain valid when force-dark or a caller
// changes either string.
pub struct PaintSVGSolidColorData {
pub:
	fill_serialized   string
	fill              css.Color
	has_fill          bool
	stroke_serialized string
	stroke            css.Color
	has_stroke        bool
	fill_alpha        f64
	stroke_alpha      f64
	has_fill_alpha    bool
	has_stroke_alpha  bool
	fill_srgb         &PaintSRGBColor = unsafe { nil }
	stroke_srgb       &PaintSRGBColor = unsafe { nil }
}

fn retained_svg_solid_color_data(fill_serialized string, fill ?css.Color,
	stroke_serialized string, stroke ?css.Color) &PaintSVGSolidColorData {
	return retained_svg_solid_color_data_with_srgb(fill_serialized, fill,
		stroke_serialized, stroke, none, none)
}

fn retained_svg_solid_color_data_with_srgb(fill_serialized string, fill ?css.Color,
	stroke_serialized string, stroke ?css.Color, fill_components ?[4]f64, stroke_components ?[4]f64) &PaintSVGSolidColorData {
	if fill == none && stroke == none { return unsafe { nil } }
	fill_color := fill or { css.Color{} }
	stroke_color := stroke or { css.Color{} }
	fill_srgb := if components := fill_components {
		&PaintSRGBColor{fill_serialized, components}
	} else {
		unsafe { nil }
	}
	stroke_srgb := if components := stroke_components {
		&PaintSRGBColor{stroke_serialized, components}
	} else {
		unsafe { nil }
	}
	fill_alpha := if fill_srgb == unsafe { nil } { 1.0 } else { fill_srgb.components[3] }
	stroke_alpha := if stroke_srgb == unsafe { nil } { 1.0 } else { stroke_srgb.components[3] }
	return &PaintSVGSolidColorData{
		fill_serialized:   fill_serialized
		fill:              fill_color
		has_fill:          fill != none
		stroke_serialized: stroke_serialized
		stroke:            stroke_color
		has_stroke:        stroke != none
		fill_alpha:        fill_alpha
		stroke_alpha:      stroke_alpha
		has_fill_alpha:    fill != none && fill_srgb != unsafe { nil }
			&& math.abs(fill_alpha * 255 - f64(fill_color.a)) > 1e-6
		has_stroke_alpha:  stroke != none && stroke_srgb != unsafe { nil }
			&& math.abs(stroke_alpha * 255 - f64(stroke_color.a)) > 1e-6
		fill_srgb:         fill_srgb
		stroke_srgb:       stroke_srgb
	}
}

pub fn (command &PaintCommand) retained_svg_solid_components(stroke bool) ?[4]f64 {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_solid_color_data
	if data == unsafe { nil } { return none }
	if stroke {
		if !data.has_stroke || data.stroke_srgb == unsafe { nil }
			|| command.stroke_color != data.stroke_serialized {
			return none
		}
		return data.stroke_srgb.components
	}
	if !data.has_fill || data.fill_srgb == unsafe { nil }
		|| command.color != data.fill_serialized {
		return none
	}
	return data.fill_srgb.components
}

pub fn (command &PaintCommand) retained_svg_solid_alpha(stroke bool) ?f64 {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_solid_color_data
	if data == unsafe { nil } { return none }
	if stroke {
		if !data.has_stroke_alpha || command.stroke_color != data.stroke_serialized { return none }
		return data.stroke_alpha
	}
	if !data.has_fill_alpha || command.color != data.fill_serialized { return none }
	return data.fill_alpha
}

pub fn (command &PaintCommand) retained_svg_fill_color() ?css.Color {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_solid_color_data
	if data == unsafe { nil } || !data.has_fill || command.color != data.fill_serialized {
		return none
	}
	return data.fill
}

pub fn (command &PaintCommand) retained_svg_stroke_color() ?css.Color {
	if command.svg_data == unsafe { nil } { return none }
	data := command.svg_data.svg_solid_color_data
	if data == unsafe { nil } || !data.has_stroke || command.stroke_color != data.stroke_serialized {
		return none
	}
	return data.stroke
}
