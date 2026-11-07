module main

import layout
import css
import html
import os
import platform
import painting

fn test_disjoint_parent_spans_can_surround_a_complete_bounded_svg_mask() {
	base := compositor_gap_test_commands()
	mask := &layout.PaintVisualLayer{kind: .svg_mask, scope_id: 47}
	commands := [base[0], base[1],
		layout.PaintCommand{kind: 'begin_svg_mask_layer', visual_layer_data: mask},
		base[2],
		layout.PaintCommand{kind: 'end_svg_mask_layer', visual_layer_data: mask},
		base[3], base[4]]
	plan := layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers: [layout.ChromiumRasterLayer{},
			layout.ChromiumRasterLayer{composited_contents: true, command_indices: [1,5]},
			layout.ChromiumRasterLayer{legacy_raster: true, command_indices: [2,3,4]}]
		command_layers: [0,1,2,2,2,1,0]
	}
	viewport := layout.LayoutRect{0,0,200,120}
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 5, viewport)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, viewport)
	mut offscreen_backdrop := commands.clone()
	offscreen_backdrop[3] = layout.PaintCommand{kind: 'apply_backdrop_filter',
		x: 0, y: 4000, width: 100, height: 20}
	assert chromium_compositor_gap_can_flush_parent(offscreen_backdrop, plan, 1, 2, 5, viewport)
	for replacement in [layout.PaintCommand{...base[2], y: 79},
		layout.PaintCommand{kind: 'apply_backdrop_filter', y: 35, width: 100, height: 10},
		layout.PaintCommand{kind: 'draw_text', text: 'unbounded mask content'},
		layout.PaintCommand{...base[2], fixed_to_viewport: true}] {
		mut changed := commands.clone()
		changed[3] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 5, viewport)
	}
	mut foreign := layout.ChromiumRasterLayerPlan{...plan,
		layers: plan.layers.clone(), command_layers: plan.command_layers.clone()}
	foreign.command_layers[3] = 0
	assert !chromium_compositor_gap_can_flush_parent(commands, foreign, 1, 2, 5, viewport)
	mut unbalanced := commands.clone()
	unbalanced[4] = layout.PaintCommand{kind: 'end_svg_mask_layer',
		visual_layer_data: &layout.PaintVisualLayer{kind: .svg_mask, scope_id: 48}}
	assert !chromium_compositor_gap_can_flush_parent(unbalanced, plan, 1, 2, 5, viewport)
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 4, viewport)
	for invalid in [layout.PaintVisualLayer{...*mask, opacity: .5},
		layout.PaintVisualLayer{...*mask, blend_mode: .screen},
		layout.PaintVisualLayer{...*mask, kind: .css_effect},
		layout.PaintVisualLayer{...*mask, scope_id: 0}] {
		mut changed := commands.clone()
		changed[2] = layout.PaintCommand{...commands[2], visual_layer_data: &invalid}
		changed[4] = layout.PaintCommand{...commands[4], visual_layer_data: &invalid}
		assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 5, viewport)
	}
}

fn test_compositor_parent_can_resume_after_disjoint_bounded_root_leaves() {
	base := compositor_gap_test_commands()
	mut plan := compositor_gap_test_plan()
	plan.command_layers[2] = 0
	// Root layer bounds describe the whole document, not this intervening leaf.
	plan.layers[0].bounds = layout.LayoutRect{0, 0, 200, 20000}
	viewport := layout.LayoutRect{0, 0, 200, 120}
	for root in [base[2], layout.PaintCommand{
		kind: 'draw_video'
		// The retained clip, rather than these stale compatibility bounds,
		// constrains every video/poster representation and object-fit mode.
		x: 0
		y: 0
		width: 200
		height: 20000
		video_paintable: &painting.VideoPaintable{
			video_rect: painting.Rect{0, 35, 100, 10}
			object_fit: .cover
		}
	}] {
		mut commands := base.clone()
		commands[2] = root
		assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
		assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, viewport)
	}
	for root in [layout.PaintCommand{kind: 'draw_video'},
		layout.PaintCommand{kind: 'draw_text', text: 'unbounded'},
		layout.PaintCommand{kind: 'begin_css_effect_layer'},
		layout.PaintCommand{...base[2], y: 79},
		layout.PaintCommand{...base[2], fixed_to_viewport: true},
		layout.PaintCommand{kind: 'draw_video', video_paintable: &painting.VideoPaintable{
			video_rect: painting.Rect{0, 73, 100, 10}
		}},
		layout.PaintCommand{...base[2], transform: [f64(1), 0, 0, 1, 1e7, 0]}] {
		mut commands := base.clone()
		commands[2] = root
		assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	}
}

