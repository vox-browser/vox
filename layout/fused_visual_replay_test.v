module layout

import css
import painting

fn fused_replay_assert_matches_reference(actual []PaintCommand, expected []PaintCommand) {
	assert actual.len == expected.len
	assert actual.cap == actual.len
	for index, command in actual {
		reference := expected[index]
		assert command.kind == reference.kind
		assert command.text == reference.text
		assert command.svg().path == reference.svg().path
		assert command.svg().path_data == reference.svg().path_data
		assert command.x == reference.x
		assert command.y == reference.y
		assert command.width == reference.width
		assert command.height == reference.height
		assert command.opacity == reference.opacity
		assert command.group_opacity == reference.group_opacity
		assert command.transform == reference.transform
		assert command.fixed_to_viewport == reference.fixed_to_viewport
		assert command.has_clip == reference.has_clip
		assert command.clip_x == reference.clip_x
		assert command.clip_y == reference.clip_y
		assert command.clip_width == reference.clip_width
		assert command.clip_height == reference.clip_height
		assert (command.clip_list == unsafe { nil }) == (reference.clip_list == unsafe { nil })
		if command.clip_list != unsafe { nil } {
			assert command.clip_list.items == reference.clip_list.items
		}
		assert command.visual_layer_list == unsafe { nil }
		assert command.visual_layer() == reference.visual_layer()
		assert command.line_box_debug == reference.line_box_debug
		assert command.image_scroll_offset_x == reference.image_scroll_offset_x
		assert command.image_scroll_offset_y == reference.image_scroll_offset_y
	}
}

fn test_fused_visual_replay_matches_two_stage_layers_clips_backfaces_and_live_offsets() {
	assert sizeof(CompatibilityCachedVisualReplayStep) < sizeof(PaintCommand) / 8
	mut tree := painting.new_accumulated_visual_context_tree()
	effect := tree.append(painting.EffectsVisualData{ opacity: 0.25 }, 0)
	guide_transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{
			e: 7
			f: 11
		}
	}, effect)
	transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{
			a: 2
			d: 3
			e: 13
			f: 17
		}
	}, effect)
	mask := tree.append(painting.SVGClipVisualData{
		bounding_rect: painting.IntRect{0, 0, 100, 100}
		scope_id:      99
		cache_key:     101
	}, transform)
	clip := tree.append(painting.ClipVisualData{ rect: painting.IntRect{2, 3, 40, 50} }, mask)
	guide_only := tree.append(painting.EffectsVisualData{ opacity: 0.5 }, effect)
	rotation := tree.append(painting.TransformVisualData{
		matrix_4x4:      css.rotation_matrix(css.FloatVector3{ x: 0, y: 1 }, 3.141592653589793)
		uses_matrix_4x4: true
	}, 0)
	backface := tree.append(painting.BackfaceVisibilityVisualData{}, rotation)
	mut guide_box := BlockBox{
		accumulated_visual_context_index: guide_transform
		fixed_to_viewport:                true
	}
	mut svg_box := BlockBox{
		accumulated_visual_context_index: clip
		overlay:                          &CompatibilityOverlayData{
			scroll_offset_x: 7
			scroll_offset_y: 9
		}
	}
	mut hidden_box := BlockBox{
		accumulated_visual_context_index: guide_only
	}
	mut text_box := BlockBox{
		accumulated_visual_context_index:               backface
		accumulated_visual_context_for_descendants_idx: effect
		paintable_with_lines:                           true
	}
	steps := [
		CompatibilityPaintStep{
			box:         &guide_box
			phase:       .foreground
			entry_index: 0
		},
		CompatibilityPaintStep{
			box:         &svg_box
			phase:       .foreground
			entry_index: 1
		},
		CompatibilityPaintStep{
			box:         &hidden_box
			phase:       .foreground
			entry_index: 2
		},
		CompatibilityPaintStep{
			box:         &text_box
			phase:       .foreground
			entry_index: 3
		},
	]
	mut buckets := [][]PaintCommand{len: 4 * compatibility_paint_phase_count}
	foreground := int(CompatibilityPaintPhase.foreground)
	buckets[foreground] = [PaintCommand{ kind: 'guide-first', line_box_debug: true }]
	buckets[compatibility_paint_phase_count + foreground] = [
		PaintCommand{
			kind:           'draw_svg_path'
			svg_data: &PaintSVGPathData{
				path:           'M0 0L10 10'
				path_data:      [f32(1), 2, 3]
			}
			recording_clip: LayoutRect{1, 2, 10, 20}
		},
		PaintCommand{
			kind: 'draw_background_image'
			text: 'original'
		},
		PaintCommand{
			kind:                             'scrollbar'
			y:                                3
			scrollbar_axis:                   'vertical'
			scrollbar_recorded_scroll_offset: 2
			scrollbar_thumb_travel_ratio:     0.5
		},
		PaintCommand{
			kind:                 'culled'
			visual_context_index: backface
		},
	]
	buckets[2 * compatibility_paint_phase_count + foreground] = [
		PaintCommand{
			kind:           'guide-only'
			line_box_debug: true
		},
	]
	buckets[3 * compatibility_paint_phase_count + foreground] = [
		PaintCommand{
			kind: 'draw_text'
			text: 'last'
		},
	]
	for show_guides in [false, true] {
		replayed, layer_steps := replay_cached_paint_commands_with_visual_context(steps, buckets,
			7, tree, painting.ScrollStateSnapshot{}, show_guides)
		expected := lower_visual_replay_steps(replayed, layer_steps)
		actual := record_cached_paint_commands_with_visual_context(steps, buckets, 7, tree, painting.ScrollStateSnapshot{},
			show_guides)
		fused_replay_assert_matches_reference(actual, expected)
		assert !actual.any(it.kind == 'culled')
		assert actual[0].kind == 'begin_css_effect_layer'
		assert actual[0].transform == [f64(1), 0, 0, 1, 7, 11]!
		assert actual[0].fixed_to_viewport
		path := actual.filter(it.kind == 'draw_svg_path')[0]
		assert path.clip_list.items.len == 2
		assert path.clip_list.items.all(!it.is_svg_mask)
		assert actual.filter(it.kind == 'scrollbar')[0].y == 6.5
	}

	initial := record_cached_paint_commands_with_visual_context(steps, buckets, 7, tree, painting.ScrollStateSnapshot{},
		false)
	svg_box.overlay = &CompatibilityOverlayData{
		scroll_offset_x: 20
		scroll_offset_y: 30
	}
	buckets[compatibility_paint_phase_count + foreground][1].text = 'updated'
	updated := record_cached_paint_commands_with_visual_context(steps, buckets, 7, tree, painting.ScrollStateSnapshot{},
		false)
	assert initial.data != updated.data
	assert initial.filter(it.kind == 'draw_background_image')[0].text == 'original'
	assert initial.filter(it.kind == 'draw_background_image')[0].image_scroll_offset_y == 9
	assert initial.filter(it.kind == 'scrollbar')[0].y == 6.5
	assert updated.filter(it.kind == 'draw_background_image')[0].text == 'updated'
	assert updated.filter(it.kind == 'draw_background_image')[0].image_scroll_offset_y == 30
	assert updated.filter(it.kind == 'scrollbar')[0].y == 17
	assert buckets[compatibility_paint_phase_count + foreground][0].clip_list == unsafe { nil }
	assert buckets[compatibility_paint_phase_count + foreground][2].y == 3
}

