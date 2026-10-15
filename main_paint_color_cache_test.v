module main

import css

fn test_paint_color_cache_replays_each_alpha_and_opacity_like_the_parser() {
	mut cache := PaintColorCache{}
	for alpha in 0 .. 256 {
		serialized := css.Color{
			r: 21
			g: 103
			b: 221
			a: u8(alpha)
		}.serialize()
		for opacity in [f64(-1), 0, 0.01, 0.2, 0.5, 0.999, 1, 2] {
			assert cache.color(serialized, opacity) == paint_color(serialized, opacity)
			assert cache.color(serialized, opacity) == paint_color(serialized, opacity)
		}
	}
}

fn test_paint_color_cache_preserves_fallbacks_and_distinguishes_live_colors() {
	mut cache := PaintColorCache{}
	for serialized in ['', 'not-a-color', 'rgb(1, 2)', 'currentColor'] {
		for opacity in [f64(0), 0.5, 1] {
			assert cache.color(serialized, opacity) == paint_color(serialized, opacity)
		}
	}
	for serialized in ['red', 'rgb(1, 2, 3)', 'rgba(4, 5, 6, 0.5)', '#fedcba'] {
		assert cache.color(serialized, 0.5) == paint_color(serialized, 0.5)
	}
	assert cache.color('red', 1) != cache.color('#fedcba', 1)
	retained := css.Color{
		r: 7
		g: 8
		b: 9
		a: 128
	}
	assert cache.color_with_retained('red', 0.5, retained) == paint_color_with_retained('red', 0.5,
		retained)
	assert cache.color_with_retained('blue', 0.5, none) == paint_color('blue', 0.5)
}

fn test_paint_color_cache_owns_keys_and_bounds_the_retained_palette() {
	mut cache := PaintColorCache{}
	mut transient := 'rgb(12, 34, 56)'.clone()
	expected := paint_color(transient, 1)
	assert cache.color(transient, 1) == expected
	unsafe { transient.free() }
	$if gcboehm ? { C.GC_gcollect() }
	assert cache.color('rgb(12, 34, 56)', 1) == expected
	for channel in 0 .. 300 {
		serialized := css.Color{
			r: u8(channel % 256)
			g: u8(channel / 256)
			b: 15
			a: 255
		}.serialize()
		assert cache.color(serialized, 0.5) == paint_color(serialized, 0.5)
	}
	assert cache.entries.len == paint_color_cache_capacity
	mut other := PaintColorCache{}
	large := ' '.repeat(paint_color_cache_key_limit) + 'red'
	assert other.color(large, 0.5) == paint_color(large, 0.5)
	assert other.entries.len == 0
	assert cache.entries.len == paint_color_cache_capacity
}
