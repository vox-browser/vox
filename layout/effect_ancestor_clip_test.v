module layout

import painting

fn test_bounded_effects_retain_the_original_clip_and_repeated_bounds() {
	ancestor := LayoutRect{0, 0, 100, 100}
	mut commands := [PaintCommand{
		kind:        'begin_css_effect_layer'
		has_clip:    true
		clip_width:  100
		clip_height: 100
	}, PaintCommand{ kind: 'fill_rect', x: 10, y: 20, width: 30, height: 40 },
		PaintCommand{ kind: 'end_css_effect_layer' }]
	bound_visual_effect_contents(mut commands)
	assert commands[0].clip_x == 10 && commands[0].clip_width == 30
	assert commands[0].effect_ancestor_clip()? == ancestor
	bound_visual_effect_contents(mut commands)
	assert commands[0].effect_ancestor_clip()? == ancestor
	// Nested replay maps both coordinate spaces without mutating the recording.
	nested := paint_command_for_nested_viewport(commands[0], [f64(2), 0, 0, 2, 11, 17]!,
		painting.IntPoint{5, 7}, 1)
	assert nested.clip_x == 41 && nested.clip_y == 71
	assert nested.effect_ancestor_clip()? == LayoutRect{21, 31, 200, 200}
	assert commands[0].effect_ancestor_clip()? == ancestor
}

fn test_calculated_effect_envelopes_do_not_invent_ancestor_clips() {
	mut commands := [PaintCommand{ kind: 'begin_css_effect_layer' },
		PaintCommand{ kind: 'fill_rect', x: 10, y: 20, width: 30, height: 40 },
		PaintCommand{ kind: 'end_css_effect_layer' }]
	bound_visual_effect_contents(mut commands)
	assert commands[0].has_clip && commands[0].clip_width == 30
	assert commands[0].effect_ancestor_clip() == none
	// Untagged clips remain semantic, including manually constructed commands.
	manual := PaintCommand{
		kind:              'begin_css_effect_layer'
		has_clip:          true
		clip_x:            3
		clip_y:            5
		clip_width:        7
		clip_height:       11
		visual_layer_data: &PaintVisualLayer{}
	}
	assert manual.effect_ancestor_clip()? == LayoutRect{3, 5, 7, 11}
}
