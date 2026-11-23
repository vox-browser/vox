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

fn test_svg_pattern_tile_summary_skips_unsupported_filters_only_inside_invisible_scopes() {
	blur := SVGMaskPaintOperation{
		kind: .begin_filter
		filter: GfxFilter{operations: [GfxFilterOperation{kind: 'blur', first: 1}]}
	}
	for opacity in [.003, .004] {
		for by_filter in [false, true] {
			opening := if by_filter {
				SVGMaskPaintOperation{
					kind: .begin_filter
					filter: GfxFilter{operations: [GfxFilterOperation{
						kind: 'color', color_operation: .opacity, first: opacity
					}]}
				}
			} else {
				SVGMaskPaintOperation{kind: .begin_opacity, opacity: opacity}
			}
			closing := SVGMaskPaintOperation{kind: if by_filter { .end_filter } else { .end_opacity }}
			operations := [opening, blur, SVGMaskPaintOperation{kind: .image},
				SVGMaskPaintOperation{kind: .end_filter}, closing]
			style := tile_style_for_test(SVGPatternDisplayList.from_operations(operations))
			if opacity == .003 {
				info := style.shared_tile_info() or { panic('invisible filters need no raster support') }
				assert !info.has_images
				assert info.operations == operations.len
				with_visible_image := tile_style_for_test(SVGPatternDisplayList.from_operations(
					[...operations, SVGMaskPaintOperation{kind: .image}]))
				assert (with_visible_image.shared_tile_info() or { panic('expected eligible sibling') }).has_images
			} else {
				assert style.shared_tile_info() == none
			}
		}
	}
}

fn test_svg_pattern_scope_end_rejects_crossed_and_unclosed_scopes() {
	opening := SVGMaskPaintOperation{kind: .begin_opacity, opacity: .003}
	filter := SVGMaskPaintOperation{kind: .begin_filter}
	scope_end := SVGMaskPaintOperation{kind: .end_opacity}
	filter_end := SVGMaskPaintOperation{kind: .end_filter}
	assert svg_pattern_scope_end([opening, filter, scope_end, filter_end], 0) == none
	assert svg_pattern_scope_end([opening, filter, filter_end], 0) == none
	assert (svg_pattern_scope_end([opening, filter, filter_end, scope_end], 0) or { -1 }) == 3
}