fn compositor_gap_test_commands() []layout.PaintCommand {
	gradient := layout.PaintCommand{
		kind:                      'fill_gradient'
		width:                     120
		height:                    140
		gradient_background_layer: true
		gradient:                  &layout.LinearGradient{
			kind:  'linear'
			x2:    1
			y2:    1
			stops: [layout.GradientStop{css.Color{18, 27, 40, 143}, 0},
				layout.GradientStop{css.Color{16, 21, 30, 143}, 1}]
		}
		image_data:                &layout.PaintImageData{ image_clip_width: 120, image_clip_height: 140 }
	}
	return [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'fill_rect', width: 120, y: 5, height: 10 },
		layout.PaintCommand{ kind: 'fill_rect', width: 100, y: 35, height: 10 }, layout.PaintCommand{
			...gradient
			y:          80
			height:     10
			image_data: &layout.PaintImageData{ image_clip_y: 80, image_clip_width: 120, image_clip_height: 10 }
		}, layout.PaintCommand{ kind: 'fill_rect' }]
}

fn compositor_gap_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers:             [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [
				1,
				3,
			]
		}, layout.ChromiumRasterLayer{
			scroll_contents: true
			command_indices: [2]
			bounds:          layout.LayoutRect{0, 30, 100, 30}
		}]
		command_layers:     [0, 1, 2, 1, 0]
	}
}

fn test_compositor_parent_can_resume_after_a_disjoint_visible_scroll_layer() {
	commands := compositor_gap_test_commands()
	plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, 1, viewport)
	assert !chromium_svg_compositor_layer_supported(commands, plan, 1)
}

fn test_compositor_parent_resume_retains_premultiplied_overlap_and_native_fringe() {
	commands := compositor_gap_test_commands()
	plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	for bottom in [f64(74), 74.015625, 90] {
		mut changed := commands.clone()
		changed[1] = layout.PaintCommand{ ...commands[1], height: bottom - 5 }
		assert chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 3, viewport) == (bottom == 74)
	}
	mut overlaps_child := compositor_gap_test_plan()
	overlaps_child.layers[2].bounds = layout.LayoutRect{0, 75, 100, 20}
	assert !chromium_compositor_gap_can_flush_parent(commands, overlaps_child, 1, 2, 3, viewport)
	// Native command transforms already include root scrolling; layer bounds
	// stay in document coordinates.
	mut scrolled := compositor_gap_test_plan()
	scrolled.layers[2].bounds = layout.LayoutRect{0, 1030, 100, 30}
	assert chromium_compositor_gap_can_flush_parent(commands, scrolled, 1, 2, 3,
		layout.LayoutRect{0, 1000, 200, 120})
}

fn test_compositor_parent_resume_rejects_unknown_bounds_effects_and_ownership() {
	commands := compositor_gap_test_commands()
	plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	for replacement in [layout.PaintCommand{ kind: 'draw_text', text: 'unknown ink' },
		layout.PaintCommand{ ...commands[1], fixed_to_viewport: true },
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ ...commands[1], transform: [f64(1), 0, 0, 1, 1e7, 0] }] {
		mut changed := commands.clone()
		changed[1] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 3, viewport)
	}
	for replacement in [layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ ...commands[2], fixed_to_viewport: true }] {
		mut changed := commands.clone()
		changed[2] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 3, viewport)
	}
	for owners in [[0, 1, 1, 1, 0], [0, 1, 9, 1, 0], [0, 1, 2, 0, 0], [0, 1]] {
		mut invalid := compositor_gap_test_plan()
		invalid.command_layers = owners
		assert !chromium_compositor_gap_can_flush_parent(commands, invalid, 1, 2, 3, viewport)
	}
	mut no_metadata := compositor_gap_test_plan()
	no_metadata.has_paint_metadata = false
	assert !chromium_compositor_gap_can_flush_parent(commands, no_metadata, 1, 2, 3, viewport)
	for legacy in [false, true] {
		mut invalid := compositor_gap_test_plan()
		invalid.layers[2].legacy_raster = legacy
		invalid.layers[2].scroll_contents = legacy
		assert !chromium_compositor_gap_can_flush_parent(commands, invalid, 1, 2, 3, viewport)
	}
}

