module layout

import css

// The adapter already resolves SVG solids to sRGB bytes. Keep those bytes with
// their exact transport strings so replay can avoid parsing them again. Shared
// recordings remain valid when force-dark or a caller changes either string.
pub struct PaintSVGSolidColorData {
pub:
	fill_serialized   string
	fill              css.Color
	has_fill          bool
	stroke_serialized string
	stroke            css.Color
	has_stroke        bool
}

fn retained_svg_solid_color_data(fill_serialized string, fill ?css.Color,
	stroke_serialized string, stroke ?css.Color) &PaintSVGSolidColorData {
	if fill == none && stroke == none { return unsafe { nil } }
	return &PaintSVGSolidColorData{
		fill_serialized:   fill_serialized
		fill:              fill or { css.Color{} }
		has_fill:          fill != none
		stroke_serialized: stroke_serialized
		stroke:            stroke or { css.Color{} }
		has_stroke:        stroke != none
	}
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
