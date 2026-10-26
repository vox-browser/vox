module layout

import css
import html

fn test_chromium_inward_rounded_outline_keeps_its_frame_and_focus_color_role() {
	for chromium in [false, true] {
		for automatic in [false, true] {
			box := BlockBox{
				x:                     20
				y:                     30
				width:                 88
				height:                32
				snaps_background_rect: chromium
				outline_color:         css.Color{112, 173, 70, 255}
				outline_style:         .solid
				outline_is_auto:       automatic
				decoration_data:       retained_block_box_decoration(BlockBoxDecorationData{
					border_radius:  8
					outline_width:  1
					outline_offset: -1
				})
			}
			commands := box.paint_commands()
			strokes := commands.filter(it.kind == 'paint_uniform_border')
			if !chromium {
				assert strokes.len == 0
				assert commands.any(it.kind == 'draw_svg_path')
				continue
			}
			assert strokes.len == 1
			stroke := strokes[0]
			assert [stroke.x, stroke.y, stroke.width, stroke.height] == [20.5, 30.5, 87.0, 31.0]
			assert stroke.corner_radii.top_left == CornerRadius{7.5, 7.5}
			assert stroke.stroke_width == 1
			assert stroke.force_dark_role == if automatic { .none_ } else { .border }
		}
	}
}

fn test_chromium_inline_rounded_outline_uses_the_same_stroke_and_keeps_dashed_fallback() {
	for style in ['solid', 'dashed'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}span{border-radius:8px;outline:1px ${style} green;outline-offset:-1px}
		</style><span>label</span>')
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 200)
		commands := root.paint_commands()
		strokes := commands.filter(it.kind == 'paint_uniform_border')
		if style == 'solid' {
			assert strokes.len == 1
			assert strokes[0].stroke_width == 1
			assert strokes[0].corner_radii.top_left == CornerRadius{7.5, 7.5}
		} else {
			assert strokes.len == 0
			assert commands.any(it.kind == 'draw_line' && it.line_style == 'dashed')
		}
		document.finalize()
	}
}
