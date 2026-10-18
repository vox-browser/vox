module layout

import css
import dom
import html
import painting
import platform

fn assert_flattened_contexts_match(expected CompatibilityFlattenedVisualContext, actual CompatibilityFlattenedVisualContext) {
	assert actual.transform == expected.transform
	assert actual.matrix_4x4 == expected.matrix_4x4
	assert actual.backface_culled == expected.backface_culled
	assert actual.has_clip == expected.has_clip
	assert actual.clip == expected.clip
	assert actual.group_opacity == expected.group_opacity
	assert actual.clips.len == expected.clips.len
	for index, clip in expected.clips {
		assert actual.clips[index].rect == clip.rect
		assert actual.clips[index].transform == clip.transform
		assert actual.clips[index].corner_radii == clip.corner_radii
		assert actual.clips[index].is_path == clip.is_path
		assert actual.clips[index].path_data == clip.path_data
	}
	assert actual.layers.len == expected.layers.len
	for index, layer in expected.layers {
		assert actual.layers[index].kind == layer.kind
		assert actual.layers[index].scope_id == layer.scope_id
		assert actual.layers[index].opacity == layer.opacity
		assert actual.layers[index].blend_mode == layer.blend_mode
		assert actual.layers[index].clip_rect == layer.clip_rect
	}
	assert (actual.clip_list == unsafe { nil }) == (expected.clip_list == unsafe { nil })
	if expected.clip_list != unsafe { nil } {
		assert actual.clip_list.items.len == expected.clip_list.items.len
	}
	assert (actual.layer_list == unsafe { nil }) == (expected.layer_list == unsafe { nil })
	if expected.layer_list != unsafe { nil } {
		assert actual.layer_list.items.len == expected.layer_list.items.len
	}
}

fn test_memoized_visual_contexts_match_the_ancestor_chain_walk() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:200px;height:100px;overflow:auto;border-radius:6px}#tall{height:400px}.layer{opacity:0.5;transform:translate(10px,4px) rotate(5deg);overflow:hidden;width:150px;height:60px}.inner{mix-blend-mode:multiply;filter:blur(1px);clip-path:inset(2px);width:80px;height:30px}.stage{transform-style:preserve-3d;perspective:100px}.card{transform:rotateY(120deg);backface-visibility:hidden;width:40px;height:40px;background:red}.front{transform:rotateY(10deg);backface-visibility:hidden;width:40px;height:40px;background:green}</style><div id="scroller"><div id="tall"><div class="layer"><div class="inner">text<div class="layer">nested</div></div></div><div class="stage"><div class="card"><div class="front"></div></div><div class="front"></div></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = document.record_display_list() or { panic('missing paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	tree := result.visual_context_tree
	assert tree.nodes.len > 8
	mut memo := new_compatibility_visual_context_memo(&tree, result.scroll_state_snapshot)
	// Resolve deepest nodes first so ancestors are reached through recursion.
	for index := tree.nodes.len - 1; index >= -1; index-- {
		expected := flatten_compatibility_visual_context(tree, index, result.scroll_state_snapshot)
		actual := memo.contexts[memo.resolve(index)]
		assert_flattened_contexts_match(expected, actual)
	}
	assert memo.resolve(tree.nodes.len) == 0
	assert memo.contexts.any(it.layers.len >= 2)
}