fn test_fused_visual_replay_preserves_guide_only_layers_and_empty_output() {
	mut tree := painting.new_accumulated_visual_context_tree()
	outer := tree.append(painting.EffectsVisualData{ opacity: 0.25 }, 0)
	inner := tree.append(painting.EffectsVisualData{ opacity: 0.5 }, outer)
	box := BlockBox{
		accumulated_visual_context_index: inner
	}
	steps := [CompatibilityPaintStep{ box: &box, phase: .foreground, entry_index: 0 }]
	mut buckets := [][]PaintCommand{len: compatibility_paint_phase_count}
	buckets[int(CompatibilityPaintPhase.foreground)] = [
		PaintCommand{
			kind:           'guide'
			line_box_debug: true
		},
	]
	replayed, layer_steps := replay_cached_paint_commands_with_visual_context(steps, buckets, 1,
		tree, painting.ScrollStateSnapshot{}, false)
	expected := lower_visual_replay_steps(replayed, layer_steps)
	actual := record_cached_paint_commands_with_visual_context(steps, buckets, 1, tree, painting.ScrollStateSnapshot{},
		false)
	fused_replay_assert_matches_reference(actual, expected)
	assert actual.map(it.kind) == ['begin_css_effect_layer', 'begin_css_effect_layer',
		'end_css_effect_layer', 'end_css_effect_layer']
	assert actual[0].visual_layer().opacity == 0.25
	assert actual[3].visual_layer().opacity == 0.25
	assert record_cached_paint_commands_with_visual_context([]CompatibilityPaintStep{},
		[][]PaintCommand{}, 0, tree, painting.ScrollStateSnapshot{}, false).len == 0
}
