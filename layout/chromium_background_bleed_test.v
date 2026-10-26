module layout

import html
import css

fn test_chromium_background_image_shrinks_its_clip_without_changing_tile_origin() {
	for clip in ['border-box', 'padding-box'] {
		for color in ['#444', 'rgba(68,68,68,.5)'] {
			mut document := html.parse_document('<!doctype html><style>
				html,body{margin:0}div{position:absolute;left:31px;top:31px;
				width:99px;height:38px;border:1px solid ${color};border-radius:3px;
				background:white url(pattern.png) repeat 1px 1px;background-clip:${clip}}
			</style><div></div>')
			document.set_font_rendering_policy(.chromium)
			document.set_layout_coordinate_scale(2)
			root := layout_document_typed_in_viewport(document, 800, 600)
			commands := root.paint_commands().filter(it.kind == 'draw_background_image')
			assert commands.len == 1
			command := commands[0]
			image := command.image()
			// background-origin remains the padding box for every clip mode.
			assert [command.x, command.y, command.width, command.height] == [64.0, 64.0, 198.0,
				76.0]
			inset := if clip == 'padding-box' {
				2.0
			} else if color == '#444' {
				1.0
			} else {
				0.0
			}
			assert [image.image_clip_x, image.image_clip_y, image.image_clip_width,
				image.image_clip_height] ==
				[62.0 + inset, 62.0 + inset, 202.0 - 2 * inset, 80.0 - 2 * inset]
			assert image.image_clip_radii.top_left == CornerRadius{6 - inset, 6 - inset}
			if clip == 'border-box' {
				destination := image.background_image_destination or { panic('missing image destination') }
				assert destination == if color == '#444' {
					LayoutRect{64, 64, 198, 76}
				} else {
					LayoutRect{62, 62, 202, 80}
				}
			} else {
				assert image.background_image_destination == none
			}
			document.finalize()
		}
	}
}

fn test_chromium_background_image_obscured_edges_are_independent() {
	rect := LayoutRect{10, 20, 100, 50}
	border := BoxEdges{ top: 2, right: 4, bottom: 3, left: 6 }
	colors := BoxColors{
		top:    css.Color{ r: 0, g: 0, b: 0, a: 255 }
		right:  css.Color{ a: 128 }
		bottom: css.Color{ a: 255 }
		left:   css.Color{ a: 255 }
	}
	styles := BoxBorderStyles{ top: .solid, right: .solid, bottom: .dashed, left: .double }
	assert chromium_background_image_destination(rect, border, colors, styles) == LayoutRect{10, 22, 100, 48}
	// A narrow double edge uses the solid effective style.
	assert chromium_background_image_destination(rect, BoxEdges{ left: 2 }, colors, styles) == LayoutRect{12, 20, 98, 50}
}

fn test_chromium_background_image_color_shares_only_a_matching_rounded_clip() {
	for clip in ['border-box', 'padding-box'] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}span{font:12px Verdana;line-height:20px}
			a{border:1px solid #444;padding:1px 6px;border-radius:3px;
			background:white url(pattern.png) repeat;background-clip:${clip};font:bold 10px Verdana}
		</style><span><a>join</a></span>')
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(2)
		root := layout_document_typed_in_viewport(document, 800, 600)
		commands := root.paint_commands()
		mut found := false
		for index, command in commands {
			if command.kind != 'draw_background_image' { continue }
			assert index > 0
			assert commands[index - 1].kind == 'fill_rect'
			assert commands[index - 1].underlays_next == (clip == 'border-box')
			assert background_image_border_can_share_pass(command, commands[index + 1])
			assert !background_image_border_can_share_pass(command, PaintCommand{
				...commands[index + 1]
				transform: [1.0, 0, 0, 1, 1, 0]!
			})
			assert !background_image_border_can_share_pass(command, PaintCommand{
				...commands[index + 1]
				has_clip: true
			})
			found = true
		}
		assert found
		document.finalize()
	}
}
