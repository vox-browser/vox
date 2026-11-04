module platform

import math

// Blink's ShapeResultSpacing converts each CSS spacing value to a signed
// TextRunLayoutUnit (16.16) before adding it to an individual glyph advance.
// Truncation is towards zero, including for negative spacing.
fn (font &Font) quantized_shaping_spacing(value f32) f32 {
	if font.font_rendering_policy != .chromium { return value }
	if math.is_nan(f64(value)) { return 0 }
	scaled := f64(value) * 65536
	if scaled >= 2147483647 { return f32(2147483647.0 / 65536) }
	if scaled <= -2147483648 { return -32768 }
	return f32(f64(i64(scaled)) / 65536)
}
