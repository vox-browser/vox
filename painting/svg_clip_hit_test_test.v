module painting

fn pointer_clip_square() ClipPathVisualData {
	return ClipPathVisualData{
		bounding_rect: IntRect{0, 0, 10, 10}
		polygon:       [Point{0, 0}, Point{10, 0}, Point{10, 10}, Point{0, 10}]
	}
}

fn test_svg_clip_hits_union_transformed_components_and_reject_gaps() {
	mut tree := AccumulatedVisualContextTree.create()
	index := tree.append(SVGClipVisualData{
		components: [
			SVGClipPathComponent{ path: pointer_clip_square(), transform: Affine{ e: 5 } },
			SVGClipPathComponent{ path: pointer_clip_square(), transform: Affine{ e: 30 } },
		]
	}, 0)
	assert tree.transform_point_for_hit_test(index, Point{6, 2}, ScrollStateSnapshot{})? == Point{6, 2}
	assert tree.transform_point_for_hit_test(index, Point{35, 2}, ScrollStateSnapshot{})? == Point{35, 2}
	assert tree.transform_point_for_hit_test(index, Point{22, 2}, ScrollStateSnapshot{}) == none
	assert tree.transform_point_for_hit_test(index, Point{6, 12}, ScrollStateSnapshot{}) == none
	mut hole := pointer_clip_square()
	hole = ClipPathVisualData{
		...hole
		polygons:  [hole.polygon, [Point{2, 2}, Point{8, 2}, Point{8, 8}, Point{2, 8}]]
		fill_rule: .even_odd
	}
	assert !SVGClipVisualData{ components: [SVGClipPathComponent{ path: hole }] }.contains(Point{5, 5})
	assert SVGClipVisualData{ components: [SVGClipPathComponent{ path: hole }] }.contains(Point{1, 1})
	resource := ClipPathVisualData{polygon: pointer_clip_square().polygon}
	assert SVGClipVisualData{components: [SVGClipPathComponent{path: resource}]}.contains(Point{5, 5})
}

fn test_svg_clip_hits_reject_empty_or_singular_resources_and_keep_masks_non_geometric() {
	assert !SVGClipVisualData{}.contains(Point{0, 0})
	assert !SVGClipVisualData{
		components: [SVGClipPathComponent{
			path:      pointer_clip_square()
			transform: Affine{ a: 0, d: 0 }
		}]
	}.contains(Point{0, 0})
	mut tree := AccumulatedVisualContextTree.create()
	clip := tree.append(SVGClipVisualData{ components: [SVGClipPathComponent{ path: pointer_clip_square() }] }, 0)
	mask := tree.append(SVGMaskVisualData{ bounding_rect: IntRect{0, 0, 1, 1} }, clip)
	effect := tree.append(EffectsVisualData{ opacity: 0 }, mask)
	assert tree.transform_point_for_hit_test(effect, Point{5, 5}, ScrollStateSnapshot{})? == Point{5, 5}
	assert tree.transform_point_for_hit_test(effect, Point{20, 5}, ScrollStateSnapshot{}) == none
}
