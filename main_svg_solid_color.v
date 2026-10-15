module main

import css
import gg

fn paint_color_with_retained(serialized string, opacity f64, retained ?css.Color) gg.Color {
	parsed := retained or { return paint_color(serialized, opacity) }
	alpha := clamp(f64(parsed.a) * opacity, 0.0, 255.0)
	return gg.rgba(parsed.r, parsed.g, parsed.b, u8(int(alpha + 0.5)))
}
