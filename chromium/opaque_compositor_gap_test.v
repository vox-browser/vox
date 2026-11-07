module main

import layout
import html
import os

fn test_captured_svg_header_retains_its_opaque_continuation_after_layout() {
	mut document := html.parse_document(os.read_file('Tests/Browser/Brave/input/opaque-svg-mask-ellipse-resume.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_font_size_keyword_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	mut plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1, viewport, mut plan)
	mut masks := 0
	for index, command in commands {
		if command.kind != 'begin_svg_mask_layer' { continue }
		masks++
		assert index + 3 < commands.len
		parent := plan.command_layers[index + 3]
		assert parent > 0
		assert commands[index + 3].kind == 'draw_svg_path'
		assert commands[index + 3].svg_data.path_data[0] == 6
		assert chromium_svg_compositor_layer_supported_for_viewport(commands, plan, parent, viewport)
		assert !chromium_compositor_opaque_mask_resume(commands, plan, parent,
			plan.layers[parent].command_indices.first())
		assert chromium_compositor_opaque_mask_resume(commands, plan, parent, index + 3)
	}
	assert masks == 1
}

fn opaque_mask_gap_test_commands() []layout.PaintCommand {
	mask := &layout.PaintVisualLayer{kind:.svg_mask, scope_id:47,
		mask_clip:layout.PaintClip{is_svg_content_mask:true, scope_id:47}}
	return [layout.PaintCommand{kind:'fill_rect'},
		layout.PaintCommand{kind:'fill_rect', width:1024, height:40, color:'white'},
		layout.PaintCommand{kind:'draw_svg_path', color:'#c00', svg_data:&layout.PaintSVGPathData{
			path_data:[f32(0),80,9,0,0,0,0,0,0,0,0,0,1,126,9,0,0,0,0,0,0,0,0,0]}},
		layout.PaintCommand{kind:'begin_svg_mask_layer', visual_layer_data:mask},
		layout.PaintCommand{kind:'fill_rect', x:779, y:12, width:16, height:16, color:'black'},
		layout.PaintCommand{kind:'end_svg_mask_layer', visual_layer_data:mask},
		layout.PaintCommand{kind:'fill_rect', x:918.5, y:5.5, width:73, height:29, color:'white'}]
}

fn opaque_mask_gap_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{has_paint_metadata:true,
		layers:[layout.ChromiumRasterLayer{command_indices:[0]},
			layout.ChromiumRasterLayer{composited_contents:true,command_indices:[1,2,6]},
			layout.ChromiumRasterLayer{legacy_raster:true,command_indices:[3,4,5]}],
		command_layers:[0,1,1,2,2,2,1]}
}

fn test_opaque_compositor_prefix_can_resume_around_a_disjoint_captured_mask() {
	commands := opaque_mask_gap_test_commands()
	plan := opaque_mask_gap_test_plan()
	assert chromium_compositor_gap_can_flush_parent(commands,plan,1,3,6,
		layout.LayoutRect{0,0,1024,768})
	assert chromium_svg_compositor_layer_supported_for_viewport(commands,plan,1,
		layout.LayoutRect{0,0,1024,768})
	assert chromium_compositor_opaque_mask_resume(commands,plan,1,6)
	assert !chromium_compositor_opaque_mask_resume(commands,plan,1,1)
	assert !chromium_compositor_opaque_mask_resume(commands,plan,2,3)
}

fn test_opaque_fixed_prefix_can_resume_around_a_mask_in_the_same_viewport_space() {
	mut commands := opaque_mask_gap_test_commands()
	for index in 1 .. commands.len {
		commands[index].fixed_to_viewport = true
	}
	plan := opaque_mask_gap_test_plan()
	assert chromium_compositor_gap_can_flush_parent(commands,plan,1,3,6,
		layout.LayoutRect{0,6400,1024,768})
	assert chromium_svg_compositor_layer_supported_for_viewport(commands,plan,1,
		layout.LayoutRect{0,6400,1024,768})
	assert chromium_compositor_opaque_mask_resume(commands,plan,1,6)
	for index in [1,2,3,4,6] {
		mut mixed := commands.clone()
		mixed[index].fixed_to_viewport = false
		assert !chromium_opaque_compositor_mask_gap(mixed,plan,1,3,6)
	}
}

fn test_fixed_mask_closing_marker_does_not_change_its_painted_coordinate_space() {
	mut commands := opaque_mask_gap_test_commands()
	for index in [1,2,3,4,6] {
		commands[index].fixed_to_viewport = true
	}
	// Display-list lowering attaches no geometry or fixed flag to closing markers.
	assert !commands[5].fixed_to_viewport
	plan := opaque_mask_gap_test_plan()
	assert chromium_opaque_compositor_mask_gap(commands,plan,1,3,6)
	assert chromium_svg_compositor_layer_supported_for_viewport(commands,plan,1,
		layout.LayoutRect{0,6400,1024,768})
}

fn test_opaque_mask_gap_retains_transparency_fringe_and_paint_order_guards() {
	commands := opaque_mask_gap_test_commands()
	plan := opaque_mask_gap_test_plan()
	for replacement in [
		layout.PaintCommand{...commands[1],color:'#fffffffe'},
		layout.PaintCommand{...commands[1],height:37},
		layout.PaintCommand{...commands[1],radius:4},
		layout.PaintCommand{...commands[1],opacity:.5},
		layout.PaintCommand{...commands[1],has_clip:true,clip_width:1024,clip_height:40},
		layout.PaintCommand{...commands[1],transform:[f64(1),0,.1,1,0,0]!},
	] {
		mut changed := commands.clone()
		changed[1] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed,plan,1,3,6,
			layout.LayoutRect{0,0,1024,768})
	}
	for replacement in [
		layout.PaintCommand{...commands[6],x:794},
		layout.PaintCommand{...commands[6],fixed_to_viewport:true},
		layout.PaintCommand{kind:'draw_text',text:'unbounded glyphs'},
	] {
		mut changed := commands.clone()
		changed[6] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed,plan,1,3,6,
			layout.LayoutRect{0,0,1024,768})
	}
}

