module layout

import dom
import html

fn test_chromium_outer_shadows_preserve_fractional_parameters_at_unit_density() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for density in [f64(1), 2] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:10.25px;top:20.25px;width:9px;height:20px;border-radius:50%;box-shadow:.25px .5px .75px 1.25px #111}</style><div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			document.set_display_device_pixel_ratio(density)
			root := layout_document_typed_in_viewport(document, 100, 100)
			shadows := root.paint_commands().filter(it.kind == 'paint_outer_box_shadow')
			assert shadows.len == 1
			shadow := shadows[0]
			geometry := shadow.box_shadow()
			if policy == .chromium {
				assert shadow.width == 11.5 && shadow.height == 22.5
				assert shadow.blur == 0.75
				assert shadow.corner_radii.top_left == CornerRadius{5.75, 11.25}
				assert geometry.content_radii.top_left == CornerRadius{4.5, 10}
				if density == 1 {
					assert shadow.x == 9 && shadow.y == 19.25
					assert geometry.content_rect == LayoutRect{10, 20, 9, 20}
				} else {
					assert shadow.x == 9.5 && shadow.y == 19.75
					assert geometry.content_rect == LayoutRect{10.5, 20.5, 9, 20}
				}
			} else {
				assert shadow.x == 9 && shadow.y == 20
				assert shadow.width == 11 && shadow.height == 22
				assert shadow.blur == 1
				assert shadow.corner_radii.top_left == CornerRadius{5, 11}
				assert geometry.content_radii.top_left == CornerRadius{4, 10}
			}
		}
	}
}
