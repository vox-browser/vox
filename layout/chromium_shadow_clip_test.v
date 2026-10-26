module layout

import css
import dom
import html

fn opaque_shadow_test_commands(chromium bool, alpha u8, size f64) []PaintCommand {
	box := BlockBox{
		x:                     10
		y:                     20
		width:                 size
		height:                size
		snaps_background_rect: chromium
		background_color:      css.Color{255, 221, 170, alpha}

		decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
			background_color_clip: 'border-box'
			border_radius:         3
			shadows:               [
			BoxShadow{
				offset_x: 2
				offset_y: 2
				blur:     5
				color:    css.Color{136, 136, 136, 255}
			},
		]
		})
	}
	return box.paint_commands()
}

fn test_opaque_chromium_shadow_paints_before_background_with_inset_cutout() {
	commands := opaque_shadow_test_commands(true, 255, 50)
	mut shadow_index := -1
	mut background_index := -1
	for index, command in commands {
		if command.kind == 'paint_outer_box_shadow' { shadow_index = index }
		if command.kind == 'fill_rect' { background_index = index }
	}
	assert shadow_index >= 0 && background_index > shadow_index
	shadow := commands[shadow_index]
	geometry := shadow.box_shadow()
	assert geometry.content_rect == LayoutRect{11, 21, 48, 48}
	assert geometry.content_radii.top_left == CornerRadius{2, 2}
	assert shadow.x == 12 && shadow.y == 22 && shadow.width == 50 && shadow.height == 50
	for pair in [[0, 255], [1, 128]] {
		fallback := opaque_shadow_test_commands(pair[0] == 1, u8(pair[1]), 50)
		original := fallback.filter(it.kind == 'paint_outer_box_shadow')[0].box_shadow()
		assert original.content_rect == LayoutRect{10, 20, 50, 50}
	}
	// An opaque 1px box has an empty cutout, which is still a valid shadow.
	tiny :=
		opaque_shadow_test_commands(true, 255, 1).filter(it.kind == 'paint_outer_box_shadow')[0].box_shadow()
	assert tiny.content_rect.width == 0 && tiny.content_rect.height == 0
}

fn test_opaque_shadow_cutouts_keep_one_css_pixel_in_device_layout() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}.shadow{background:#def;border-radius:8px;box-shadow:0 0 5px #0004}
			div{position:absolute;left:20px;top:30px;width:40px;height:30px}
			span{font:16px Arial}
		</style><div class="shadow"></div><span class="shadow">Inline shadow</span>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		for scale in [1.0, 1.5, 2.0] {
			document.set_layout_coordinate_scale(scale)
			root := layout_document_typed_in_viewport(document, 300, 150)
			shadows := root.paint_commands().filter(it.kind == 'paint_outer_box_shadow')
			assert shadows.len == 2
			for shadow in shadows {
				clip := shadow.box_shadow().content_rect
				inset := if policy == .chromium { scale } else { 0.0 }
				assert clip.x == shadow.x + inset
				assert clip.y == shadow.y + inset
				assert clip.width == shadow.width - 2 * inset
				assert clip.height == shadow.height - 2 * inset
				assert shadow.box_shadow().content_radii.top_left.x == shadow.corner_radii.top_left.x - inset
			}
		}
	}
}
