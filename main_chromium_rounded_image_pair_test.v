module main

import layout
import painting
import html
import os

fn rounded_image_pair_commands() []layout.PaintCommand {
	radius := painting.BorderRadiusData{8, 8}
	return [
		layout.PaintCommand{
			kind:   'fill_rect'
			x:      24
			y:      88
			width:  464
			height: 261
			radius: 8
			color:  '#f5f3f5'
		},
		layout.PaintCommand{
			kind:            'draw_replaced_image'
			x:               24
			y:               88
			width:           464
			height:          261
			image_paintable: &painting.ImagePaintable{
				image_rect:   painting.Rect{24, 88, 464, 261}
				border_radii: painting.BorderRadiiData{radius, radius, radius, radius}
			}
		},
	]
}

fn test_rounded_image_pair_requires_root_ownership_and_matching_geometry() {
	commands := rounded_image_pair_commands()
	assert chromium_rounded_image_pair_end(commands, [0, 0], 0) == 2
	assert chromium_rounded_image_pair_end(commands, [], 0) == 0
	assert chromium_rounded_image_pair_end(commands, [1, 1], 0) == 0
	assert chromium_rounded_image_pair_end(commands, [0, 1], 0) == 0
	assert chromium_rounded_image_pair_end(commands[..1], [0], 0) == 0
	assert chromium_rounded_image_pair_end(commands, [0, 0], -1) == -1
	for i in 0 .. 2 {
		for changed in [layout.PaintCommand{ ...commands[i], opacity: .5 },
			layout.PaintCommand{ ...commands[i], group_opacity: .5 },
			layout.PaintCommand{ ...commands[i], fixed_to_viewport: true },
			layout.PaintCommand{ ...commands[i], blur: 2 },
			layout.PaintCommand{ ...commands[i], outer_shadow: true },
			layout.PaintCommand{ ...commands[i], transform: [f64(1), 0, 0, 1, 1, 0]! }] {
			mut copy := commands.clone()
			copy[i] = changed
			assert chromium_rounded_image_pair_end(copy, [0, 0], 0) == 0
		}
	}
	for changed in [layout.PaintCommand{ ...commands[0], x: 25 },
		layout.PaintCommand{ ...commands[0], radius: 7 },
		layout.PaintCommand{ ...commands[0], color: '#f5f3f580' },
		layout.PaintCommand{ ...commands[0], underlays_next: true }] {
		assert chromium_rounded_image_pair_end([changed, commands[1]], [0, 0], 0) == 0
	}
	float_color := layout.PaintCommand{
		...commands[0]
		srgb_color_data: &layout.PaintSRGBColor{
			serialized: '#f5f3f5'
			components: [f64(245.5) / 255, f64(243) / 255, f64(245) / 255, f64(1)]!
		}
	}
	assert chromium_rounded_image_pair_end([float_color, commands[1]], [0, 0], 0) == 0
	forced := layout.PaintCommand{ ...commands[1], apply_force_dark_to_image: true }
	assert chromium_rounded_image_pair_end([commands[0], forced], [0, 0], 0) == 0
}

fn test_rounded_image_pair_preserves_fractional_device_snapping_and_clip_rejections() {
	commands := rounded_image_pair_commands()
	radius := layout.CornerRadius{8, 8}
	radii := layout.BoxRadii{radius, radius, radius, radius}
	paintable := commands[1].image_paintable or { panic('paintable') }
	bg := layout.PaintCommand{ ...commands[0], x: 24, y: 741, width: 293, height: 165 }
	image := layout.PaintCommand{
		...commands[1]
		x:               24
		y:               740.796875
		width:           293.328125
		height:          164.984375
		has_clip:        true
		clip_x:          24
		clip_y:          740.796875
		clip_width:      293.328125
		clip_height:     164.984375
		clip_list:       &layout.PaintClipList{
			items: [layout.PaintClip{
				rect:         layout.LayoutRect{24, 740.796875, 293.328125, 164.984375}
				corner_radii: radii
			}]
		}
		image_paintable: &painting.ImagePaintable{
			...*paintable
			image_rect: painting.Rect{24, 740.796875, 293.328125, 164.984375}
		}
	}
	assert chromium_rounded_image_pair_end([bg, image], [0, 0], 0) == 2
	for clip in [layout.PaintClip{ is_path: true }, layout.PaintClip{ is_svg_mask: true },
		layout.PaintClip{ is_svg_content_mask: true },
		layout.PaintClip{ rect: layout.LayoutRect{25, 741, 292, 165} }, layout.PaintClip{
			rect:         layout.LayoutRect{24, 741, 293, 165}
			corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{7, 7} }
		}] {
		changed := layout.PaintCommand{ ...image, clip_list: &layout.PaintClipList{ items: [clip] } }
		assert chromium_rounded_image_pair_end([bg, changed], [0, 0], 0) == 0
	}
}

fn test_rounded_image_fixture_selects_its_visible_root_pairs() {
	source := os.read_file(os.join_path(@DIR, 'Tests/Browser/Brave/diagnostic/rounded-image-background-msaa.html'))!
	mut document := html.parse_document(source)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		layout.LayoutRect{0, 0, 1024, 768}, mut plan)
	mut selected := 0
	mut non_root := 0
	for i in 0 .. commands.len - 1 {
		if commands[i + 1].kind != 'draw_replaced_image' { continue }
		end := chromium_rounded_image_pair_end(commands, plan.command_layers, i)
		if end == i + 2 {
			selected++
			continue
		}
		// The partly offscreen last card has an independent raster owner.
		assert plan.command_layers[i] != 0
		non_root++
	}
	assert selected == 3
	assert non_root == 1
}
