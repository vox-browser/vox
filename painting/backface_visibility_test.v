module painting

import css

fn test_backface_visibility_culls_back_facing_contexts_and_hit_tests() {
	mut tree := AccumulatedVisualContextTree.create()
	rotation := css.rotation_matrix(css.FloatVector3{ x: 0, y: 1, z: 0 }, math_pi())
	transform := tree.append(TransformVisualData{
		matrix_4x4: rotation
		uses_matrix_4x4: true
	}, 0)
	marker := tree.append(BackfaceVisibilityVisualData{ plane_root_index: 0 }, transform)
	snapshot := ScrollStateSnapshot{}
	assert tree.context_is_backface_culled(marker, snapshot)
	assert tree.transform_point_for_hit_test(marker, Point{10, 20}, snapshot) == none
}

fn test_backface_visibility_keeps_front_facing_contexts() {
	mut tree := AccumulatedVisualContextTree.create()
	transform := tree.append(TransformVisualData{
		matrix_4x4: css.FloatMatrix4x4.identity()
		uses_matrix_4x4: true
	}, 0)
	marker := tree.append(BackfaceVisibilityVisualData{ plane_root_index: 0 }, transform)
	snapshot := ScrollStateSnapshot{}
	assert !tree.context_is_backface_culled(marker, snapshot)
	point := tree.transform_point_for_hit_test(marker, Point{10, 20}, snapshot) or {
		panic('front face should remain hittable')
	}
	assert point == Point{10, 20}
}

fn test_backface_visibility_is_relative_to_its_plane_root() {
	mut tree := AccumulatedVisualContextTree.create()
	rotation := css.rotation_matrix(css.FloatVector3{ x: 0, y: 1, z: 0 }, math_pi())
	plane_root := tree.append(TransformVisualData{
		matrix_4x4: rotation
		uses_matrix_4x4: true
	}, 0)
	child := tree.append(TransformVisualData{
		matrix_4x4: rotation
		uses_matrix_4x4: true
	}, plane_root)
	marker := tree.append(BackfaceVisibilityVisualData{ plane_root_index: plane_root }, child)
	assert tree.context_is_backface_culled(marker, ScrollStateSnapshot{})
}

fn test_3d_sorting_plane_resets_ancestor_backface_culling() {
	mut tree := AccumulatedVisualContextTree.create()
	rotation := css.rotation_matrix(css.FloatVector3{ x: 0, y: 1, z: 0 }, math_pi())
	ancestor_transform := tree.append(TransformVisualData{
		matrix_4x4: rotation
		uses_matrix_4x4: true
	}, 0)
	ancestor_marker := tree.append(BackfaceVisibilityVisualData{ plane_root_index: 0 }, ancestor_transform)
	assert tree.context_is_backface_culled(ancestor_marker, ScrollStateSnapshot{})

	descendant_plane := tree.append(TransformVisualData{
		resets_backface_culling: true
	}, ancestor_marker)
	assert !tree.context_is_backface_culled(descendant_plane, ScrollStateSnapshot{})
}

fn math_pi() f64 {
	return 3.141592653589793
}

fn test_inline_backface_walk_matches_the_map_walk() {
	mut tree := AccumulatedVisualContextTree.create()
	rotation := css.rotation_matrix(css.FloatVector3{ x: 0, y: 1, z: 0 }, math_pi())
	tilt := css.rotation_matrix(css.FloatVector3{ x: 1, y: 0, z: 0 }, math_pi() / 3)
	scroll := tree.append(ScrollVisualData{ scroll_frame_index: 1 }, 0)
	turned := tree.append(TransformVisualData{
		matrix_4x4: rotation
		uses_matrix_4x4: true
	}, scroll)
	tilted := tree.append(TransformVisualData{
		matrix_4x4: tilt
		uses_matrix_4x4: true
	}, turned)
	// Plane roots: the implicit root, an ancestor, the marker itself and a node
	// outside the chain.
	mut markers := []int{}
	markers << tree.append(BackfaceVisibilityVisualData{ plane_root_index: 0 }, tilted)
	markers << tree.append(BackfaceVisibilityVisualData{ plane_root_index: turned }, tilted)
	markers << tree.append(BackfaceVisibilityVisualData{ plane_root_index: tree.nodes.len }, tilted)
	outside := tree.append(TransformVisualData{
		matrix_4x4: tilt
		uses_matrix_4x4: true
	}, 0)
	markers << tree.append(BackfaceVisibilityVisualData{ plane_root_index: outside }, tilted)
	reset := tree.append(TransformVisualData{
		matrix_4x4: rotation
		uses_matrix_4x4: true
		resets_backface_culling: true
	}, markers[0])
	markers << tree.append(BackfaceVisibilityVisualData{ plane_root_index: scroll }, reset)
	mut deep := markers.last()
	for _ in 0 .. inline_backface_chain_capacity + 2 {
		deep = tree.append(TransformVisualData{
			matrix_4x4: tilt
			uses_matrix_4x4: true
		}, deep)
	}
	markers << tree.append(BackfaceVisibilityVisualData{ plane_root_index: turned }, deep)
	snapshot := ScrollStateSnapshot{
		device_offsets: [Point{}, Point{0, -40}]
	}
	mut culled := 0
	for marker in markers {
		expected := tree.context_is_backface_culled_with_depth_fallback(marker, snapshot)
		assert tree.context_is_backface_culled(marker, snapshot) == expected
		if tree.nodes[marker].depth <= inline_backface_chain_capacity {
			assert tree.inline_context_is_backface_culled(marker, snapshot) == expected
		}
		if expected { culled++ }
	}
	assert culled > 0 && culled < markers.len
}
