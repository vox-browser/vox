module layout

import css
import html
import painting

fn test_replay_and_hit_testing_keep_the_cull_state_outside_a_nested_3d_context() {
	mut tree := painting.AccumulatedVisualContextTree.create()
	visible_context := tree.append(painting.TransformVisualData{
		establishes_sorting_context: true
	}, 0)
	flipped := tree.append(painting.TransformVisualData{
		matrix_4x4:              css.rotation_matrix(css.FloatVector3{ y: 1 }, 3.141592653589793)
		uses_matrix_4x4:         true
		resets_backface_culling: true
	}, visible_context)
	hidden := tree.append(painting.BackfaceVisibilityVisualData{}, flipped)
	ordinary_participant := tree.append(painting.TransformVisualData{
		resets_backface_culling: true
	}, hidden)
	nested_context := tree.append(painting.TransformVisualData{
		establishes_sorting_context: true
		resets_backface_culling:     true
	}, hidden)
	nested_participant := tree.append(painting.TransformVisualData{
		resets_backface_culling: true
	}, nested_context)
	mut memo := new_compatibility_visual_context_memo(&tree, painting.ScrollStateSnapshot{})
	for index in [nested_participant, ordinary_participant, nested_context, hidden, visible_context] {
		expected := index in [hidden, nested_context, nested_participant]
		chain := flatten_compatibility_visual_context(tree, index, painting.ScrollStateSnapshot{})
		cached := memo.contexts[memo.resolve(index)]
		assert chain.backface_culled == expected
		assert cached.backface_culled == expected
		assert cached.backface_culled_outside_sorting_context == chain.backface_culled_outside_sorting_context
		assert tree.context_is_backface_culled(index, painting.ScrollStateSnapshot{}) == expected
	}
}

fn test_layout_distinguishes_nested_3d_context_roots_from_participants() {
	mut document := html.parse_document('<!doctype html><style>div{width:100px;height:100px}#hidden{transform:rotateY(180deg);backface-visibility:hidden}#nested,#extended{transform-style:preserve-3d}#participant{transform:translateZ(10px)}</style><div id="hidden"><div id="nested"><div id="extended"><div id="participant"></div></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = document.record_display_list() or { panic('missing display list') }
	mut result := document_layout_result(document) or { panic('missing layout') }
	mut context_roots := 0
	for node in result.visual_context_tree.nodes {
		if node.data is painting.TransformVisualData && node.data.establishes_sorting_context {
			context_roots++
		}
	}
	assert context_roots == 1
	for id in ['nested', 'extended', 'participant'] {
		element := document.get_element_by_id(id) or {
			panic('missing ${id}')
		}
		handle := element.as_node().unsafe_layout_node() or { panic('missing layout node') }.real_layout_handle()
		box := result.retained_box_for_layout(handle) or { panic('missing paint box') }
		index := box.accumulated_visual_context_index
		assert result.visual_context_tree.context_is_backface_culled(index, result.scroll_state_snapshot)
		assert flatten_compatibility_visual_context(result.visual_context_tree, index,
			result.scroll_state_snapshot).backface_culled
	}
}
