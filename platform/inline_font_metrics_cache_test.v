module platform

import math
import os

// The pre-cache calculation remains the reference, including its live policy
// lookup and explicit fallback-face precedence.
fn uncached_legacy_ascent_adjustment(font &Font, ascent f64, descent f64) f64 {
	face := font.system_face() or { return 0 }
	if face.family_name !in ['Times', 'Helvetica', 'Courier'] { return 0 }
	return math.floor((ascent + descent) * 0.15 + 0.5)
}

fn test_resolved_ascent_adjustment_matches_live_policy_and_override_precedence() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer {
		if value := previous {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', value, true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		}
	}
	missing := os.join_path(os.temp_dir(), 'vox-missing-inline-font-${os.getpid()}.ttf')
	assert !os.exists(missing)
	for configured in ['', missing, source] {
		os.setenv('LADYBIRD_LAYOUT_TEST_FONT', configured, true)
		for policy in [FontRenderingPolicy.libweb, .chromium] {
			for path in ['', source] {
				for family in ['Verdana', 'Arial', 'Times', 'Helvetica', 'Courier', ''] {
					cached := if family == '' {
						?SystemFontFace(none)
					} else {
						?SystemFontFace(SystemFontFace{ family_name: family })
					}
					for override_family in ['', 'Times', 'Verdana'] {
						override_face := if override_family == '' {
							?SystemFontFace(none)
						} else {
							?SystemFontFace(SystemFontFace{ family_name: override_family })
						}
						font := &Font{
							family:                'UnusedCachedFamily'
							point_size:            13.25
							source_path:           path
							font_rendering_policy: policy
							system_face_override:  override_face
							resolved_system_face_: cached
							system_face_resolved_: true
						}
						for heights in [[f64(0), 0], [f64(10), 3], [f64(12.5), 4.25], [f64(31),
							8]] {
							actual := chromium_legacy_ascent_adjustment(font, heights[0], heights[1])
							assert actual == uncached_legacy_ascent_adjustment(font, heights[0], heights[1])
						}
					}
				}
			}
		}
	}
}

fn test_legacy_ascent_keeps_live_test_font_suppression_after_resolution() {
	if !system_font_matching_supported() { return }
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer {
		if value := previous {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', value, true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		}
	}
	for family in ['Times', 'Helvetica', 'Courier'] {
		font := &Font{
			family:                family
			point_size:            16
			font_rendering_policy: .chromium
			resolved_system_face_: SystemFontFace{ family_name: family }
			system_face_resolved_: true
		}
		os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		assert chromium_legacy_ascent_adjustment(font, 12, 4) == 2
		os.setenv('LADYBIRD_LAYOUT_TEST_FONT', source, true)
		assert chromium_legacy_ascent_adjustment(font, 12, 4) == 0
		os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		assert chromium_legacy_ascent_adjustment(font, 12, 4) == 2
	}
}

fn test_unresolved_face_still_resolves_before_ascent_adjustment_is_cached() {
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	defer {
		if value := previous {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', value, true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		}
	}
	for family in ['Verdana', 'Times'] {
		font := &Font{ family: family, point_size: 16, font_rendering_policy: .chromium }
		assert !font.system_face_resolved_
		first := chromium_legacy_ascent_adjustment(font, 12, 4)
		assert first == uncached_legacy_ascent_adjustment(font, 12, 4)
		assert font.system_face_resolved_ == system_font_matching_supported()
		assert chromium_legacy_ascent_adjustment(font, 12, 4) == first
	}
}

fn test_cached_face_preserves_complete_fractional_inline_metrics() {
	raw := FontPixelMetrics{
		size:                  13.25
		ascent:                10.49
		descent:               3.51
		line_gap:              0.75
		x_height:              6.2
		advance_of_ascii_zero: 7.125
	}
	for family in ['Verdana', 'Times', 'Helvetica', 'Courier'] {
		font := &Font{
			family:                family
			point_size:            13.25
			font_rendering_policy: .chromium
			resolved_system_face_: SystemFontFace{ family_name: family }
			system_face_resolved_: true
			pixel_metrics_:        raw
			has_pixel_metrics_:    true
		}
		ascent := math.round(f64(raw.ascent))
		descent := math.round(f64(raw.descent))
		expected := FontPixelMetrics{
			...raw
			ascent:               f32(ascent + uncached_legacy_ascent_adjustment(font, ascent, descent))
			descent:              f32(descent)
			line_gap:             f32(math.round(f64(raw.line_gap)))
			floor_inline_leading: true
		}
		assert font.inline_metrics() == expected
		assert font.pixel_metrics() == raw
	}
}
