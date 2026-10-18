module layout

import css
import math
import painting

fn partial_border_box() BlockBox {
	color := css.Color{12, 12, 12, 255}
	return BlockBox{
		snaps_background_rect: true
		border: BoxEdges{0, 2, 2, 0}
		border_colors: BoxColors{color, color, color, color}
		own_paint_transform: affine_around_origin([math.sqrt(0.5), -math.sqrt(0.5), math.sqrt(0.5), math.sqrt(0.5), f64(0), 0]!, 86, 46.5)
	}
}

fn partial_border_assert_close(actual [6]f64, expected [6]f64) {
	for i, value in actual { assert math.abs(value - expected[i]) < 1e-10 }
}

fn test_chromium_partial_border_uses_overlapping_local_rectangles_and_keeps_layout_origin() {
	box := partial_border_box()
	mut commands := []PaintCommand{}
	assert append_chromium_partial_border(mut commands, &box, box.border_colors, BoxRadii{}, LayoutRect{80, 40.5, 12, 12}, 1)
	assert commands.len == 2
	assert commands[0].kind == 'fill_rect' && commands[0].antialiased_rect
	assert [commands[0].x, commands[0].y, commands[0].width, commands[0].height] == [f64(10), 0, 2, 12]
	assert [commands[1].x, commands[1].y, commands[1].width, commands[1].height] == [f64(0), 10, 12, 2]
	assert commands[0].opacity == 1 && commands[0].force_dark_role == .border
	assert commands[0].local_border_data == commands[1].local_border_data
	assert commands[0].local_border_data.origin_y == 40.5
	actual := chromium_local_border_transform(commands[0].local_border_data, box.own_paint_transform, box.own_paint_transform)
	expected := multiply_affine(affine_around_origin([math.sqrt(0.5), -math.sqrt(0.5), math.sqrt(0.5), math.sqrt(0.5), f64(0), 0]!, 86, 47), translated_affine(80, 41))
	partial_border_assert_close(actual, expected)
}

fn test_chromium_partial_border_preserves_fallbacks() {
	base := partial_border_box()
	color := css.Color{12, 12, 12, 255}
	for box in [
		BlockBox{...base, snaps_background_rect: false},
		BlockBox{...base, own_paint_transform: [6]f64{}},
		BlockBox{...base, own_paint_transform: translated_affine(1, 2)},
		BlockBox{...base, border: BoxEdges{}},
		BlockBox{...base, border: BoxEdges{2, 2, 2, 2}},
		BlockBox{...base, border: BoxEdges{0, 2.5, 2, 0}},
		BlockBox{...base, border_styles: BoxBorderStyles{right: .dashed}},
		BlockBox{...base, border_colors: BoxColors{color, css.Color{12, 12, 12, 128}, color, color}},
		BlockBox{...base, border_colors: BoxColors{color, css.Color{255, 0, 0, 255}, color, color}},
	] {
		mut commands := []PaintCommand{}
		assert !append_chromium_partial_border(mut commands, &box, box.border_colors, BoxRadii{}, LayoutRect{80, 40.5, 12, 12}, 1)
		assert commands.len == 0
	}
	mut commands := []PaintCommand{}
	assert !append_chromium_partial_border(mut commands, &base, base.border_colors, BoxRadii{}, LayoutRect{80, 40.5, 12, 12}, 0.75)
	assert commands.len == 0
	assert !append_chromium_partial_border(mut commands, &base, base.border_colors, BoxRadii{top_left: CornerRadius{2, 2}}, LayoutRect{80, 40.5, 12, 12}, 1)
}

fn test_chromium_partial_border_scale_preserves_the_untransformed_axis_fraction() {
	data := PaintLocalBorderData{origin_x: 80.25, origin_y: 40.5}
	for own, expected in {
		'x': [f64(2), 0, 0, 1, 160.25, 40.5]!
		'y': [f64(1), 0, 0, 3, 80.25, 122]!
	} {
		matrix := if own == 'x' { [f64(2), 0, 0, 1, 0, 0]! } else { [f64(1), 0, 0, 3, 0, 0]! }
		partial_border_assert_close(chromium_local_border_transform(&data, matrix, matrix), expected)
	}
}

fn test_chromium_partial_border_replay_reads_live_own_and_ancestor_transforms() {
	mut tree := painting.new_accumulated_visual_context_tree()
	parent := tree.append(painting.TransformVisualData{matrix: painting.Affine{a: 2, d: 3, e: 17, f: 19}}, 0)
	child := tree.append(painting.TransformVisualData{matrix: painting.Affine{a: 0, b: -1, c: 1, d: 0}}, parent)
	mut box := partial_border_box()
	box.own_transform_visual_context_idx = child
	box.accumulated_visual_context_index = child
	mut source := []PaintCommand{}
	assert append_chromium_partial_border(mut source, &box, box.border_colors, BoxRadii{}, LayoutRect{80.25, 40.5, 12, 12}, 1)
	steps := [CompatibilityPaintStep{box: &box, phase: .border, entry_index: 0}]
	mut buckets := [][]PaintCommand{len: compatibility_paint_phase_count}
	buckets[int(CompatibilityPaintPhase.border)] = source
	for own in [
		painting.Affine{a: 0, b: -1, c: 1, d: 0},
		painting.Affine{a: 1, b: 0.25, c: 0.5, d: 1, e: 3, f: 5},
		painting.Affine{e: 7, f: 9},
	] {
		tree.replace_compositor_values(child, painting.TransformVisualData{matrix: own})
		full := flatten_compatibility_visual_context(tree, child, painting.ScrollStateSnapshot{})
		expected := chromium_local_border_transform(source[0].local_border_data, full.transform, [own.a, own.b, own.c, own.d, own.e, own.f]!)
		old, _ := replay_cached_paint_commands_with_visual_context(steps, buckets, 2, tree, painting.ScrollStateSnapshot{}, false)
		actual := record_cached_paint_commands_with_visual_context(steps, buckets, 2, tree, painting.ScrollStateSnapshot{}, false)
		assert actual.len == 2 && old.len == 2
		partial_border_assert_close(actual[0].transform, expected)
		partial_border_assert_close(old[0].transform, expected)
		assert source[0].transform == [6]f64{}
	}
}
