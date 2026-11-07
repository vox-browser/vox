module main

import css
import gg
import platform

const paint_color_cache_capacity = 256
const paint_color_cache_key_limit = 256

struct ResolvedPaintColor {
	color css.Color
	valid bool
}

// Colors are context-free at replay: force-dark and live style updates already
// supply their final serialized values. Retain only a small, owned palette;
// new values beyond either bound continue through the ordinary parser.
struct PaintColorCache {
mut:
	entries map[string]ResolvedPaintColor
}

fn (mut cache PaintColorCache) color(serialized string, opacity f64) gg.Color {
	resolved := cache.entries[serialized] or {
		mut result := ResolvedPaintColor{}
		if color := css.parse_color_string(serialized) {
			result = ResolvedPaintColor{
				color: color
				valid: true
			}
		}
		if cache.entries.len < paint_color_cache_capacity
			&& serialized.len <= paint_color_cache_key_limit {
			persistent := platform.enter_persistent()
			cache.entries[serialized.clone()] = result
			platform.leave_persistent(persistent)
		}
		result
	}
	// The existing empty/invalid-color fallback remains opaque at every opacity.
	if !resolved.valid { return gg.rgba(15, 23, 42, 255) }
	alpha := clamp(f64(resolved.color.a) * opacity, 0.0, 255.0)
	return gg.rgba(resolved.color.r, resolved.color.g, resolved.color.b, u8(int(alpha + 0.5)))
}

fn (mut cache PaintColorCache) color_with_retained(serialized string, opacity f64, retained ?css.Color) gg.Color {
	if retained != none { return paint_color_with_retained(serialized, opacity, retained) }
	return cache.color(serialized, opacity)
}
