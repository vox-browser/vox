module painting

fn tile_style_for_test(list &SVGPatternDisplayList) &SVGPatternPaintStyle {
	return &SVGPatternPaintStyle{
		tile_rect: Rect{0, 0, 10, 10}
		tile_display_list: list
	}
}

fn test_svg_pattern_tile_summary_counts_nested_draws_and_images() {
	child := tile_style_for_test(SVGPatternDisplayList.from_operations([
		SVGMaskPaintOperation{kind: .image, opacity: 0},
	]))
	assert !(child.shared_tile_info() or { panic('expected a supported child') }).has_images
	middle := tile_style_for_test(SVGPatternDisplayList.from_operations([
		SVGMaskPaintOperation{kind: .image},
		SVGMaskPaintOperation{kind: .path, fill_pattern: child},
	]))
	operations := [SVGMaskPaintOperation{kind: .path, fill_pattern: middle, stroke_pattern: child}]
	prepared := tile_style_for_test(SVGPatternDisplayList.from_operations(operations))
	raw := tile_style_for_test(&SVGPatternDisplayList{operations: operations})
	info := prepared.shared_tile_info() or { panic('expected a supported pattern') }
	assert info == (raw.shared_tile_info() or { panic('expected a supported raw pattern') })
	assert info.operations == 5
	assert info.depth == 3
	assert info.has_images
}

fn test_svg_pattern_tile_summary_keeps_combined_operation_and_depth_limits() {
	child := tile_style_for_test(SVGPatternDisplayList.from_operations(
		[]SVGMaskPaintOperation{len: svg_pattern_tile_max_operations / 2, init: SVGMaskPaintOperation{kind: .path}}))
	assert child.shared_tile_info() != none
	operations := [SVGMaskPaintOperation{kind: .path, fill_pattern: child, stroke_pattern: child}]
	assert tile_style_for_test(SVGPatternDisplayList.from_operations(operations)).shared_tile_info() == none
	assert tile_style_for_test(&SVGPatternDisplayList{operations: operations}).shared_tile_info() == none

	mut nested := tile_style_for_test(SVGPatternDisplayList.from_operations([]))
	for _ in 1 .. svg_pattern_tile_max_depth {
		nested = tile_style_for_test(SVGPatternDisplayList.from_operations([
			SVGMaskPaintOperation{kind: .path, fill_pattern: nested},
		]))
	}
	assert (nested.shared_tile_info() or { panic('expected the depth limit to be inclusive') }).depth == svg_pattern_tile_max_depth
	over_limit := tile_style_for_test(SVGPatternDisplayList.from_operations([
		SVGMaskPaintOperation{kind: .path, stroke_pattern: nested},
	]))
	assert over_limit.shared_tile_info() == none
}

fn test_svg_pattern_tile_summary_retains_filter_eligibility() {
	supported := GfxFilter{
		nodes: [GfxFilterNode{kind: 'saturate', input_ids: [-1]}]
		root_id: 0
	}
	tile := tile_style_for_test(SVGPatternDisplayList.from_operations([
		SVGMaskPaintOperation{kind: .begin_filter, filter: supported},
		SVGMaskPaintOperation{kind: .end_filter},
	]))
	assert tile.shared_tile_info() != none
	unsupported := GfxFilter{
		nodes: [GfxFilterNode{kind: 'blur', input_ids: [-1]}]
		root_id: 0
	}
	rejected := tile_style_for_test(SVGPatternDisplayList.from_operations([
		SVGMaskPaintOperation{kind: .begin_filter, filter: unsupported},
	]))
	assert rejected.shared_tile_info() == none
	parent := tile_style_for_test(SVGPatternDisplayList.from_operations([
		SVGMaskPaintOperation{kind: .path, fill_pattern: rejected},
	]))
	assert parent.shared_tile_info() == none
}