fn test_opaque_mask_gap_rejects_incomplete_scopes_and_foreign_ownership() {
	commands := opaque_mask_gap_test_commands()
	plan := opaque_mask_gap_test_plan()
	for replacement in [
		layout.PaintCommand{kind:'end_svg_mask_layer',visual_layer_data:&layout.PaintVisualLayer{kind:.svg_mask,scope_id:48}},
		layout.PaintCommand{kind:'end_css_effect_layer',visual_layer_data:commands[5].visual_layer_data},
	] {
		mut changed := commands.clone()
		changed[5] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed,plan,1,3,6,
			layout.LayoutRect{0,0,1024,768})
	}
	mut changed := opaque_mask_gap_test_plan()
	changed.command_layers[4] = 0
	assert !chromium_compositor_gap_can_flush_parent(commands,changed,1,3,6,
		layout.LayoutRect{0,0,1024,768})
	changed = opaque_mask_gap_test_plan()
	changed.has_paint_metadata = false
	assert !chromium_compositor_gap_can_flush_parent(commands,changed,1,3,6,
		layout.LayoutRect{0,0,1024,768})
}

fn opaque_svg_mask_gap_commands() []layout.PaintCommand {
    mut commands:=opaque_mask_gap_test_commands()
    commands[4]=layout.PaintCommand{kind:'draw_svg_path',color:'black',svg_data:&layout.PaintSVGPathData{
        path_data:[f32(0),779,12,0,0,0,0,0,0,0,0,0,1,795,12,0,0,0,0,0,0,0,0,0,
        1,795,28,0,0,0,0,0,0,0,0,0,1,779,28,0,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0]}}
    commands[6]=layout.PaintCommand{kind:'draw_svg_path',stroke_color:'black',stroke_width:1,
        svg_data:&layout.PaintSVGPathData{path_data:[f32(6),920,10,990,30,0,0,0,0,0,0,0]}}
    return commands
}

fn test_opaque_prefix_retains_stroked_ellipses_after_a_disjoint_svg_mask() {
    commands:=opaque_svg_mask_gap_commands()
    plan:=opaque_mask_gap_test_plan()
    assert chromium_opaque_compositor_mask_gap(commands,plan,1,3,6)
    assert chromium_svg_compositor_layer_supported_for_viewport(commands,plan,1,
        layout.LayoutRect{0,0,1024,768})
    assert chromium_compositor_opaque_mask_resume(commands,plan,1,6)
}

fn test_opaque_svg_mask_gap_keeps_stroke_bounds_and_scope_guards() {
    commands:=opaque_svg_mask_gap_commands()
    plan:=opaque_mask_gap_test_plan()
    for data in [
        &layout.PaintSVGPathData{path_data:[f32(6),790,10,805,30,0,0,0,0,0,0,0]},
        &layout.PaintSVGPathData{path_data:[f32(6),920,1,990,39,0,0,0,0,0,0,0]},
        &layout.PaintSVGPathData{path_data:[f32(0),920,10,0,0,0,0,0,0,0,0,0,3,990,30,940,50,980,0,0,0,0,0,0]},
        &layout.PaintSVGPathData{path_data:commands[6].svg_data.path_data,non_scaling_stroke:true},
        &layout.PaintSVGPathData{path_data:commands[6].svg_data.path_data,stroke_dasharray:[f32(2),2]},
    ] {
        mut changed:=commands.clone()
        changed[6]=layout.PaintCommand{...commands[6],svg_data:data}
        assert !chromium_opaque_compositor_mask_gap(changed,plan,1,3,6)
    }
}
