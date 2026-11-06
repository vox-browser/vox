module main

import layout
import painting

fn identity_mask_gap_commands() []layout.PaintCommand {
	effect := &layout.PaintVisualLayer{kind: .css_effect, scope_id: 17}
	mask := &layout.PaintVisualLayer{kind: .svg_mask, scope_id: 19}
	return [layout.PaintCommand{},
		layout.PaintCommand{kind: 'fill_rect', x: 946, y: 113, width: 36, height: 36, radius: 18},
		layout.PaintCommand{kind: 'begin_css_effect_layer', visual_layer_data: effect},
		layout.PaintCommand{kind: 'begin_svg_mask_layer', visual_layer_data: mask},
		layout.PaintCommand{kind: 'apply_backdrop_filter', x: 522, y: 4759, width: 460, height: 181},
		layout.PaintCommand{kind: 'end_svg_mask_layer', visual_layer_data: mask},
		layout.PaintCommand{kind: 'end_css_effect_layer', visual_layer_data: effect},
		layout.PaintCommand{kind: 'fill_rect', x: 979, y: 224, width: 5, height: 1}]
}

fn identity_mask_gap_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		has_paint_metadata: true
		layers: [layout.ChromiumRasterLayer{},
			layout.ChromiumRasterLayer{composited_contents: true, command_indices: [1, 7]},
			layout.ChromiumRasterLayer{legacy_raster: true, command_indices: [2, 3, 4, 5, 6]}]
		command_layers: [0, 1, 2, 2, 2, 2, 2, 1]
	}
}

fn test_disjoint_parent_resumes_across_identity_scopes_around_a_culled_mask() {
	commands := identity_mask_gap_commands()
	plan := identity_mask_gap_plan()
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	assert chromium_compositor_leaf_is_culled(&commands[4], viewport)
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 7, viewport)
}

fn test_identity_mask_gaps_retain_effect_ownership_and_balanced_scope_guards() {
	commands := identity_mask_gap_commands()
	plan := identity_mask_gap_plan()
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	for effect in [
		layout.PaintVisualLayer{kind: .css_effect, scope_id: 17, opacity: .5},
		layout.PaintVisualLayer{kind: .css_effect, scope_id: 17, blend_mode: .screen},
		layout.PaintVisualLayer{kind: .css_effect, scope_id: 17, filter: painting.GfxFilter{}},
		layout.PaintVisualLayer{kind: .css_filter, scope_id: 17},
		layout.PaintVisualLayer{kind: .css_effect, scope_id: 0},
	] {
		mut changed := commands.clone()
		changed[2] = layout.PaintCommand{...commands[2], visual_layer_data: &effect}
		changed[6] = layout.PaintCommand{...commands[6], visual_layer_data: &effect}
		assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 7, viewport)
	}
	for replacement in [
		layout.PaintCommand{...commands[4], x: 946, y: 214},
		layout.PaintCommand{kind: 'draw_text', text: 'unknown ink'},
	] {
		mut changed := commands.clone()
		changed[4] = replacement
		assert !chromium_compositor_gap_can_flush_parent(changed, plan, 1, 2, 7, viewport)
	}
	mut crossed := commands.clone()
	crossed[5], crossed[6] = commands[6], commands[5]
	assert !chromium_compositor_gap_can_flush_parent(crossed, plan, 1, 2, 7, viewport)
	mut mismatched := commands.clone()
	mismatched[6] = layout.PaintCommand{...commands[6], visual_layer_data: &layout.PaintVisualLayer{kind: .css_effect, scope_id: 20}}
	assert !chromium_compositor_gap_can_flush_parent(mismatched, plan, 1, 2, 7, viewport)
	mut foreign := layout.ChromiumRasterLayerPlan{...plan, command_layers: plan.command_layers.clone()}
	foreign.command_layers[4] = 0
	assert !chromium_compositor_gap_can_flush_parent(commands, foreign, 1, 2, 7, viewport)
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 2, 6, viewport)
}
