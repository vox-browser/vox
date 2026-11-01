module main

import layout

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
