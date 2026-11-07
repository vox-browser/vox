module layout

import css
import math
import platform
import svg

// Blink paints SVG text as glyphs of its screen-scaled font
// (LayoutSVGInlineText::ComputeNewScaledFontForStyle), not as filled outlines.
// Reshape a solid-filled text element's own text at that size and position it
// in page space, applying `spacing` textLength in the scaled space as
// SvgTextLayoutAlgorithm does. Rotated, skewed, stretched or vertical text
// keeps the outline path.
struct SVGTextGlyphs {
	runs []&platform.GlyphRun
	// The page-space start of the text's baseline.
	x f64
	y f64
}

fn chromium_svg_text_glyph_runs(node &Node, computed &css.ComputedValues, origin SVGTextPaintOrigin,
	to_page svg.AffineTransform) SVGTextGlyphs {
	if node.document().font_rendering_policy() != .chromium || !node.is_svg_text_box()
		|| node.is_svg_text_path_box() || origin.stretched || origin.text.len == 0 {
		return SVGTextGlyphs{}
	}
	if to_page.b != 0 || to_page.c != 0 || to_page.a <= 0 || to_page.a != to_page.d {
		return SVGTextGlyphs{}
	}
	if computed.writing_mode() != .horizontal_tb || computed.direction() != .ltr {
		return SVGTextGlyphs{}
	}
	scale := f32(to_page.a)
	shaped := svg_shape_text_at_scale(node, origin.text, scale)
	if shaped.runs.len == 0 {
		return SVGTextGlyphs{}
	}
	characters := svg_shaped_character_count(shaped)
	mut character_delta := f32(0)
	if text_length := origin.text_length {
		if characters > 1 {
			character_delta = (f32(text_length) * scale - f32(shaped.width)) / f32(characters - 1)
		}
	}
	mut runs := []&platform.GlyphRun{cap: shaped.runs.len}
	mut index := 0
	for run in shaped.runs {
		mut glyphs := run.glyphs().clone()
		for mut glyph in glyphs {
			glyph.position.x += character_delta * f32(index)
			index++
		}
		mut placed := platform.GlyphRun.new(run.font(), run.text_type(), glyphs)
		placed.refresh_replay_data()
		runs << placed
	}
	start := to_page.map_point(svg.Point{origin.x, origin.baseline_y})
	return SVGTextGlyphs{
		runs: runs
		x:    start.x
		y:    start.y
	}
}

// The fill color with fill-opacity folded into its alpha, as Blink's SVG paint
// flags carry it. The float components keep the unrounded alpha.
fn chromium_svg_text_fill_color(node &Node, fill css.Color, fill_opacity f64) &PaintSRGBColor {
	components := chromium_svg_paint_components(node, .fill, fill) or {
		[f64(fill.r) / 255, f64(fill.g) / 255, f64(fill.b) / 255, f64(fill.a) / 255]!
	}
	alpha := components[3] * fill_opacity
	rounded := css.Color{fill.r, fill.g, fill.b, u8(math.round(alpha * 255))}
	return &PaintSRGBColor{
		serialized: rounded.serialize()
		components: [components[0], components[1], components[2], alpha]!
	}
}

fn append_svg_text_glyph_commands(mut commands []PaintCommand, box &BlockBox, opacity f64) {
	text := box.svg_data.text
	for run in text.runs {
		commands << PaintCommand{
			kind:                'draw_text'
			x:                   box.x
			y:                   box.y
			width:               box.width
			height:              box.height
			color:               text.color.serialized
			srgb_color_data:     text.color
			text:                text.text
			font_size:           f64(run.font().point_size)
			bold:                run.font().weight >= 600
			italic:              run.font().italic
			opacity:             opacity
			glyph_run:           run
			glyph_translation_x: text.x
			glyph_translation_y: text.y
			font_smoothing:      text.font_smoothing
			force_dark_role:     .svg
			force_dark_role_set: true
		}
	}
}
