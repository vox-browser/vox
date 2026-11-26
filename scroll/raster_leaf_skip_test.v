module main

import layout

fn test_damage_skipped_leaves_bypass_culling_but_groups_and_videos_do_not() {
	if cull_damage_skipped_leaves { return }
	commands := [layout.PaintCommand{kind: 'fill_rect'}, layout.PaintCommand{kind: 'begin_css_effect_layer'},
		layout.PaintCommand{kind: 'draw_video'}, layout.PaintCommand{kind: 'draw_text'},
		layout.PaintCommand{kind: 'end_css_effect_layer'}, layout.PaintCommand{kind: 'draw_svg_path'}]
	damage := ScrollRasterDamage{
		reused:    true
		skip_plan: [true, true, true, false, true, true]
	}
	assert [0, 1, 2, 3, 4, 5].map(damage.skips_leaf(commands, it)) == [true, false, false, false, false,
		true]
	// Without a reused frame nothing is skipped by damage.
	fresh := ScrollRasterDamage{ skip_plan: [true, true, true, true, true, true] }
	assert [0, 3, 5].map(fresh.skips_leaf(commands, it)) == [false, false, false]
}
