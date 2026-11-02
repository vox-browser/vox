module main

import html
import layout
import os

fn test_elliptical_border_shares_msaa_with_other_boxes_in_its_tiles() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/diagnostic/inset-rounded-box-shadow.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	triggers := chromium_msaa_triggers(commands)
	assert triggers.len == 1
	assert commands[triggers[0].command_index].kind == 'paint_uniform_border'
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 1, 256) == [0, 1]
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 2, 256) == [1, 2]
}

fn test_circular_and_square_uniform_borders_keep_analytic_tile_coverage() {
	for radius in [0.0, 12.5] {
		r := layout.CornerRadius{radius, radius}
		command := layout.PaintCommand{
			kind: 'paint_uniform_border'
			x: 48.5
			y: 43.5
			width: 299
			height: 129
			stroke_width: 1
			corner_radii: layout.BoxRadii{r, r, r, r}
		}
		assert chromium_msaa_triggers([command]).len == 0
	}
}

fn test_partial_rounded_border_clips_share_the_parent_tile_msaa_mode() {
	command := layout.PaintCommand{
		kind: 'paint_partial_rounded_border'
		x: 701
		y: 92
		width: 298
		height: 560
		points: [0.0, 1.0, 1.0, 1.0]
		corner_radii: layout.BoxRadii{layout.CornerRadius{}, layout.CornerRadius{10,10}, layout.CornerRadius{}, layout.CornerRadius{10,10}}
	}
	triggers := chromium_msaa_triggers([command])
	assert triggers.len == 1
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 1, 256) == [0, 1, 2]
}
