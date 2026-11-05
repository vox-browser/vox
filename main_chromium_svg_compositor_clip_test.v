module main

import layout
import html
import os

fn compositor_clip_test_path(clip layout.PaintClip) layout.PaintCommand {
	return layout.PaintCommand{
		kind:        'draw_svg_path'
		color:       '#0d0d0d'
		has_clip:    true
		clip_x:      12
		clip_y:      20
		clip_width:  80
		clip_height: 40
		clip_list:   &layout.PaintClipList{ items: [clip] }
		svg_data:    &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	}
}

fn test_rounded_svg_clips_are_retained_by_compositors_and_rejected_by_scalar_batches() {
	path := compositor_clip_test_path(layout.PaintClip{
		rect:         layout.LayoutRect{12, 20, 80, 40}
		corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{20, 16} }
	})
	assert !chromium_svg_solid_path_supported(&path)
	assert chromium_svg_compositor_path_supported(&path)
	assert chromium_svg_solid_run_end([path, path], [], 0) == 0
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [0]
		}]
		command_layers: [1]
	}
	assert chromium_svg_compositor_layer_supported([path], plan, 1)
}

fn test_compositor_svg_eligibility_keeps_mask_transform_and_paint_fallbacks() {
	for clip in [layout.PaintClip{ is_path: true }, layout.PaintClip{ is_svg_mask: true },
		layout.PaintClip{ is_svg_content_mask: true },
		layout.PaintClip{ transform: [f64(1), .25, 0, 1, 0, 0]! },
		layout.PaintClip{ corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{-1, 2} } }] {
		path := compositor_clip_test_path(clip)
		assert !chromium_svg_compositor_path_supported(&path)
	}
	base := compositor_clip_test_path(layout.PaintClip{ rect: layout.LayoutRect{12, 20, 80, 40} })
	assert chromium_svg_solid_path_supported(&base)
	assert chromium_svg_compositor_path_supported(&base)
	for path in [layout.PaintCommand{ ...base, opacity: .5 },
		layout.PaintCommand{ ...base, group_opacity: .5 },
		layout.PaintCommand{ ...base, recording_clip: layout.LayoutRect{12, 20, 40, 40} },
		layout.PaintCommand{ ...base, stroke_color: '#000', stroke_width: 1 }] {
		assert !chromium_svg_compositor_path_supported(&path)
	}
}

fn test_rounded_clip_fixture_reaches_the_complete_compositor_recording() {
	source := os.read_file('Tests/Browser/Brave/input/compositor-rounded-svg-clip.html') or { panic(err) }
	mut document := html.parse_document(source)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	layout.enable_native_paint_tree_storage(document)
	layout.enable_native_static_svg_backgrounds(document)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing recording') })
	mut plan := layout.ChromiumRasterLayerPlan{}
	viewport := layout.LayoutRect{0, 0, 800, 600}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1, viewport, mut plan)
	mut count := 0
	for index, command in commands {
		if command.kind != 'draw_svg_path' || command.y < 250 { continue }
		owner := plan.command_layers[index]
		assert owner > 0, 'expected an isolated composer owner, got ${owner}'
		assert plan.layers[owner].composited_contents, 'composer owner ${owner} is not composited'
		assert chromium_svg_compositor_path_supported(&command)
		assert !plan.layers[owner].legacy_raster, 'owner ${owner} uses legacy raster'
		supported := chromium_svg_compositor_layer_supported_for_viewport(commands, plan, owner, viewport)
		if !supported {
			eprintln('fixture owner=${owner} indices=${plan.layers[owner].command_indices}')
			for ci in plan.layers[owner].command_indices {
				c := commands[ci]
				eprintln('fixture command=${ci} kind=${c.kind} opacity=${c.opacity} group=${c.group_opacity} blur=${c.blur}')
			}
		}
		assert supported
		count++
	}
	assert count == 2
}

fn test_compositor_identity_scopes_are_balanced_and_keep_real_effect_fallbacks() {
	path := compositor_clip_test_path(layout.PaintClip{
		rect:         layout.LayoutRect{12, 20, 80, 40}
		corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{20, 16} }
	})
	data := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 17, opacity: 1 }
	begin := layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: data }
	end := layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: data }
	commands := [begin, path, end]
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [0, 1, 2]
		}]
		command_layers: [1, 1, 1]
	}
	assert chromium_svg_identity_scope_end(commands, plan.command_layers, 0) == 3
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
	for unsupported in [&layout.PaintVisualLayer{ ...*data, scope_id: 19 },
		&layout.PaintVisualLayer{ ...*data, opacity: .5 },
		&layout.PaintVisualLayer{ ...*data, blend_mode: .multiply }] {
		changed := [begin, path, layout.PaintCommand{ ...end, visual_layer_data: unsupported }]
		assert chromium_svg_identity_scope_end(changed, plan.command_layers, 0) == 0
		assert !chromium_svg_compositor_layer_supported(changed, plan, 1)
	}
	assert chromium_svg_identity_scope_end(commands[..2], plan.command_layers[..2], 0) == 0
	assert chromium_svg_identity_scope_end(commands, [1, 1, 2], 0) == 0
}

fn test_svg_opacity_fixture_keeps_compositor_recording_after_ink_bounding() {
	source := os.read_file('Tests/Browser/Brave/input/forum-svg-single-paint-opacity.html') or { panic(err) }
	mut document := html.parse_document(source)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	layout.enable_native_paint_tree_storage(document)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing recording') })
	mut plan := layout.ChromiumRasterLayerPlan{}
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1, viewport, mut plan)
	mut paths := 0
	for index, command in commands {
		if command.kind != 'draw_svg_path' { continue }
		owner := plan.command_layers[index]
		assert owner > 0
		assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, owner, viewport)
		paths++
	}
	assert paths == 6
}
