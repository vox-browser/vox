module main

import html
import layout

fn test_translucent_uniform_border_pairs_only_its_outer_background_clip() {
	for shadows in ['none', '0 2px 8px #0001', '0 0 0 1px #0000000a,0 2px 8px #0000000a,0 4px 40px 8px #00000006'] {
	for clip in ['border-box', 'padding-box', 'content-box'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}div{position:absolute;left:40px;top:40px;width:700px;height:52px;
				box-sizing:border-box;border:1px solid #00000026;border-radius:28px;
				background:white;background-clip:${clip};padding:3px;box-shadow:${shadows}}
		</style><div></div>')
		document.set_font_rendering_policy(.chromium)
		root := layout.layout_document_typed_in_viewport(document, 800, 600)
		commands := root.paint_commands()
		borders := commands.filter(it.kind == 'paint_uniform_border')
		backgrounds := commands.filter(it.kind == 'fill_rect' && it.radius > 0)
		assert borders.len == 1 && backgrounds.len == 1
		border := borders[0]
		background := backgrounds[0]
		assert background.underlays_next == (clip == 'border-box')
		assert chromium_uniform_border_shares_outer_clip(&border, &background) == (clip == 'border-box')
		// The inverse path belongs to the offscreen ClipLayer; it must not
		// select MSAA for unrelated shapes in the parent raster tile.
		assert chromium_msaa_triggers(commands).len == 0
		mut hidden := commands.clone()
		for i, command in hidden {
			if command.kind == 'paint_uniform_border' {
				hidden[i] = layout.PaintCommand{...command,has_clip:true,clip_width:0,clip_height:20}
			}
		}
		assert chromium_msaa_triggers(hidden).len == 0
		assert !chromium_uniform_border_shares_outer_clip(&border,
			&layout.PaintCommand{...background, x: background.x + 1})
		document.finalize()
	}
	}
}

fn test_uniform_border_outer_clip_requires_matching_circular_geometry() {
	background := layout.PaintCommand{kind:'fill_rect',x:10,y:20,width:100,height:40,radius:6}
	border := layout.PaintCommand{kind:'paint_uniform_border',x:10.5,y:20.5,width:99,height:39,
		stroke_width:1,corner_radii:layout.BoxRadii{
			top_left:layout.CornerRadius{5.5,5.5},top_right:layout.CornerRadius{5.5,5.5},
			bottom_right:layout.CornerRadius{5.5,5.5},bottom_left:layout.CornerRadius{5.5,5.5}}}
	assert chromium_uniform_border_shares_outer_clip(&border, &background)
	for changed in [
		layout.PaintCommand{...border, stroke_width:0},
		layout.PaintCommand{...border, kind:'stroke_rounded_rect'},
		layout.PaintCommand{...border, corner_radii:layout.BoxRadii{top_left:layout.CornerRadius{5.5,4.5}}},
	] { assert !chromium_uniform_border_shares_outer_clip(&changed, &background) }
	assert !chromium_uniform_border_shares_outer_clip(&border,
		&layout.PaintCommand{...background,radius:0})
}
