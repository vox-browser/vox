module platform

import math

// Blink's HTML inline layout uses integer ascent and descent, while retaining
// the fractional x-height for vertical-align:middle. SVG keeps pixel_metrics().
pub fn (font &Font) inline_metrics() FontPixelMetrics {
	metrics := font.pixel_metrics()
	if font.font_rendering_policy != .chromium { return metrics }
	return FontPixelMetrics{
		...metrics
		ascent: f32(math.round(f64(metrics.ascent)))
		descent: f32(math.round(f64(metrics.descent)))
		line_gap: f32(math.round(f64(metrics.line_gap)))
		floor_inline_leading: true
	}
}
