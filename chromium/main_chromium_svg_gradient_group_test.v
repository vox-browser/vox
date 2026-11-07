module main

import layout
import painting

fn svg_gradient_group_test_command() layout.PaintCommand {
	return layout.PaintCommand{
		kind:     'draw_svg_path'
		svg_data: &layout.PaintSVGPathData{
			path_data:         [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			svg_gradient_data: &layout.PaintSVGGradientData{
				fill_linear_gradient: painting.SVGLinearGradientPaintStyle{
					gradient: painting.SVGGradientPaintStyle{
						color_stops: [painting.ColorStop{ color: painting.Color{255, 0, 0, 255} }]
					}
				}
			}
		}
	}
}

fn test_gradient_fill_group_stops_at_layer_clip_or_effect_changes() {
	base := svg_gradient_group_test_command()
	assert chromium_svg_gradient_run_end([base, base, base], [0, 0, 1], 0) == 2
	assert chromium_svg_gradient_run_end([base, base], [0, 1], 0) == 0
	assert chromium_svg_gradient_run_end([base], [0], 0) == 0
	assert chromium_svg_gradient_run_end([base, base], [], 0) == 0
	for barrier in [
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ ...base, opacity: 0.5 },
		layout.PaintCommand{ ...base, group_opacity: 0.5 },
		layout.PaintCommand{ ...base, stroke_color: '#000', stroke_width: 1 },
		layout.PaintCommand{ ...base, has_clip: true, clip_width: 10, clip_height: 10 },
	] {
		assert chromium_svg_gradient_run_end([base, base, barrier, base], [0, 0, 0, 0], 0) == 2
	}
}

fn test_gradient_fill_group_accepts_shared_rectangular_clips_and_rejects_rounded_clips() {
	base := svg_gradient_group_test_command()
	clipped := layout.PaintCommand{
		...base
		has_clip:    true
		clip_width:  20
		clip_height: 20
		clip_list:   &layout.PaintClipList{ items: [layout.PaintClip{}] }
	}
	assert chromium_svg_gradient_run_end([clipped, clipped], [1, 1], 0) == 2
	rounded := layout.PaintCommand{
		...clipped
		clip_list: &layout.PaintClipList{
			items: [layout.PaintClip{
				corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{ x: 2, y: 2 } }
			}]
		}
	}
	assert chromium_svg_gradient_run_end([rounded, rounded], [1, 1], 0) == 0
}

fn test_gradient_fill_group_duplicates_single_stop_and_preserves_stop_alpha() {
	assert chromium_svg_gradient_stops(painting.SVGGradientPaintStyle{}).len == 0
	data := chromium_svg_gradient_stops(painting.SVGGradientPaintStyle{
		color_stops: [painting.ColorStop{ color: painting.Color{255, 128, 0, 128}, position: 0.7 }]
	})
	assert data.len == 10
	assert data[0] == 1 && data[1] == f32(128) / 255 && data[2] == 0
	assert data[3] == f32(128) / 255 && data[4] == 0
	assert data[5] == data[0] && data[8] == data[3] && data[9] == 1
}
