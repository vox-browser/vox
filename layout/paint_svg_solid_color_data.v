module layout

import css

// Keep resolved RGB bytes and unquantized modern paint alpha with their exact
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
}

fn retained_svg_solid_color_data(fill_serialized string, fill ?css.Color,
	stroke_serialized string, stroke ?css.Color) &PaintSVGSolidColorData {
	return retained_svg_solid_color_data_with_alpha(fill_serialized, fill,
		stroke_serialized, stroke, none, none)
}

fn retained_svg_solid_color_data_with_alpha(fill_serialized string, fill ?css.Color,
	stroke_serialized string, stroke ?css.Color, fill_alpha ?f64, stroke_alpha ?f64) &PaintSVGSolidColorData {
	if fill == none && stroke == none { return unsafe { nil } }
	return &PaintSVGSolidColorData{
		fill_serialized:   fill_serialized
		fill:              fill or { css.Color{} }
		has_fill:          fill != none
		stroke_serialized: stroke_serialized
		stroke:            stroke or { css.Color{} }
		has_stroke:        stroke != none
		fill_alpha:        fill_alpha or { 1 }
		stroke_alpha:      stroke_alpha or { 1 }
		has_fill_alpha:    fill != none && fill_alpha != none
		has_stroke_alpha:  stroke != none && stroke_alpha != none
	}
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
