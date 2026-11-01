module main

import layout

fn test_contoured_background_follows_the_border_coordinate_space() {
	background := layout.PaintCommand{
		kind:              'fill_rect'
		width:             738
		height:            50
		radius:            25
		local_border_data: &layout.PaintLocalBorderData{
			shape_border_rect: layout.LayoutRect{-1, -1, 740, 52}
		}
	}
	border := layout.PaintCommand{
		kind:              'paint_uniform_border'
		local_border_data: &layout.PaintLocalBorderData{
			shape_border_rect: layout.LayoutRect{272, 354, 740, 52}
		}
	}
	rect := contoured_background_in_border_space(&background, &border)
	assert rect[..4] == [f32(273), 355, 738, 50]
	assert rect[4..] == [f32(25), 25, 25, 25, 25, 25, 25, 25]
	plain := layout.PaintCommand{ kind: 'fill_rect', x: 12.125, y: 18.5, width: 80, height: 30, radius: 8 }
	assert contoured_background_in_border_space(&plain, &border)[..4] == [f32(12.125), 18.5, 80,
		30]
}

fn test_contoured_rect_keeps_each_elliptical_corner() {
	command := layout.PaintCommand{
		kind:         'fill_rounded_rect'
		x:            1
		y:            2
		width:        80
		height:       50
		corner_radii: layout.BoxRadii{
			top_left:     layout.CornerRadius{3, 4}
			top_right:    layout.CornerRadius{5, 6}
			bottom_right: layout.CornerRadius{7, 8}
			bottom_left:  layout.CornerRadius{9, 10}
		}
	}
	assert contoured_box_rect(&command) == [f32(1), 2, 80, 50, 3, 4, 5, 6, 7, 8, 9, 10]!
}

fn test_contoured_reference_retains_border_geometry_for_shadow_insets() {
	data := layout.PaintLocalBorderData{
		shape_border_rect:  layout.LayoutRect{40, 240, 700, 52}
		shape_border_radii: layout.BoxRadii{
			top_left:     layout.CornerRadius{26, 26}
			top_right:    layout.CornerRadius{26, 26}
			bottom_right: layout.CornerRadius{26, 26}
			bottom_left:  layout.CornerRadius{26, 26}
		}
	}
	assert contoured_box_reference(&data) == [f32(40), 240, 700, 52, 26, 26, 26, 26, 26, 26, 26,
		26]!
}

fn test_contoured_shadows_and_outer_border_clips_mark_parent_tiles() {
	data := &layout.PaintLocalBorderData{ corner_shapes: [f64(1.1), 1.1, 1.1, 1.1]! }
	shadow := layout.PaintCommand{
		kind:              'paint_outer_box_shadow'
		x:                 39
		y:                 239
		width:             702
		height:            54
		corner_radii:      layout.BoxRadii{ top_left: layout.CornerRadius{27, 27} }
		local_border_data: data
	}
	assert chromium_msaa_tiles([shadow], 1, 256) == [0, 1]
	for unsupported in [layout.PaintCommand{ ...shadow, blur: 8 },
		layout.PaintCommand{ ...shadow, corner_radii: layout.BoxRadii{} },
		layout.PaintCommand{ ...shadow, local_border_data: unsafe { nil } }, layout.PaintCommand{
			...shadow
			local_border_data: &layout.PaintLocalBorderData{
				corner_shapes: [
					f64(-1),
					-1,
					-1,
					-1,
				]!
			}
		}] {
		assert chromium_msaa_triggers([unsupported]).len == 0
	}
	border := layout.PaintCommand{
		kind:              'paint_uniform_border'
		x:                 40
		y:                 40
		width:             700
		height:            52
		stroke_width:      1
		corner_radii:      layout.BoxRadii{ top_left: layout.CornerRadius{28, 20} }
		local_border_data: data
	}
	assert chromium_msaa_triggers([border]).len == 1
	assert chromium_msaa_triggers([layout.PaintCommand{ ...border, local_border_data: unsafe { nil } }]).len == 1
}

fn test_contoured_decorations_record_together_in_root_and_compositor_layers() {
	data := &layout.PaintLocalBorderData{ corner_shapes: [f64(1.1), 1.1, 1.1, 1.1]! }
	shadow := layout.PaintCommand{
		kind:              'paint_outer_box_shadow'
		x:                 32
		y:                 232
		width:             716
		height:            68
		blur:              80
		local_border_data: data
		box_shadow_data:   &layout.PaintBoxShadowData{ content_rect: layout.LayoutRect{41, 241, 698, 50} }
	}
	background := layout.PaintCommand{ kind: 'fill_rect', x: 41, y: 241, width: 698, height: 50, radius: 25, local_border_data: data }
	border := layout.PaintCommand{ kind: 'paint_uniform_border', x: 40.5, y: 240.5, width: 699, height: 51, local_border_data: data }
	commands := [shadow, background, border]
	supported, vectors := chromium_shared_recording_leaf_supported(&shadow)
	assert supported && vectors
	root := layout.ChromiumRasterLayerPlan{ layers: [layout.ChromiumRasterLayer{}], command_layers: [
		0,
		0,
		0,
	] }
	assert chromium_shared_recording_supported(commands, root)
	child := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [0, 1, 2]
		}]
		command_layers: [1, 1, 1]
	}
	assert chromium_svg_compositor_layer_supported(commands, child, 1)
	for unsupported in [layout.PaintCommand{ ...shadow, local_border_data: unsafe { nil } },
		layout.PaintCommand{ ...shadow, box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...shadow, blur: -1 }] {
		accepted, _ := chromium_shared_recording_leaf_supported(&unsupported)
		assert !accepted
		assert !chromium_shared_recording_supported([unsupported, background, border], root)
		assert !chromium_svg_compositor_layer_supported([unsupported, background, border], child, 1)
	}
}
