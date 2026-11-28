module main

import layout
import math

fn svg_viewport_test_command() layout.PaintCommand {
	return layout.PaintCommand{
		kind:      'draw_svg_path'
		color:     'white'
		has_clip:  true
		clip_list: &layout.PaintClipList{
			items: [layout.PaintClip{
				rect: layout.LayoutRect{7, 10, 12, 9}
			}]
		}
		svg_data:  &layout.PaintSVGPathData{
			path_transform: [f64(2), 0, 0, 3, 5, 7]!
			path_data:      [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	}
}

fn test_svg_background_viewport_keeps_author_clip_and_local_coordinate_precision() {
	command := svg_viewport_test_command()
	path := chromium_svg_background_viewport_path(&command, 100, 60) or { panic('viewport') }
	assert path.matrix == [f32(2), 0, 5, 0, 3, 7, 0, 0, 1]!
	assert path.has_clip == 1 && path.has_ancestor_clip == 1
	assert path.clip == [f32(1), 1, 6, 3, 0, 0, 0, 0, 0, 0, 0, 0]!
	assert path.ancestor_clip == [f32(-2.5), f32(-7.0 / 3), 50, 20, 0, 0, 0, 0, 0, 0, 0, 0]!
}

fn test_svg_background_viewport_retains_unsupported_effect_and_stroke_fallbacks() {
	base := svg_viewport_test_command()
	for command in [layout.PaintCommand{ ...base, kind: 'begin_svg_mask_layer' },
		layout.PaintCommand{ ...base, opacity: .5 }, layout.PaintCommand{ ...base, group_opacity: .5 },
		layout.PaintCommand{ ...base, stroke_color: 'red', stroke_width: 1 },
		layout.PaintCommand{ ...base, transform: [f64(0), 1, -1, 0, 0, 0]! }] {
		if _ := chromium_svg_background_viewport_path(&command, 100, 60) {
			assert false
		}
	}
}

fn test_svg_background_viewport_rejects_nonfinite_or_empty_geometry() {
	command := svg_viewport_test_command()
	for value in [f64(0), -1, math.nan(), math.inf(1)] {
		if _ := chromium_svg_background_viewport_path(&command, value, 60) {
			assert false
		}
		if _ := chromium_svg_background_viewport_path(&command, 100, value) {
			assert false
		}
	}
}

fn test_svg_background_viewport_keeps_outer_opacity_and_color_filter_fallbacks() {
	base := layout.PaintCommand{ kind: 'draw_background_image' }
	assert chromium_svg_background_viewport_outer_supported(&base)
	for command in [layout.PaintCommand{ ...base, kind: 'draw_replaced_image' },
		layout.PaintCommand{ ...base, opacity: .5 }, layout.PaintCommand{ ...base, group_opacity: .5 },
		layout.PaintCommand{ ...base, blur: 1 }, layout.PaintCommand{ ...base, outer_shadow: true },
		layout.PaintCommand{ ...base, apply_force_dark_to_image: true }] {
		assert !chromium_svg_background_viewport_outer_supported(&command)
	}
}

fn test_svg_background_viewport_preserves_analytic_oval_sampling_policy() {
	oval := layout.PaintCommand{
		kind:     'draw_svg_path'
		color:    '#c00'
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(6), 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0]
		}
	}
	curve := layout.PaintCommand{
		...oval
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 8, 8, 2, 0, 6, 8, 0, 0, 0,
				0, 0]
		}
	}
	assert !chromium_svg_background_viewport_uses_msaa([])
	assert !chromium_svg_background_viewport_uses_msaa([oval, oval])
	assert chromium_svg_background_viewport_uses_msaa([oval, curve])
}
