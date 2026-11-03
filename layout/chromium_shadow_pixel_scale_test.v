module layout

import css
import html

fn test_retained_outer_shadows_follow_display_density_in_css_coordinates() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}div{position:absolute;left:20.25px;top:20.25px;width:140.5px;height:40.5px;
		background:white;border-radius:8.25px;box-shadow:.25px .75px 3.25px .25px #0004}
	</style><div></div><svg width="1" height="1"></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for density in [f64(1), 2, 1] {
		document.set_display_device_pixel_ratio(density)
		coordinates := 1.0
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		shadows := commands.filter(it.kind == 'paint_outer_box_shadow')
		assert shadows.len == 1
		shadow := shadows[0]
		assert shadow.x / coordinates == if density == 2 { 20.5 } else { 20.0 }
		assert shadow.y / coordinates == 21
		assert shadow.width == 141
		assert shadow.blur / coordinates == if density == 2 { 3.25 } else { 3.0 }
		assert shadow.corner_radii.top_left.x / coordinates == if density == 2 {
			8.5
		} else {
			8.0
		}
		clip := shadow.box_shadow().content_rect
		assert clip.x / coordinates == if density == 2 { 21.5 } else { 21.0 }
		assert clip.width / coordinates == if density == 2 { 138.5 } else { 139.0 }
	}
}

fn test_shadow_spread_keeps_fractional_radii_and_small_corner_correction() {
	assert chromium_shadow_spread_radius(8.25, 0.25) == 8.5
	assert chromium_shadow_spread_radius(8.25, -1.25) == 7
	assert chromium_shadow_spread_radius(0, 4) == 0
	assert chromium_shadow_spread_radius(2, 4) == 5.5
	assert chromium_shadow_spread_radius(2, -4) == 0
}

fn test_outer_shadow_device_path_preserves_inset_fallback_and_paint_order() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	result := document_layout_result(document) or { panic('layout') }
	mut commands := []PaintCommand{}
	paintable_box_paint_box_shadow_for_node(mut commands, [
		BoxShadow{ blur: 3.25, color: css.Color{10, 20, 30, 128} },
		BoxShadow{ inset: true, blur: 3.25, color: css.Color{40, 50, 60, 128} },
	], BoxEdges{}, BoxColors{}, BoxBorderStyles{}, BoxRadii{},
		LayoutRect{20.25, 30.25, 80.5, 40.5}, LayoutRect{20.25, 30.25, 80.5, 40.5}, 0.75, voidptr(result.root))
	assert commands.len == 2
	assert commands[0].kind == 'paint_inner_box_shadow' && commands[0].blur == 3
	assert commands[1].kind == 'paint_outer_box_shadow' && commands[1].blur == 3.25
	assert commands[0].opacity == 0.75 && commands[1].opacity == 0.75
	assert commands[1].box_shadow().content_rect == LayoutRect{20.5, 30.5, 80.5, 40.5}
}

fn test_libweb_outer_shadows_keep_the_original_integer_geometry() {
	mut document := html.parse_document('<!doctype html><style>
 body{margin:0}div{width:140.5px;height:40.5px;border-radius:8.25px;
 box-shadow:.25px .75px 3.25px .25px #0004}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.libweb)
	document.set_display_device_pixel_ratio(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	shadows := commands.filter(it.kind == 'paint_outer_box_shadow')
	assert shadows.len == 1 && shadows[0].blur == 3
	assert shadows[0].x == 0 && shadows[0].y == 1
	assert shadows[0].corner_radii.top_left == CornerRadius{8, 8}
}
