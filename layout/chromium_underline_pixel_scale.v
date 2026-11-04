module layout

import math

struct ChromiumUnderlineGeometry {
	thickness   f64
	line_offset f64
	top         f64
	height      f64
}

// DecorationLinePainter rounds in the font's device coordinate space. Keep
// command coordinates in layout units after computing those rounded values.
fn chromium_underline_geometry(fragment TextFragment, font_ascent f64, scale f64) ChromiumUnderlineGeometry {
	specified := if fragment.decoration_thickness_set {
		math.round(fragment.decoration_thickness * scale)
	} else {
		fragment.font_size * scale / 10
	}
	thickness := math.max(specified, 1.0)
	gap := if fragment.text_underline_offset_auto {
		math.max(1.0, math.ceil(thickness / 2))
	} else {
		0.0
	}
	offset := if fragment.text_underline_offset_auto {
		0.0
	} else {
		math.round(fragment.text_underline_offset * scale)
	}
	// The transported fragment starts at the line box's top. Its baseline
	// includes half-leading (and the selected font's inline metrics), whereas
	// the raw font ascent alone starts the underline inside that leading.
	baseline := if fragment.baseline_set { fragment.baseline } else {
		math.round(font_ascent * scale) / scale
	}
	line_offset := baseline + (gap + offset) / scale
	return ChromiumUnderlineGeometry{
		thickness:   thickness / scale
		line_offset: line_offset
		top:         math.floor((fragment.y + line_offset) * scale + 0.5) / scale
		height:      math.max(math.floor(thickness), 1.0) / scale
	}
}

struct ChromiumSkipInkStripe {
	upper       f64
	width       f64
	clip_top    f64
	clip_bottom f64
}

fn chromium_device_skip_ink_stripe(fragment TextFragment, font_ascent f64,
	line_offset f64, thickness f64, scale f64) ChromiumSkipInkStripe {
	baseline := if fragment.baseline_set {
		fragment.baseline
	} else {
		math.round(font_ascent * scale) / scale
	}
	decoration_top := fragment.y + line_offset
	return ChromiumSkipInkStripe{
		upper:       decoration_top + 0.5 / scale - text_fragment_paint_top(fragment) - baseline
		width:       math.max(thickness - 1 / scale, 0.0)
		clip_top:    decoration_top - 0.5 / scale
		clip_bottom: decoration_top + thickness + 0.5 / scale
	}
}

fn chromium_device_skip_ink_clips(fragment TextFragment, font_ascent f64,
	line_offset f64, thickness f64, scale f64) []f64 {
	if !fragment.decoration_skip_ink { return []f64{} }
	run := fragment.paintable_fragment.glyph_run or { return []f64{} }
	stripe := chromium_device_skip_ink_stripe(fragment, font_ascent, line_offset, thickness, scale)
	intervals := run.glyph_intercepts(f32(scale), f32(stripe.upper * scale),
		f32((stripe.upper + stripe.width) * scale))
	dilation := math.min(thickness * scale, 13.0) / scale
	mut clips := []f64{}
	for index := 0; index + 1 < intervals.len; index += 2 {
		clips << [fragment.x + f64(intervals[index]) / scale - dilation, stripe.clip_top,
			fragment.x + f64(intervals[index + 1]) / scale + dilation, stripe.clip_bottom]
	}
	return clips
}
