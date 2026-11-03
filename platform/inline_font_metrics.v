module platform

import math

// Blink's HTML inline layout uses integer ascent and descent, while retaining
// the fractional x-height for vertical-align:middle. SVG keeps pixel_metrics().
pub fn (font &Font) inline_metrics() FontPixelMetrics {
	return font.inline_metrics_at_scale(1)
}

// Keep the selected CSS font instance, but round its metrics on the presenting
// device grid. Layout that already uses device coordinates supplies scale 1.
pub fn (font &Font) inline_metrics_at_scale(device_scale f64) FontPixelMetrics {
	metrics := font.pixel_metrics()
	if font.font_rendering_policy != .chromium { return metrics }
	scale := if device_scale > 0 && !math.is_inf(device_scale, 0) && !math.is_nan(device_scale) {
		device_scale
	} else { 1.0 }
	// Blink's zero-sized font contributes no strut. SkFont's one-pixel
	// fallback metrics belong to the upstream font API, not HTML line layout.
	if font.point_size == 0 { return FontPixelMetrics{ floor_inline_leading: true } }
	ascent := math.round(f64(metrics.ascent) * scale)
	descent := math.round(f64(metrics.descent) * scale)
	return FontPixelMetrics{
		...metrics
		ascent:               f32((ascent + chromium_legacy_ascent_adjustment(font, ascent, descent)) / scale)
		descent:              f32(descent / scale)
		line_gap:             f32(math.round(f64(metrics.line_gap) * scale) / scale)
		floor_inline_leading: true
		inline_leading_scale: scale
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
