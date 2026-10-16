module layout

import css
import dom
import html
import painting

fn frame_cost_pseudo_box(document &dom.Document, mut result DocumentLayoutResult, id string) &BlockBox {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	pseudo := dom.AbstractElement.new(element, .before)
	styled := pseudo.unsafe_layout_node() or { panic('missing ${id} before') }
	layout_node := styled.layout_node_ or { panic('missing ${id} placeholder') }
	return result.retained_box_for_layout(layout_node.layout_handle) or { panic('missing ${id} box') }
}

fn frame_cost_box_for_element(document &dom.Document, mut result DocumentLayoutResult, id string) &BlockBox {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	layout_node := element.as_node().layout_node() or { panic('missing ${id} layout') }
	return result.retained_box_for_layout(layout_node.layout_handle) or { panic('missing ${id} box') }
}

fn test_offscreen_clipped_infinite_pseudo_transform_animations_skip_sampling_until_visible() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes shine{from{transform:translateX(0)}to{transform:translateX(100px)}}.tag{position:relative;overflow:hidden;width:60px;height:20px}.tag::before{content:"";position:absolute;left:0;top:0;width:20px;height:20px;background:green;animation:shine 1s linear infinite}#once::before{animation-iteration-count:1}.spacer{height:900px}#element{width:20px;height:20px;animation:shine 1s linear infinite}</style><div class="tag" id="visible"></div><div class="spacer"></div><div class="tag" id="far"></div><div class="tag" id="once"></div><div id="element"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	_ = document.record_display_list() or { panic('missing paint') }
	initial_far := frame_cost_pseudo_box(document, mut result, 'far').own_paint_transform
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	_ = document.record_display_list() or { panic('missing sampled paint') }
	assert normalized_affine(frame_cost_pseudo_box(document, mut result, 'visible').own_paint_transform)[4] == 50
	// Clipped outside the viewport: the infinite pseudo transform is not sampled.
	assert frame_cost_pseudo_box(document, mut result, 'far').own_paint_transform == initial_far
	// Finite animations and element targets keep main-thread sampling.
	assert normalized_affine(frame_cost_pseudo_box(document, mut result, 'once').own_paint_transform)[4] == 50
	assert normalized_affine(frame_cost_box_for_element(document, mut result, 'element').own_paint_transform)[4] == 50
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 850, viewport.width, viewport.height})
	document.update_animations_and_send_events(700)
	document.update_layout(.html_event_loop_rendering_update)
	_ = document.record_display_list() or { panic('missing scrolled paint') }
	// Scrolling the clip into view resumes sampling at the current time.
	assert normalized_affine(frame_cost_pseudo_box(document, mut result, 'far').own_paint_transform)[4] == 70
	// The first tag has scrolled out; it keeps its last sampled value.
	assert normalized_affine(frame_cost_pseudo_box(document, mut result, 'visible').own_paint_transform)[4] == 50
}

fn test_clip_walk_matches_the_flattened_effective_clip() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:200px;height:100px;overflow:auto;border-radius:6px}#tall{height:400px}.layer{opacity:0.5;transform:translate(10px,4px) rotate(5deg);overflow:hidden;width:150px;height:60px}.inner{mix-blend-mode:multiply;filter:blur(1px);clip-path:inset(2px);width:80px;height:30px}.stage{transform-style:preserve-3d;perspective:100px}.card{transform:rotateY(120deg);backface-visibility:hidden;width:40px;height:40px;background:red}.front{transform:rotateY(10deg);backface-visibility:hidden;width:40px;height:40px;background:green}</style><div id="scroller"><div id="tall"><div class="layer"><div class="inner">text<div class="layer">nested</div></div></div><div class="stage"><div class="card"><div class="front"></div></div><div class="front"></div></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = document.record_display_list() or { panic('missing paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	page_tree := result.visual_context_tree
	assert page_tree.nodes.len > 8
	mut clipped := 0
	for index in -1 .. page_tree.nodes.len + 1 {
		expected := flatten_compatibility_visual_context(page_tree, index, result.scroll_state_snapshot)
		clip := compatibility_visual_context_clip(&page_tree, index, result.scroll_state_snapshot)
		assert clip.transform == expected.transform
		assert clip.has_clip == expected.has_clip
		assert clip.clip == expected.clip
		if clip.has_clip { clipped++ }
	}
	assert clipped > 0
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
	for index in 0 .. tree.nodes.len {
		expected := flatten_compatibility_visual_context(tree, index, snapshot)
		lean := compatibility_visual_context_clip(&tree, index, snapshot)
		assert lean.transform == expected.transform
		assert lean.has_clip == expected.has_clip
		assert lean.clip == expected.clip
	}
	_ = [compensation, recovered, foreign_plane, root_plane]
}
