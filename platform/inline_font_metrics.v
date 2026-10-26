module platform

import math

// Blink's HTML inline layout uses integer ascent and descent, while retaining
// the fractional x-height for vertical-align:middle. SVG keeps pixel_metrics().
pub fn (font &Font) inline_metrics() FontPixelMetrics {
	metrics := font.pixel_metrics()
	if font.font_rendering_policy != .chromium { return metrics }
	// Blink's zero-sized font contributes no strut. SkFont's one-pixel
	// fallback metrics belong to the upstream font API, not HTML line layout.
	if font.point_size == 0 { return FontPixelMetrics{ floor_inline_leading: true } }
	ascent := math.round(f64(metrics.ascent))
	descent := math.round(f64(metrics.descent))
	return FontPixelMetrics{
		...metrics
		ascent:               f32(ascent + chromium_legacy_ascent_adjustment(font, ascent, descent))
		descent:              f32(descent)
		line_gap:             f32(math.round(f64(metrics.line_gap)))
		floor_inline_leading: true
	}
}

// Blink on macOS preserves Safari's ascent for Times, Helvetica and Courier
// by adding 15% of the rounded font height.
fn chromium_legacy_ascent_adjustment(font &Font, ascent f64, descent f64) f64 {
	// A resolved non-legacy face (or miss) cannot acquire the adjustment when
	// layout-test fonts suppress system matching. Avoid querying that live
	// policy again for every line. Legacy faces and explicit overrides still
	// go through system_face(), preserving their policy and precedence rules.
	if font.system_face_override == none && font.system_face_resolved_ {
		cached := font.resolved_system_face_ or { return 0 }
		if cached.family_name !in ['Times', 'Helvetica', 'Courier'] {
			return 0
		}
	}
	face := font.system_face() or { return 0 }
	if face.family_name !in ['Times', 'Helvetica', 'Courier'] {
		return 0
	}
	return math.floor((ascent + descent) * 0.15 + 0.5)
}
