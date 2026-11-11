module painting

import css

// Ladybird 830bdd3775c5: a new 3D context is flattened into its containing
// plane, so a hidden backface must also cull that context and its participants.
fn test_hidden_backface_culls_nested_contexts_in_short_and_deep_walks() {
	for depth in [0, inline_backface_chain_capacity + 1] {
		mut tree := AccumulatedVisualContextTree.create()
		rotation := css.rotation_matrix(css.FloatVector3{ y: 1 }, 3.141592653589793)
		flipped := tree.append(TransformVisualData{
			matrix_4x4:      rotation
			uses_matrix_4x4: true
		}, 0)
		hidden := tree.append(BackfaceVisibilityVisualData{}, flipped)
		mut parent := hidden
		for _ in 0 .. depth {
			parent = tree.append(TransformVisualData{}, parent)
		}
		context := tree.append(TransformVisualData{
			establishes_sorting_context: true
			resets_backface_culling:     true
		}, parent)
		participant := tree.append(TransformVisualData{
			matrix_4x4:              rotation
			uses_matrix_4x4:         true
			resets_backface_culling: true
		}, context)
		for index in [context, participant] {
			assert tree.context_is_backface_culled(index, ScrollStateSnapshot{})
			assert tree.context_is_backface_culled_with_depth_fallback(index, ScrollStateSnapshot{})
			assert tree.transform_point_for_hit_test(index, Point{10, 20}, ScrollStateSnapshot{}) == none
		}
	}
}

fn test_participants_reset_only_to_their_own_contexts_inherited_cull_state() {
	mut tree := AccumulatedVisualContextTree.create()
	context := tree.append(TransformVisualData{ establishes_sorting_context: true }, 0)
	flipped := tree.append(TransformVisualData{
		matrix_4x4:              css.rotation_matrix(css.FloatVector3{ y: 1 }, 3.141592653589793)
		uses_matrix_4x4:         true
		resets_backface_culling: true
	}, context)
	hidden := tree.append(BackfaceVisibilityVisualData{}, flipped)
	participant := tree.append(TransformVisualData{ resets_backface_culling: true }, hidden)
	assert !tree.context_is_backface_culled(participant, ScrollStateSnapshot{})
	assert tree.transform_point_for_hit_test(participant, Point{10, 20}, ScrollStateSnapshot{}) != none

	nested := tree.append(TransformVisualData{
		establishes_sorting_context: true
		resets_backface_culling:     true
	}, hidden)
	nested_participant := tree.append(TransformVisualData{ resets_backface_culling: true }, nested)
	assert tree.context_is_backface_culled(nested_participant, ScrollStateSnapshot{})
	// Resolving the nested context must not change a sibling's context state.
	sibling := tree.append(TransformVisualData{ resets_backface_culling: true }, context)
	assert !tree.context_is_backface_culled(sibling, ScrollStateSnapshot{})
}
