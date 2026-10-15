module layout

import painting

fn retained_rare_payload_commands() []PaintCommand {
	layer := PaintVisualLayer{
		kind: .svg_mask
		scope_id: 17
		opacity: 0.4
		mask_clip: PaintClip{
			is_svg_mask: true
			cache_key: 23
			transform: [f64(1), 0, 0, 1, 3, 4]!
			mask_operations: [PaintMaskOperation{
				kind: .path
				path_data: [f32(1), 2, 3]
				transform: [f64(1), 0, 0, 1, 5, 6]!
			}]
		}
	}
	return lower_visual_layers([PaintCommand{
		kind: 'fill_rect'
		visual_layer_list: &PaintVisualLayerList{items: [layer]}
	}])
}

fn test_ordinary_commands_leave_rare_payloads_absent_and_keep_logical_defaults() {
	assert sizeof(PaintCommand) <= 2400
	for command in [PaintCommand{kind: 'draw_text', text: 'ordinary'}, PaintCommand{kind: 'fill_rect'}] {
		assert command.visual_layer_data == none
		assert command.mask_clip_data == none
		assert command.backdrop_filter_data == none
		assert command.visual_layer().opacity == 1
		assert command.visual_layer().scope_id == 0
		assert command.visual_layer().filter == none
		assert command.mask_clip().rect.width == 0
		assert command.mask_clip().transform == [6]f64{}
		assert command.backdrop_filter() == none
		nested := paint_command_for_nested_viewport(command, [f64(1), 0, 0, 1, 7, 8]!, painting.IntPoint{10, 20}, 1)
		assert nested.visual_layer_data == none
		assert nested.mask_clip_data == none
		assert nested.backdrop_filter_data == none
	}
}

fn test_layer_snapshots_retain_mask_ownership_and_nested_replay_does_not_mutate_them() {
	commands := retained_rare_payload_commands()
	assert commands.map(it.kind) == ['begin_svg_mask_layer', 'fill_rect', 'end_svg_mask_layer']
	for _ in 0 .. 3 {
		gc_collect()
		assert commands.first().visual_layer().scope_id == 17
		assert commands.last().visual_layer().opacity == 0.4
		assert commands.first().mask_clip_data == none
		assert commands.first().mask_clip().mask_operations[0].path_data == [f32(1), 2, 3]
		assert commands.last().mask_clip().cache_key == 23
	}
	nested := paint_command_for_nested_viewport(commands.first(), [f64(2), 0, 0, 2, 7, 8]!, painting.IntPoint{10, 20}, 1)
	assert nested.mask_clip_data != none
	assert nested.mask_clip().transform == [f64(2), 0, 0, 2, 33, 56]!
	assert nested.mask_clip().mask_operations[0].transform == [f64(2), 0, 0, 2, 37, 60]!
	assert nested.mask_clip().cache_key != 23
	assert commands.first().mask_clip().transform == [f64(1), 0, 0, 1, 3, 4]!
	assert commands.last().mask_clip().cache_key == 23
	assert commands.first().mask_clip().mask_operations[0].transform == [f64(1), 0, 0, 1, 5, 6]!
	assert nested.visual_layer().mask_clip.cache_key == 23
}

fn test_backdrop_filter_payload_is_optional_and_survives_its_recording_scope() {
	assert retained_paint_backdrop_filter(none) == none
	filter := painting.GfxFilter{root_id: 7, bounds: painting.Rect{1, 2, 30, 40}}
	mut commands := []PaintCommand{}
	append_painting_display_command(mut commands, painting.ApplyBackdropFilter{
		backdrop_region: painting.IntRect{1, 2, 30, 40}
		filter: filter
	}, 0.5)
	assert commands.len == 1
	assert commands[0].backdrop_filter_data != none
	for _ in 0 .. 3 {
		gc_collect()
		retained := commands[0].backdrop_filter() or { panic('missing retained backdrop filter') }
		root := retained.root_id or { panic('missing retained filter root') }
		bounds := retained.bounds or { panic('missing retained filter bounds') }
		assert root == 7
		assert bounds == painting.Rect{1, 2, 30, 40}
		assert commands[0].opacity == 0.5
	}
}
