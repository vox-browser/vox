// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

// Ladybird 6852ca42e970c1ecda7ac48ce17a2ca3622aee3f.
fn test_local_background_uses_scrollable_area_and_preserves_origin_insets() {
	for origin in ['padding-box', 'content-box', 'border-box'] {
		box := BlockBox{
			x: 30
			y: 40
			width: 100
			height: 80
			padding: BoxEdges{top: 10, right: 10, bottom: 10, left: 10}
			border: BoxEdges{top: 2, right: 2, bottom: 2, left: 2}
			has_scrollable_overflow: true
			scrollable_overflow: LayoutRect{20, 30, 320, 600}
			decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
				background_images: [BackgroundImageLayer{
					url: 'local.png'
					attachment: 'local'
					origin: origin
					clip: 'padding-box'
				}]
			})
		}
		command := box.paint_commands().filter(it.kind == 'draw_background_image')[0]
		inset := if origin == 'content-box' { 10.0 } else if origin == 'border-box' { -2.0 } else { 0.0 }
		assert command.x == 20 + inset
		assert command.y == 30 + inset
		assert command.width == 320 - 2 * inset
		assert command.height == 600 - 2 * inset
		assert command.image().image_clip_x == 20
		assert command.image().image_clip_y == 30
		assert command.image().image_clip_width == 120
		assert command.image().image_clip_height == 100
	}
}

fn test_local_background_does_not_expand_visible_overflow_or_viewport_backgrounds() {
	for viewport in [false, true] {
		box := BlockBox{
			width: 100
			height: 80
			has_scrollable_overflow: viewport
			is_viewport_scroller: viewport
			scrollable_overflow: LayoutRect{0, 0, 300, 600}
			decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
				background_images: [BackgroundImageLayer{
					url: 'local.png'
					attachment: 'local'
					origin: 'padding-box'
				}]
			})
		}
		command := box.paint_commands().filter(it.kind == 'draw_background_image')[0]
		assert command.width == 100
		assert command.height == 80
	}
}
