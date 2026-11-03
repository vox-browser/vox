module platform

import math

fn test_tracking_size_separates_shaping_caches_at_the_same_physical_size() {
	$if !macos { return }
	physical := &Font{family: 'SystemUi', point_size: 28, weight: 600,
		font_rendering_policy: .chromium}
	css_sized := &Font{...*physical, shaping_ptem: 14}
	original := shaped_text_width(0, 0, 'Log in', physical, .ltr)
	projected := shaped_text_width(0, 0, 'Log in', css_sized, .ltr)
	assert original - projected > 1
	assert !physical.has_same_identity(css_sized)
	assert shaping_cache_font_key(physical) != shaping_cache_font_key(css_sized)
	for _ in 0 .. 3 {
		assert shaped_text_width(0, 0, 'Log in', physical, .ltr) == original
		assert shaped_text_width(0, 0, 'Log in', css_sized, .ltr) == projected
	}
	// Refill both HarfBuzz and text caches in the opposite order.
	release_unused_text_shaping()
	assert shaped_text_width(0, 0, 'Log in', css_sized, .ltr) == projected
	assert shaped_text_width(0, 0, 'Log in', physical, .ltr) == original
}

fn test_css_tracking_size_survives_character_fallback_and_its_owned_cache() {
	$if !macos { return }
	physical := &Font{family: 'SystemUi', point_size: 28, font_rendering_policy: .chromium}
	css_sized := &Font{...*physical, shaping_ptem: 14}
	first := system_fallback_font(0x4e2d, 'zh-Hans', css_sized) or { panic('fallback') }
	second := system_fallback_font(0x4e2d, 'zh-Hans', physical) or { panic('fallback') }
	assert first.point_size == second.point_size
	assert first.tracking_size() == 14
	assert second.tracking_size() == 28
	assert voidptr(first) != voidptr(second)
	assert voidptr(system_fallback_font(0x4e2d, 'zh-Hans', css_sized)?) == voidptr(first)
}

fn test_invalid_tracking_overrides_keep_the_physical_size_and_identity() {
	base := &Font{family: 'Arial', point_size: 18}
	for size in [f32(0), -1, f32(math.nan()), f32(math.inf(1))] {
		other := &Font{...*base, shaping_ptem: size}
		assert other.tracking_size() == 18
		assert other.has_same_identity(base)
	}
}
