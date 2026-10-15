module layout

import painting

fn test_layer_free_replay_transfers_its_fresh_vector_and_keeps_earlier_snapshots() {
	mut tree := painting.new_accumulated_visual_context_tree()
	context := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{ a: 1, d: 1, e: 3, f: 7 }
	}, 0)
	mut box := BlockBox{
		accumulated_visual_context_index: context
		overlay:                          CompatibilityOverlayData{ scroll_offset_x: 5, scroll_offset_y: 6 }
	}
	steps := [CompatibilityPaintStep{ box: &box, phase: .foreground, entry_index: 0 }]
	mut buckets := [][]PaintCommand{len: compatibility_paint_phase_count}
	buckets[int(CompatibilityPaintPhase.foreground)] = [
		PaintCommand{ kind: 'guide', line_box_debug: true },
		PaintCommand{ kind: 'draw_background_image', text: 'before' },
	]
	replayed, layer_steps := replay_cached_paint_commands_with_visual_context(steps, buckets,
		2, tree, painting.ScrollStateSnapshot{}, false)
	assert layer_steps[0].command_index == -1
	finished := finish_fresh_visual_replay(replayed, layer_steps)
	assert finished.data == replayed.data
	assert finished.cap == finished.len
	assert finished.len == 1 && finished[0].text == 'before'
	assert finished[0].transform == [f64(1), 0, 0, 1, 3, 7]!
	assert finished[0].image_scroll_offset_x == 5
	assert finished.data != buckets[int(CompatibilityPaintPhase.foreground)].data
	buckets[int(CompatibilityPaintPhase.foreground)][1].text = 'after'
	box.overlay = CompatibilityOverlayData{ scroll_offset_x: 15, scroll_offset_y: 16 }
	updated, updated_steps := replay_cached_paint_commands_with_visual_context(steps, buckets,
		2, tree, painting.ScrollStateSnapshot{}, false)
	last := finish_fresh_visual_replay(updated, updated_steps)
	assert last.data != finished.data
	assert last[0].text == 'after' && last[0].image_scroll_offset_x == 15
	assert finished[0].text == 'before' && finished[0].image_scroll_offset_x == 5
	assert buckets[int(CompatibilityPaintPhase.foreground)][1].image_scroll_offset_x == 0
}

fn test_fresh_replay_keeps_layer_lowering_and_the_general_helpers_input_contract() {
	layer := &PaintVisualLayerList{ items: [PaintVisualLayer{ kind: .css_effect, scope_id: 1, opacity: 0.5 }] }
	commands := [PaintCommand{ kind: 'visible', visual_layer_list: layer }]
	steps := [CompatibilityVisualReplayStep{ command_index: 0, layer_list: layer }]
	finished := finish_fresh_visual_replay(commands, steps)
	assert finished.map(it.kind) == ['begin_css_effect_layer', 'visible', 'end_css_effect_layer']
	assert finished[0].visual_layer().opacity == 0.5
	assert finished.all(it.visual_layer_list == unsafe { nil })
	assert commands[0].visual_layer_list == layer
	plain := [PaintCommand{ kind: 'plain' }]
	mut lowered := lower_visual_layers(plain)
	lowered[0].text = 'changed'
	assert plain[0].text == ''
	assert finish_fresh_visual_replay([]PaintCommand{}, []CompatibilityVisualReplayStep{}).len == 0
}
