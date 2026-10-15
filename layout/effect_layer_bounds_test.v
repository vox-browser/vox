module layout

import painting

fn test_effect_surface_bounds_belong_to_the_scope_before_descendant_clips() {
	mut tree := painting.new_accumulated_visual_context_tree()
	transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{ a: 1, d: 1, e: 3, f: 7 }
	}, 0)
	ancestor := tree.append(painting.ClipVisualData{ rect: painting.IntRect{10, 20, 100, 80} }, transform)
	effect := tree.append(painting.EffectsVisualData{ opacity: 0.5 }, ancestor)
	first_child := tree.append(painting.ClipVisualData{ rect: painting.IntRect{10, 20, 10, 10} }, effect)
	second_child := tree.append(painting.ClipVisualData{ rect: painting.IntRect{60, 40, 40, 30} }, effect)
	first := flatten_compatibility_visual_context(tree, first_child, painting.ScrollStateSnapshot{})
	second := flatten_compatibility_visual_context(tree, second_child, painting.ScrollStateSnapshot{})
	assert first.clip != second.clip
	for context in [first, second] {
		assert context.layers.len == 1
		bounds := context.layers[0].clip_rect or { panic('missing ancestor bounds') }
		assert bounds == LayoutRect{13, 27, 100, 80}
	}
	commands := [PaintCommand{ kind: 'first', visual_layer_list: first.layer_list },
		PaintCommand{ kind: 'second', visual_layer_list: second.layer_list }]
	lowered := lower_visual_layers(commands)
	assert lowered.map(it.kind) == ['begin_css_effect_layer', 'first', 'second', 'end_css_effect_layer']
	begin := lowered[0]
	assert begin.has_clip
	assert begin.clip_x == 13 && begin.clip_y == 27
	assert begin.clip_width == 100 && begin.clip_height == 80
	assert begin.visual_layer().opacity == 0.5
	// Sprite replay composes the enclosing background transform and tile origin
	// into these viewport bounds, independently of the command's own transform.
	nested := paint_command_for_nested_viewport(begin, [f64(2), 0, 0, 2, 11, 17]!,
		painting.IntPoint{5, 7}, 1)
	assert nested.has_clip
	assert nested.clip_x == 47 && nested.clip_y == 85
	assert nested.clip_width == 200 && nested.clip_height == 160
	assert begin.clip_x == 13 && begin.clip_y == 27
}

fn test_effect_surface_bounds_distinguish_unclipped_and_empty_scopes() {
	mut tree := painting.new_accumulated_visual_context_tree()
	unclipped := tree.append(painting.EffectsVisualData{ opacity: 0.75 }, 0)
	child := tree.append(painting.ClipVisualData{ rect: painting.IntRect{0, 0, 10, 10} }, unclipped)
	context := flatten_compatibility_visual_context(tree, child, painting.ScrollStateSnapshot{})
	assert context.has_clip
	assert context.layers[0].clip_rect == none
	begin := lower_visual_layers([PaintCommand{ kind: 'child', visual_layer_list: context.layer_list }])[0]
	assert !begin.has_clip
	outer := tree.append(painting.ClipVisualData{ rect: painting.IntRect{0, 0, 10, 10} }, 0)
	disjoint := tree.append(painting.ClipVisualData{ rect: painting.IntRect{20, 20, 10, 10} }, outer)
	effect := tree.append(painting.EffectsVisualData{ opacity: 0.5 }, disjoint)
	empty := flatten_compatibility_visual_context(tree, effect, painting.ScrollStateSnapshot{})
	bounds := empty.layers[0].clip_rect or { panic('empty clip must remain present') }
	assert bounds.width == 0 && bounds.height == 0
	empty_begin := lower_visual_layers([PaintCommand{ kind: 'empty', visual_layer_list: empty.layer_list }])[0]
	assert empty_begin.has_clip
	assert empty_begin.clip_width == 0 && empty_begin.clip_height == 0
}
