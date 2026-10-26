module layout

import html
import dom

fn test_chromium_outer_shadow_colors_retain_fractional_components_in_paint_order() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			div{width:40px;height:30px;box-shadow:1px 2px 5px rgb(10.5 20.25 30.75 / 25%),
			inset 9px 9px 4px rgb(90.5 100.25 110.75 / 60%),
			3px 4px 8px rgb(50.5 60.25 70.75 / 40%)}
		</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		root := layout_document_typed_in_viewport(document, 200, 100)
		commands := root.paint_commands().filter(it.kind == 'paint_outer_box_shadow')
		assert commands.len == 2
		for index, command in commands {
			if policy == .libweb {
				assert command.srgb_color_data == unsafe { nil }
				continue
			}
			data := command.srgb_color_data
			assert data != unsafe { nil }
			assert data.serialized == command.color
			expected := if index == 0 {
				[50.5 / 255, 60.25 / 255, 70.75 / 255, 0.4]!
			} else {
				[10.5 / 255, 20.25 / 255, 30.75 / 255, 0.25]!
			}
			assert data.components == expected
		}
	}
}
