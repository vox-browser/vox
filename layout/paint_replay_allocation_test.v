module layout

import css
import painting

fn test_cached_replay_reserves_only_enabled_commands_and_keeps_live_snapshots() {
	mut box := BlockBox{
		overlay: &CompatibilityOverlayData{scroll_offset_x: 7, scroll_offset_y: 9}
	}
	steps := [CompatibilityPaintStep{box: &box, phase: .foreground, entry_index: 0}]
	mut buckets := [][]PaintCommand{len: compatibility_paint_phase_count}
	buckets[int(CompatibilityPaintPhase.foreground)] = [
		PaintCommand{kind: 'guide-before', line_box_debug: true},
		PaintCommand{kind: 'draw_background_image', text: 'original'},
		PaintCommand{kind: 'guide-after', line_box_debug: true},
	]
	initial := replay_cached_paint_commands(steps, buckets, 3, false)
	assert initial.map(it.kind) == ['draw_background_image']
	assert initial.cap == initial.len
	assert initial[0].image_scroll_offset_x == 7
	assert initial[0].image_scroll_offset_y == 9
	visible := replay_cached_paint_commands(steps, buckets, 3, true)
	assert visible.map(it.kind) == ['guide-before', 'draw_background_image', 'guide-after']
	assert visible.cap == visible.len
	assert buckets[int(CompatibilityPaintPhase.foreground)].len == 3
	assert buckets[int(CompatibilityPaintPhase.foreground)][1].image_scroll_offset_x == 0
	box.overlay = &CompatibilityOverlayData{scroll_offset_x: 20, scroll_offset_y: 30}
	buckets[int(CompatibilityPaintPhase.foreground)][1].text = 'updated'
	updated := replay_cached_paint_commands(steps, buckets, 3, false)
	assert updated[0].text == 'updated'
	assert updated[0].image_scroll_offset_x == 20
	assert updated[0].image_scroll_offset_y == 30
	assert initial[0].text == 'original'
	assert initial[0].image_scroll_offset_x == 7
	assert visible[1].text == 'original'
	assert visible.filter(it.line_box_debug).len == 2
}

fn test_visual_replay_skips_hidden_and_backface_commands_without_reserving_them() {
	mut tree := painting.new_accumulated_visual_context_tree()
	transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{a: 2, d: 2, e: 3, f: 4}
	}, 0)
	clip := tree.append(painting.ClipVisualData{rect: painting.IntRect{1, 2, 30, 40}}, transform)
	effect := tree.append(painting.EffectsVisualData{opacity: 0.5}, clip)
	rotation := tree.append(painting.TransformVisualData{
		matrix_4x4: css.rotation_matrix(css.FloatVector3{x: 0, y: 1, z: 0}, 3.141592653589793)
		uses_matrix_4x4: true
	}, 0)
	backface := tree.append(painting.BackfaceVisibilityVisualData{}, rotation)
	mut box := BlockBox{
		accumulated_visual_context_index: effect
		overlay: &CompatibilityOverlayData{scroll_offset_x: 5, scroll_offset_y: 6}
	}
	steps := [CompatibilityPaintStep{box: &box, phase: .foreground, entry_index: 0}]
	mut buckets := [][]PaintCommand{len: compatibility_paint_phase_count}
	buckets[int(CompatibilityPaintPhase.foreground)] = [
		PaintCommand{kind: 'guide', line_box_debug: true},
		PaintCommand{kind: 'draw_background_image'},
		PaintCommand{kind: 'culled', visual_context_index: backface},
	]
	initial, hidden_steps := replay_cached_paint_commands_with_visual_context(steps, buckets,
		3, tree, painting.ScrollStateSnapshot{}, false)
	assert initial.map(it.kind) == ['draw_background_image']
	assert initial.cap == initial.len
	assert hidden_steps.len == 2
	assert hidden_steps[0].command_index == -1
	assert hidden_steps[1].command_index == 0
	assert initial[0].has_clip
	assert initial[0].transform == [f64(2), 0, 0, 2, 3, 4]!
	assert initial[0].clip_list.items.len == 1
	assert initial[0].group_opacity == 0.5
	assert initial[0].image_scroll_offset_x == 5
	visible, visible_steps := replay_cached_paint_commands_with_visual_context(steps, buckets,
		3, tree, painting.ScrollStateSnapshot{}, true)
	assert visible.map(it.kind) == ['guide', 'draw_background_image']
	assert visible.cap == visible.len
	mut expected := lower_visual_replay_steps(visible, visible_steps)
	filter_line_box_debug_commands(mut expected, false)
	actual := lower_visual_replay_steps(initial, hidden_steps)
	assert actual.map(it.kind) == expected.map(it.kind)
	assert actual.cap == actual.len
	assert actual[0].visual_layer() == expected[0].visual_layer()
	assert actual[0].transform == expected[0].transform
	assert actual[1].clip_list.items == expected[1].clip_list.items
	box.overlay = &CompatibilityOverlayData{scroll_offset_x: 15, scroll_offset_y: 16}
	updated, _ := replay_cached_paint_commands_with_visual_context(steps, buckets, 3, tree,
		painting.ScrollStateSnapshot{}, false)
	assert updated[0].image_scroll_offset_x == 15
	assert initial[0].image_scroll_offset_x == 5
	assert visible[1].image_scroll_offset_x == 5
	assert buckets[int(CompatibilityPaintPhase.foreground)].len == 3
}

fn test_hidden_visual_steps_preserve_guide_only_scopes_and_first_transform() {
	effect := PaintVisualLayer{kind: .css_effect, scope_id: 1, opacity: 0.25}
	filter := PaintVisualLayer{kind: .css_filter, scope_id: 2}
	mask := PaintVisualLayer{kind: .svg_mask, scope_id: 3}
	first_path := &PaintVisualLayerList{items: [effect, filter]}
	second_path := &PaintVisualLayerList{
		items: [PaintVisualLayer{...effect, opacity: 0.75}, mask]
	}
	guide_transform := [f64(1), 0, 0, 1, 7, 11]!
	clips := &PaintClipList{
		items: [PaintClip{is_svg_mask: true}, PaintClip{rect: LayoutRect{width: 30, height: 40}}]
	}
	commands := [PaintCommand{kind: 'visible', clip_list: clips}]
	steps := [
		CompatibilityVisualReplayStep{
			layer_list: first_path
			transform: guide_transform
			fixed_to_viewport: true
		},
		CompatibilityVisualReplayStep{command_index: 0, layer_list: second_path},
		CompatibilityVisualReplayStep{layer_list: first_path},
		CompatibilityVisualReplayStep{},
	]
	actual := lower_visual_replay_steps(commands, steps)
	assert actual.map(it.kind) == ['begin_css_effect_layer', 'begin_css_filter_layer',
		'end_css_filter_layer', 'begin_svg_mask_layer', 'visible', 'end_svg_mask_layer',
		'begin_css_filter_layer', 'end_css_filter_layer', 'end_css_effect_layer']
	assert actual.cap == actual.len
	assert actual[0].transform == guide_transform
	assert actual[0].fixed_to_viewport
	assert actual[0].visual_layer().opacity == 0.25
	assert actual.last().visual_layer().opacity == 0.25
	assert actual[4].clip_list.items.len == 1
	assert !actual[4].clip_list.items[0].is_svg_mask
	assert actual.all(it.visual_layer_list == unsafe { nil })
	assert clips.items.len == 2
	assert first_path.items == [effect, filter]
	assert second_path.items[0].opacity == 0.75
	assert lower_visual_replay_steps([]PaintCommand{}, []CompatibilityVisualReplayStep{}).len == 0
}
