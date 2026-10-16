module layout

import css
import dom
import html
import painting

fn patch_test_box_for_element(document &dom.Document, mut result DocumentLayoutResult, id string) &BlockBox {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	layout_node := element.as_node().layout_node() or { panic('missing ${id} layout') }
	return result.retained_box_for_layout(layout_node.layout_handle) or { panic('missing ${id} box') }
}

fn test_transform_samples_patch_the_retained_visual_context_tree() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(100px)}}#scroller{height:80px;overflow:auto}#tall{height:300px}#target{width:30px;height:30px;background:rgb(71 72 73);animation:slide 1s linear forwards}</style><div id="scroller"><div id="tall"><div id="target"></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	_ = document.record_display_list() or { panic('missing paint') }
	nodes := result.visual_context_tree.nodes.data
	node_count := result.visual_context_tree.nodes.len
	frames := result.scroll_state.frames.data
	box := patch_test_box_for_element(document, mut result, 'target')
	assert box.own_transform_visual_context_idx > 0
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	assert !document.document_needs_accumulated_visual_contexts_update()
	// Geometry consumers see the sampled transform before any repaint.
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect().x == 50
	assert result.visual_context_tree.nodes.data == nodes
	assert result.visual_context_tree.nodes.len == node_count
	assert result.scroll_state.frames.data == frames
	transform := result.visual_context_tree.node_at(box.own_transform_visual_context_idx).data as painting.TransformVisualData
	assert transform.uses_matrix_4x4
	assert transform.matrix_4x4.m14 == 50
	sampled := (document.record_display_list() or { panic('missing sampled paint') }).dump()
	assert result.visual_context_tree.nodes.data == nodes
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == sampled
}

fn test_opacity_samples_patch_effect_nodes_and_match_a_full_refresh() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes fade{from{opacity:0.8}to{opacity:0.2}}#target{width:30px;height:30px;background:rgb(71 72 73);animation:fade 1s linear forwards}</style><div id="target"><span>text</span></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	_ = document.record_display_list() or { panic('missing paint') }
	nodes := result.visual_context_tree.nodes.data
	box := patch_test_box_for_element(document, mut result, 'target')
	assert box.own_effects_visual_context_idx > 0
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	sampled := (document.record_display_list() or { panic('missing sampled paint') }).dump()
	assert result.visual_context_tree.nodes.data == nodes
	effects := result.visual_context_tree.node_at(box.own_effects_visual_context_idx).data as painting.EffectsVisualData
	assert effects.opacity > 0.49 && effects.opacity < 0.51
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == sampled
}

fn test_samples_that_change_the_node_set_are_not_patched() {
	mut tree := painting.new_accumulated_visual_context_tree()
	transform := tree.append(painting.TransformVisualData{
		matrix_4x4:      css.FloatMatrix4x4.identity()
		uses_matrix_4x4: true
	}, 0)
	effects := tree.append(painting.EffectsVisualData{ opacity: 0.5 }, transform)
	mut box := BlockBox{
		opacity:                          0.25
		uses_own_paint_transform_4x4:     true
		own_transform_visual_context_idx: transform
		own_effects_visual_context_idx:   effects
	}
	assert patch_compositor_visual_contexts(mut tree, [&box])
	assert (tree.node_at(effects).data as painting.EffectsVisualData).opacity == 0.25
	// Opacity reaching 1 would drop the effects node; a lost transform would
	// drop the transform node. Either needs a rebuild, and nothing is written.
	box.opacity = 1.0
	assert !patch_compositor_visual_contexts(mut tree, [&box])
	box.opacity = 0.75
	box.uses_own_paint_transform_4x4 = false
	assert !patch_compositor_visual_contexts(mut tree, [&box])
	assert (tree.node_at(effects).data as painting.EffectsVisualData).opacity == 0.25
	mut stale := BlockBox{
		opacity:                          0.5
		own_effects_visual_context_idx:   transform
	}
	assert !patch_compositor_visual_contexts(mut tree, [&stale])
	assert !tree.replace_compositor_values(effects, painting.TransformVisualData{})
}
