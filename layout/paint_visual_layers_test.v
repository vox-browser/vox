module layout

fn test_visual_layer_lowering_preserves_shared_prefix_and_sibling_order() {
	effect := PaintVisualLayer{
		kind:     .css_effect
		scope_id: 1
		opacity:  0.5
	}
	filter := PaintVisualLayer{
		kind:     .css_filter
		scope_id: 2
	}
	mask := PaintVisualLayer{
		kind:     .svg_mask
		scope_id: 3
	}
	first_path := &PaintVisualLayerList{
		items: [effect, filter]
	}
	second_path := &PaintVisualLayerList{
		items: [effect, mask]
	}
	commands := [
		PaintCommand{
			kind:              'first'
			visual_layer_list: first_path
		},
		PaintCommand{
			kind:              'second'
			visual_layer_list: second_path
			transform:         [f64(1), 0, 0, 1, 7, 11]!
		},
		PaintCommand{
			kind: 'last'
		},
	]
	lowered := lower_visual_layers(commands)
	assert lowered.map(it.kind) == ['begin_css_effect_layer', 'begin_css_filter_layer', 'first',
		'end_css_filter_layer', 'begin_svg_mask_layer', 'second', 'end_svg_mask_layer',
		'end_css_effect_layer', 'last']
	assert lowered.filter(it.kind.starts_with('begin_') || it.kind.starts_with('end_')).map(it.visual_layer().scope_id) == [
		u64(1),
		2,
		2,
		3,
		3,
		1,
	]
	assert lowered[4].transform == commands[1].transform
	assert lowered.all(it.visual_layer_list == unsafe { nil })
	assert first_path.items == [effect, filter]
	assert second_path.items == [effect, mask]
	assert voidptr(commands[0].visual_layer_list) == voidptr(first_path)
	assert voidptr(commands[1].visual_layer_list) == voidptr(second_path)
}

fn test_visual_layer_lowering_keeps_the_original_open_prefix_payload() {
	initial := PaintVisualLayer{
		kind:     .css_effect
		scope_id: 5
		opacity:  0.25
	}
	updated := PaintVisualLayer{
		kind:     .css_effect
		scope_id: 5
		opacity:  0.75
	}
	first_path := &PaintVisualLayerList{
		items: [initial]
	}
	second_path := &PaintVisualLayerList{
		items: [updated]
	}
	commands := [PaintCommand{ kind: 'first', visual_layer_list: first_path },
		PaintCommand{ kind: 'second', visual_layer_list: second_path }]
	for _ in 0 .. 2 {
		lowered := lower_visual_layers(commands)
		assert lowered.map(it.kind) == ['begin_css_effect_layer', 'first', 'second',
			'end_css_effect_layer']
		assert lowered.first().visual_layer().opacity == 0.25
		assert lowered.last().visual_layer().opacity == 0.25
		assert first_path.items[0].opacity == 0.25
		assert second_path.items[0].opacity == 0.75
	}
	assert lower_visual_layers([]PaintCommand{}).len == 0
}
