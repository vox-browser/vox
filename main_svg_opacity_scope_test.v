module main

import css
import layout

fn test_css_opacity_keeps_precise_svg_paint_in_its_intermediate_bitmap() {
	color := 'rgb(34 34 34 / 0.85098)'
	path := layout.PaintCommand{
		kind:          'draw_svg_path'
		color:         color
		opacity:       0.7
		group_opacity: 0.7
		svg_data:      &layout.PaintSVGPathData{
			path_data:            [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 16, 16, 0, 0, 0,
				0, 0, 0, 0, 0, 0]
			svg_solid_color_data: &layout.PaintSVGSolidColorData{
				fill_serialized: color
				fill:            css.Color{34, 34, 34, 217}
				has_fill:        true
				fill_alpha:      0.85
				has_fill_alpha:  true
				fill_srgb:       &layout.PaintSRGBColor{color, [f64(34.0 / 255), 34.0 / 255,
					34.0 / 255, 0.85]!}
			}
		}
	}
	for svg_graphics in [false, true] {
		layer := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 7, opacity: 0.7, svg_graphics_opacity: svg_graphics }
		commands := [
			layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: layer },
			path,
			layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: layer },
		]
		result := chromium_svg_folded_opacity(commands, [], 0)
		if svg_graphics {
			assert result or { -1.0 } == 0.7
		} else {
			assert result == none
		}
	}
}

fn test_ink_bounds_preserve_folded_svg_alpha_and_authored_clip_guards() {
	layer := &layout.PaintVisualLayer{
		kind:                   .css_effect
		scope_id:               9
		opacity:                .4
		svg_graphics_opacity:   true
		content_bounds_applied: true
	}
	begin := layout.PaintCommand{
		kind:              'begin_css_effect_layer'
		visual_layer_data: layer
		has_clip:          true
		clip_x:            9
		clip_y:            19
		clip_width:        22
		clip_height:       22
	}
	path := layout.PaintCommand{
		kind:          'draw_svg_path'
		color:         'red'
		opacity:       .4
		group_opacity: .4
		has_clip:      true
		clip_width:    100
		clip_height:   100
		svg_data:      &layout.PaintSVGPathData{
			path_data: [f32(0), 10, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 30, 40, 0, 0, 0, 0, 0, 0,
				0, 0, 0]
		}
	}
	end := layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: layer }
	assert (chromium_svg_folded_opacity([begin, path, end], [], 0) or { -1.0 }) == 0.4
	clipped := layout.PaintCommand{
		...begin
		visual_layer_data: &layout.PaintVisualLayer{
			...*layer
			clip_rect: layout.LayoutRect{0, 0, 20, 20}
		}
	}
	assert chromium_svg_folded_opacity([clipped, path, end], [], 0) == none
	untagged := layout.PaintCommand{
		...begin
		visual_layer_data: &layout.PaintVisualLayer{
			...*layer
			content_bounds_applied: false
		}
	}
	assert chromium_svg_folded_opacity([untagged, path, end], [], 0) == none
}
