module main

import layout
import dom
import painting

fn test_stationary_raster_skips_initial_frame_without_a_document() {
	app := BrowserApp{}
	assert !app.begin_stationary_document_raster()
}

fn test_stationary_raster_excludes_independently_updated_content() {
	ordinary := [layout.PaintCommand{kind: 'fill_rect'},
		layout.PaintCommand{kind: 'draw_replaced_image'},
		layout.PaintCommand{kind: 'draw_svg_path'}]
	assert stationary_document_raster_eligible(ordinary)
	for kind in ['draw_canvas', 'draw_nested_document'] {
		mut commands := ordinary.clone()
		commands << layout.PaintCommand{kind: kind}
		assert !stationary_document_raster_eligible(commands), kind
	}
}

fn test_stationary_raster_reuses_static_nested_snapshots_and_empty_video() {
	commands := [layout.PaintCommand{
		kind: 'paint_nested_display_list'
		nested_viewport_commands: [layout.PaintCommand{kind: 'draw_svg_path'},
			layout.PaintCommand{kind: 'draw_video', video_representation: .transparent_black}]
	}]
	assert stationary_document_raster_eligible(commands)
	for live in [layout.PaintCommand{kind: 'draw_canvas'},
		layout.PaintCommand{kind: 'draw_nested_document'},
		layout.PaintCommand{kind: 'draw_video', video_frame_source: &painting.VideoFrameSource{}},
		layout.PaintCommand{kind: 'draw_video', video_bitmap: &dom.Bitmap_{}}] {
		assert !stationary_document_raster_eligible([live])
		assert !stationary_document_raster_eligible([layout.PaintCommand{
			kind: 'paint_nested_display_list'
			nested_viewport_commands: [layout.PaintCommand{
				kind: 'paint_nested_display_list'
				nested_viewport_commands: [live]
			}]
		}])
	}
}

fn test_stationary_raster_limits_nested_snapshot_depth() {
	mut commands := [layout.PaintCommand{kind: 'draw_svg_path'}]
	for _ in 0 .. 32 {
		commands = [layout.PaintCommand{kind: 'paint_nested_display_list', nested_viewport_commands: commands}]
	}
	assert stationary_document_raster_eligible(commands)
	commands = [layout.PaintCommand{kind: 'paint_nested_display_list', nested_viewport_commands: commands}]
	assert !stationary_document_raster_eligible(commands)
}
