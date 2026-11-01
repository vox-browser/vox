module main

import dom
import layout
import painting
import math

fn shadow_picture_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices: [1, 2, 3]
		}]
		command_layers: [0, 1, 1, 1, 0]
	}
}

fn shadow_picture_commands() []layout.PaintCommand {
	shadow := layout.PaintCommand{
		kind: 'paint_outer_box_shadow'
		x: 10
		y: 10
		width: 120
		height: 80
		blur: 20
		box_shadow_data: &layout.PaintBoxShadowData{
			content_rect: layout.LayoutRect{15, 15, 110, 70}
		}
	}
	return [layout.PaintCommand{kind: 'fill_rect'}, shadow,
		layout.PaintCommand{kind: 'fill_rect', width: 120, height: 80}, layout.PaintCommand{kind: 'draw_text', text: 'Layer'},
		layout.PaintCommand{kind: 'fill_rect'}]
}

fn test_complete_shadow_picture_records_ordinary_shadow_and_rechecks_video_inputs() {
	mut commands := shadow_picture_commands()
	plan := shadow_picture_test_plan()
	assert chromium_complete_outer_shadow_supported(unsafe { &commands[1] })
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
	commands[2] = layout.PaintCommand{kind: 'draw_video', video_representation: .transparent_black}
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
	commands[2].video_bitmap = &dom.Bitmap_{}
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
	commands[2].video_bitmap = none
	commands[2].video_frame_source = &painting.VideoFrameSource{}
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
	commands[2].video_frame_source = none
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
}

fn test_complete_shadow_picture_rejects_invalid_geometry_and_legacy_shadow_state() {
	commands := shadow_picture_commands()
	base := commands[1]
	for changed in [
		layout.PaintCommand{...base, blur: math.nan()},
		layout.PaintCommand{...base, blur: -1},
		layout.PaintCommand{...base, width: 0},
		layout.PaintCommand{...base, outer_shadow: true},
		layout.PaintCommand{...base, box_shadow_data: unsafe { nil }},
		layout.PaintCommand{...base, box_shadow_data: &layout.PaintBoxShadowData{}},
		layout.PaintCommand{...base, clip_outs: [f64(0), 0, 10, 10]},
	] {
		assert !chromium_complete_outer_shadow_supported(&changed)
	}
	mut translucent := commands.clone()
	translucent[1].opacity = .5
	assert !chromium_svg_compositor_layer_supported(translucent, shadow_picture_test_plan(), 1)
}