fn test_memoized_visual_contexts_match_plane_roots_scrolls_and_layers() {
	mut tree := painting.new_accumulated_visual_context_tree()
	scroll := tree.append(painting.ScrollVisualData{ scroll_frame_index: 1 }, 0)
	effect := tree.append(painting.EffectsVisualData{ opacity: 0.25 }, scroll)
	clip := tree.append(painting.ClipVisualData{ rect: painting.IntRect{2, 3, 40, 50} }, effect)
	rotation := tree.append(painting.TransformVisualData{
		matrix_4x4:      css.rotation_matrix(css.FloatVector3{ x: 0, y: 1 }, 3.141592653589793)
		uses_matrix_4x4: true
	}, clip)
	// Plane roots: an ancestor, the implicit root and a node outside the chain.
	culled := tree.append(painting.BackfaceVisibilityVisualData{ plane_root_index: clip }, rotation)
	root_plane := tree.append(painting.BackfaceVisibilityVisualData{ plane_root_index: 0 }, rotation)
	sibling := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{
			a: 2
			d: 3
			e: 13
		}
	}, effect)
	foreign_plane := tree.append(painting.BackfaceVisibilityVisualData{ plane_root_index: sibling }, rotation)
	recovered := tree.append(painting.TransformVisualData{
		matrix_4x4:      css.rotation_matrix(css.FloatVector3{ x: 0, y: 1 }, 3.141592653589793)
		uses_matrix_4x4: true
		resets_backface_culling: true
	}, culled)
	mask := tree.append(painting.SVGClipVisualData{
		bounding_rect: painting.IntRect{0, 0, 100, 100}
		scope_id:      99
		cache_key:     101
	}, sibling)
	nested_effect := tree.append(painting.EffectsVisualData{ opacity: 0.5 }, mask)
	compensation := tree.append(painting.ScrollCompensationVisualData{ scroll_frame_index: 1 }, nested_effect)
	snapshot := painting.ScrollStateSnapshot{
		device_offsets: [painting.Point{}, painting.Point{0, -40}]
	}
	mut memo := new_compatibility_visual_context_memo(&tree, snapshot)
	for index in [compensation, recovered, foreign_plane, root_plane, culled, 0, scroll, effect] {
		expected := flatten_compatibility_visual_context(tree, index, snapshot)
		actual := memo.contexts[memo.resolve(index)]
		assert_flattened_contexts_match(expected, actual)
	}
	assert memo.contexts[memo.resolve(culled)].backface_culled
	assert memo.contexts[memo.resolve(compensation)].layers.len == 3
	// Resolving a sibling must not leak its appended lists into its parent.
	assert memo.contexts[memo.resolve(effect)].layers.len == 1
	assert memo.contexts[memo.resolve(effect)].clips.len == 0
}

fn test_retained_display_list_scenes_survive_later_recordings() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:40px;background:rgb(71 72 73)}</style><div></div><div></div><div>text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first_list := document.record_display_list() or { panic('missing paint') }
	first := display_list_commands(first_list)
	first_kinds := first.map(it.kind)
	first_scene := retain_display_list_scene(first_list)
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 10, viewport.width, viewport.height})
	second_list := document.record_display_list() or { panic('missing second paint') }
	second := display_list_commands(second_list)
	assert second.data != first.data
	// The consumer still holds the first scene, so its commands stay intact.
	assert first.map(it.kind) == first_kinds
	assert normalized_affine(first[0].transform)[5] == 0
	assert normalized_affine(second[0].transform)[5] == -10
	release_display_list_scene(first_scene)
	document.set_viewport_rect(dom.Rect{viewport.x, 20, viewport.width, viewport.height})
	third_list := document.record_display_list() or { panic('missing third paint') }
	third := display_list_commands(third_list)
	assert third.map(it.kind) == first_kinds
	assert normalized_affine(third[0].transform)[5] == -20
	$if prealloc {
		if platform.arenas_poisoned() {
			return
		}
		// The released scene's storage is reused for the third recording.
		result := document_layout_result(document) or { panic('missing layout') }
		assert result.scene.arena.contains(first.data)
		assert result.scene.arena.contains(third.data)
	}
}

// Collector builds keep one command vector per recording and recycle the one
// the consumer returns; -prealloc reuses whole scenes instead.
fn test_returned_display_list_vectors_are_reused_without_touching_published_lists() {
	$if prealloc {
		return
	}
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:40px;background:rgb(71 72 73)}</style><div></div><div></div><div>text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first_list := document.record_display_list() or { panic('missing paint') }
	first := display_list_commands(first_list)
	first_kinds := first.map(it.kind)
	// The published vector itself is never accepted for reuse.
	recycle_display_list_commands(first_list, first)
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 10, viewport.width, viewport.height})
	second_list := document.record_display_list() or { panic('missing second paint') }
	second := display_list_commands(second_list)
	assert second.data != first.data
	assert first.map(it.kind) == first_kinds
	// Once the consumer adopts the second list and returns the first, the next
	// recording writes into the returned capacity and leaves the second intact.
	second_transforms := second.map(it.transform)
	recycle_display_list_commands(second_list, first)
	document.set_viewport_rect(dom.Rect{viewport.x, 20, viewport.width, viewport.height})
	third_list := document.record_display_list() or { panic('missing third paint') }
	third := display_list_commands(third_list)
	assert third.data == first.data
	assert third.map(it.kind) == first_kinds
	assert second.map(it.transform) == second_transforms
	assert normalized_affine(third[0].transform)[5] == -20
	assert normalized_affine(second[0].transform)[5] == -10
}
