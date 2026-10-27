module painting

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_common_visual_context_hit_tests_do_not_allocate_backface_maps() {
	mut tree := new_accumulated_visual_context_tree()
	clip := tree.append(ClipVisualData{ rect: IntRect{0, 0, 100, 100} }, 0)
	leaf := tree.append(ScrollVisualData{}, clip)
	for _ in 0 .. 1000 {
		tree.append(ClipVisualData{ rect: IntRect{0, 0, 100, 100} }, 0)
	}
	snapshot := ScrollStateSnapshot{}
	point := tree.transform_point_for_hit_test(leaf, Point{20, 30}, snapshot) or {
		panic('clipped point')
	}
	assert point == Point{20, 30}
	assert tree.transform_point_for_hit_test(leaf, Point{120, 30}, snapshot) == none
	$if gcboehm ? {
		before := C.GC_get_total_bytes()
		for _ in 0 .. 1000 {
			mapped := tree.transform_point_for_hit_test(leaf, Point{20, 30}, snapshot) or {
				panic('clipped point')
			}
			assert mapped == Point{20, 30}
		}
		assert C.GC_get_total_bytes() - before < 4096
	}
}

fn test_visual_context_backface_presence_follows_ancestors_and_siblings() {
	mut tree := new_accumulated_visual_context_tree()
	ordinary := tree.append(ScrollVisualData{}, 0)
	assert !tree.nodes[ordinary].has_backface_visibility
	backface := tree.append(BackfaceVisibilityVisualData{}, ordinary)
	child := tree.append(ClipVisualData{ rect: IntRect{0, 0, 100, 100} }, backface)
	sibling := tree.append(ScrollVisualData{}, ordinary)
	assert tree.nodes[backface].has_backface_visibility
	assert tree.nodes[child].has_backface_visibility
	assert !tree.nodes[sibling].has_backface_visibility
	assert !tree.context_is_backface_culled(child, ScrollStateSnapshot{})
}