fn test_compositor_gap_includes_vector_hulls_and_native_border_strokes() {
	path := layout.PaintCommand{
		kind:     'draw_svg_path'
		color:    '#abcdef'
		svg_data: &layout.PaintSVGPathData{
			path_transform: [f64(2), 0, 0, 1, 8, 3]!
			path_data:      [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 10, 10, 0, 40, 15, 45,
				0, 0, 0, 0, 0]
		}
	}
	bounds := chromium_compositor_gap_ink(&path) or { panic('Expected bounded Bezier') }
	assert bounds == layout.LayoutRect{8, 3, 30, 45}
	mut commands := compositor_gap_test_commands()
	commands[1] = path
	plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	commands[3] = layout.PaintCommand{
		...commands[3]
		y:          50
		image_data: &layout.PaintImageData{
			image_clip_y:      50
			image_clip_width:  120
			image_clip_height: 10
		}
	}
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	border := layout.PaintCommand{ kind: 'paint_uniform_border', x: 10, y: 20, width: 30, height: 40, stroke_width: 2 }
	ring := chromium_compositor_gap_ink(&border) or { panic('Expected bounded border') }
	assert ring == layout.LayoutRect{8, 18, 34, 44}
	for bad in [layout.PaintCommand{
		...path
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(1), 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	}, layout.PaintCommand{
		...path
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(9), 10, 10, 0, 0, 0, 0, 20, 20, 0, 0, 0]
		}
	}, layout.PaintCommand{ ...path, svg_data: &layout.PaintSVGPathData{ path_data: [f32(0), 1] } },
		layout.PaintCommand{ ...path, transform: [f64(1), 0, 0, 1, 1e7, 0] },
		layout.PaintCommand{ ...path, stroke_color: '#123456', stroke_width: 2 }] {
		assert chromium_compositor_gap_ink(&bad) == none
	}
}

fn test_compositor_gap_accepts_disjoint_scrollbars_but_preserves_other_layer_rejection() {
	mut commands := compositor_gap_test_commands()
	mut plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	plan.layers[2].scroll_contents = false
	for kind in ['fill_rounded_rect', 'stroke_rounded_rect'] {
		commands[2] = layout.PaintCommand{ ...commands[2], kind: kind, scrollbar_axis: 'horizontal' }
		assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	}
	commands[2] = layout.PaintCommand{ ...commands[2], scrollbar_axis: '' }
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
}

fn test_compositor_gap_accepts_the_recorded_scroll_and_scrollbar_fixture() {
	source := os.read_file('Tests/Browser/Brave/input/compositor-disjoint-scroll-gap.html') or { panic(err) }
	mut document := html.parse_document(source)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	mut plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		layout.LayoutRect{0, 0, 800, 600}, mut plan)
	assert plan.has_paint_metadata
	mut parent := -1
	mut saw_scrollbar := false
	for index, command in commands {
		if command.kind == 'fill_gradient' && parent < 0 { parent = plan.command_layers[index] }
		if command.scrollbar_axis != '' { saw_scrollbar = true }
	}
	assert parent > 0
	assert saw_scrollbar
	assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, parent, layout.LayoutRect{0, 0, 800, 600})
	// Exercise the recorder's layer ownership and native ink here; the browser
	// regression also covers gradient replay and final compositing.
	mut gaps := 0
	for position, index in plan.layers[parent].command_indices {
		if position == 0 { continue }
		previous := plan.layers[parent].command_indices[position - 1]
		if index > previous + 1 {
			assert chromium_compositor_gap_can_flush_parent(commands, plan, parent,
				previous + 1, index, layout.LayoutRect{0, 0, 800, 600})
			gaps++
		}
	}
	assert gaps > 0
}

fn test_compositor_gap_retains_holes_between_separated_prefix_leaves() {
	original := compositor_gap_test_commands()
	commands := [original[0], original[1],
		layout.PaintCommand{ kind: 'fill_rect', width: 120, y: 108, height: 10 }, original[2],
		original[3], original[4]]
	mut plan := compositor_gap_test_plan()
	plan.layers[1].command_indices = [1, 2, 4]
	plan.layers[2].command_indices = [3]
	plan.command_layers = [0, 1, 1, 2, 1, 0]
	viewport := layout.LayoutRect{0, 0, 200, 120}
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 3, 4, viewport)
	mut overlap := commands.clone()
	overlap[2] = layout.PaintCommand{ ...commands[2], y: 82 }
	assert !chromium_compositor_gap_can_flush_parent(overlap, plan, 1, 3, 4, viewport)
}

fn test_compositor_gap_bounds_native_svg_arcs_before_comparing_spans() {
	path := layout.PaintCommand{
		kind:     'draw_svg_path'
		color:    '#abcdef'
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 40, 0, 0, 0, 0, 0, 20, 10,
				0, 0, 1]
		}
	}
	bounds := chromium_compositor_gap_ink(&path) or { panic('Expected bounded native arc') }
	assert bounds.x <= 0 && bounds.x + bounds.width >= 40
	assert bounds.y <= -9.999 && bounds.y + bounds.height >= 0
	assert bounds.height < 10.001
}

fn test_compositor_gap_uses_outline_bounds_only_for_unvaried_document_faces() {
	font := &platform.Font{ family: 'Times', point_size: 23, font_rendering_policy: .chromium }
	_, glyph := font.glyph_advance_and_index(u32(`A`))
	glyphs := [platform.Glyph{ glyph_index: glyph, position: platform.GlyphPosition{10, 30} }]
	run := platform.GlyphRun.new(font, .common, glyphs)
	tight := run.outline_ink_bounds() or { panic('Expected ordinary TrueType outline') }
	assert tight.width > 0 && tight.height > 0
	for fallback in [&platform.Font{ ...*font, italic: true }, &platform.Font{ ...*font, weight: 700 },
		&platform.Font{ ...*font, requested_variations: [platform.FontVariationAxis{ tag: 0x77676874, value: 400 }] }] {
		assert platform.GlyphRun.new(fallback, .common, glyphs).outline_ink_bounds() == none
	}
	assert platform.GlyphRun.new_with_face(font, .common, glyphs, .emoji).outline_ink_bounds() == none
	assert platform.GlyphRun.new(font, .common, [platform.Glyph{ glyph_index: 65535 }]).outline_ink_bounds() == none
}

fn test_compositor_gap_bounds_inner_shadows_by_their_native_content_clip() {
	shadow := layout.PaintCommand{
		kind:            'paint_inner_box_shadow'
		x:               -1000
		y:               -1000
		width:           2000
		height:          2000
		blur:            100
		box_shadow_data: &layout.PaintBoxShadowData{ content_rect: layout.LayoutRect{10, 20, 30, 40} }
	}
	bounds := chromium_compositor_gap_ink(&shadow) or { panic('Expected clipped inner shadow') }
	assert bounds == layout.LayoutRect{10, 20, 30, 40}
	mut commands := compositor_gap_test_commands()
	commands[1] = shadow
	plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	commands[1] = layout.PaintCommand{
		...shadow
		box_shadow_data: &layout.PaintBoxShadowData{
			content_rect: layout.LayoutRect{0, 75, 100, 30}
		}
	}
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	assert chromium_compositor_gap_ink(&layout.PaintCommand{ kind: 'paint_inner_box_shadow' }) == none
}

fn test_compositor_gap_uses_scrollbar_ink_instead_of_its_aggregate_layer_bounds() {
	mut commands := compositor_gap_test_commands()
	mut plan := compositor_gap_test_plan()
	viewport := layout.LayoutRect{0, 0, 200, 120}
	plan.layers[2].scroll_contents = false
	plan.layers[2].bounds = layout.LayoutRect{0, 0, 200, 10000}
	commands[2] = layout.PaintCommand{ ...commands[2], kind: 'fill_rounded_rect', scrollbar_axis: 'horizontal' }
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
	commands[2] = layout.PaintCommand{ ...commands[2], y: 78 }
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 3, viewport)
}
