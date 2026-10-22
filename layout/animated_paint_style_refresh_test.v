module layout

import css
import dom
import html
import math

fn animation_paint_box_for_handle(box &BlockBox, handle voidptr) ?&BlockBox {
	if box.layout_handle == handle { return unsafe { box } }
	for index in 0 .. box.children.len {
		if found := animation_paint_box_for_handle(unsafe { &box.children[index] }, handle) { return found }
	}
	return none
}

fn test_sampled_parent_transform_retains_resources_and_updates_descendant_geometry_and_hits() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(100px)}}#target{width:30px;height:30px;animation:slide 1s linear forwards}#child{width:20px;height:20px;background:rgb(71 72 73)}</style><div id="target"><div id="child">text</div></div><svg id="unrelated" width="20" height="20"><path d="M0 0H20V20H0Z" fill="green"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	child := document.get_element_by_id('child') or { panic('missing child') }
	unrelated := document.get_element_by_id('unrelated') or { panic('missing svg') }
	svg_handle := unrelated.as_node().layout_node() or { panic('missing svg layout') }
	initial_svg := animation_paint_box_for_handle(&result.paint_tree, svg_handle.layout_handle) or { panic('missing svg transport') }
	svg_children := initial_svg.children.data
	child_layout := child.as_node().layout_node() or { panic('missing child layout') }
	initial_child := animation_paint_box_for_handle(&result.paint_tree, child_layout.layout_handle) or { panic('missing text transport') }
	text_lines := initial_child.lines.data
	paint_children := result.paint_tree.children.data
	layout_handle := document.layout_engine_handle()
	initial := record_retained_display_list(mut document) or { panic('missing paint') }
	initial_dump := initial.dump()
	document.update_animations_and_send_events(1000)
	document.update_layout(.html_event_loop_rendering_update)
	current := record_retained_display_list(mut document) or { panic('missing sampled paint') }
	assert document.layout_engine_handle() == layout_handle
	assert result.paint_tree.children.data == paint_children
	current_svg := animation_paint_box_for_handle(&result.paint_tree, svg_handle.layout_handle) or { panic('missing retained svg') }
	assert current_svg.children.data == svg_children
	current_child := animation_paint_box_for_handle(&result.paint_tree, child_layout.layout_handle) or { panic('missing retained text') }
	assert current_child.lines.data == text_lines
	assert child.get_bounding_client_rect().x == 100
	assert (document.element_from_point(110, 10) or { panic('missing transformed hit') }) == child
	assert (document.element_from_point(10, 10) or { panic('missing background hit') }) != child
	assert initial.dump() == initial_dump
	local_dump := current.dump()
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (record_retained_display_list(mut document) or { panic('missing full paint') }).dump() == local_dump
}

fn test_sampled_before_transform_reuses_pseudo_transport() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(50px)}}#target{width:100px;height:20px}#target::before{content:"";display:block;width:20px;height:20px;background:green;animation:slide 1s linear forwards}</style><div id="target"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	pseudo := dom.AbstractElement.new(target, .before)
	pseudo_styled := pseudo.unsafe_layout_node() or { panic('missing before layout') }
	pseudo_layout := pseudo_styled.layout_node_ or { panic('missing before placeholder') }
	initial := animation_paint_box_for_handle(&result.paint_tree, pseudo_layout.layout_handle) or { panic('missing before transport') }
	initial_address := voidptr(initial)
	paint_children := result.paint_tree.children.data
	_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
	document.update_animations_and_send_events(1000)
	document.update_layout(.html_event_loop_rendering_update)
	local := record_retained_display_list(mut document) or { panic('missing sampled paint') }
	current := animation_paint_box_for_handle(&result.paint_tree, pseudo_layout.layout_handle) or { panic('missing retained before') }
	assert voidptr(current) == initial_address
	assert result.paint_tree.children.data == paint_children
	assert current.own_paint_transform[4] == 50
	local_dump := local.dump()
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (record_retained_display_list(mut document) or { panic('missing full paint') }).dump() == local_dump
}

fn test_sampled_outer_svg_rotation_keeps_path_transport_and_matches_a_full_refresh() {
	image_url := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes turn{from{transform:rotate(0deg)}to{transform:rotate(180deg)}}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(50px)}}#target{display:block;width:40px;height:20px;margin-left:100px;margin-top:50px;overflow:hidden;transform-origin:5px 7px;opacity:0.5;animation:turn 1s linear forwards}#skeleton::before{content:"";display:block;width:20px;height:20px;background:blue;animation:slide 1s linear forwards}</style><svg id="target" viewBox="0 0 40 20"><defs><pattern id="tile" width="4" height="4" patternUnits="userSpaceOnUse"><image width="4" height="4" href="${image_url}"/></pattern></defs><path d="M0 0H40V20H0Z" fill="url(#tile)"/></svg><div id="skeleton"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing svg target') }
	placeholder := target.as_node().layout_node() or { panic('missing svg layout') }
	initial_box := animation_paint_box_for_handle(&result.paint_tree, placeholder.layout_handle) or { panic('missing svg transport') }
	children := initial_box.children.data
	initial_matrix := initial_box.own_paint_transform_4x4
	path_data := initial_box.children[0].svg_path().path_data.data
	image_pattern := initial_box.children[0].svg_path().fill_pattern or { panic('missing image pattern') }
	image_tile := image_pattern.tile_display_list or { panic('missing retained image tile') }
	assert image_tile.operations.any(it.kind == .image)
	paint_children := result.paint_tree.children.data
	initial := record_retained_display_list(mut document) or { panic('missing initial svg paint') }
	initial_dump := initial.dump()
	document.update_animations_and_send_events(1000)
	document.update_layout(.html_event_loop_rendering_update)
	local := record_retained_display_list(mut document) or { panic('missing rotated svg paint') }
	current_box := animation_paint_box_for_handle(&result.paint_tree, placeholder.layout_handle) or { panic('missing retained svg transport') }
	assert result.paint_tree.children.data == paint_children
	assert current_box.children.data == children
	assert current_box.children[0].svg_path().path_data.data == path_data
	current_pattern := current_box.children[0].svg_path().fill_pattern or { panic('missing retained image pattern') }
	current_tile := current_pattern.tile_display_list or { panic('missing retained image tile') }
	assert voidptr(current_tile) == voidptr(image_tile)
	assert current_tile.operations.data == image_tile.operations.data
	assert current_box.own_paint_transform_4x4.m11 < -0.9
	assert initial_matrix.m11 > 0.9
	assert math.abs(target.get_bounding_client_rect().width - 40) < 0.00001
	assert math.abs(target.get_bounding_client_rect().height - 20) < 0.00001
	assert math.abs(target.get_bounding_client_rect().x - 70) < 0.00001
	assert math.abs(target.get_bounding_client_rect().y - 44) < 0.00001
	hit := document.element_from_point(90, 54) or { panic('missing rotated svg hit') }
	assert hit == target || hit.local_name() == 'path'
	assert initial.dump() == initial_dump
	local_dump := local.dump()
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (record_retained_display_list(mut document) or { panic('missing full svg paint') }).dump() == local_dump
}

fn test_sampled_opacity_zero_and_recovery_rebuild_paint_steps_and_preserve_hits() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes fade{from{opacity:0.5}to{opacity:0}}#target{width:20px;height:20px;background:rgb(71 72 73);animation:fade 1s linear infinite alternate}</style><div id="target"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	initial := record_retained_display_list(mut document) or { panic('missing initial paint') }
	initial_dump := initial.dump()
	paint_children := result.paint_tree.children.data
	assert display_list_commands(initial).any(it.color == 'rgb(71 72 73)')
	for timestamp in [1000, 2000] {
		document.update_animations_and_send_events(timestamp)
		document.update_layout(.html_event_loop_rendering_update)
		paint := record_retained_display_list(mut document) or { panic('missing sampled opacity paint') }
		assert result.paint_tree.children.data == paint_children
		assert display_list_commands(paint).any(it.color == 'rgb(71 72 73)') == (timestamp == 2000)
		assert (document.element_from_point(10, 10) or { panic('missing transparent hit') }) == target
	}
	assert initial.dump() == initial_dump
}

fn test_non_compositor_same_pointer_sample_retains_the_full_refresh_fallback() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:20px;height:20px;background:green}</style><div id="target"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	placeholder := target.as_node().layout_node() or { panic('missing target layout') }
	computed := css.computed_properties_for_element(target) or { panic('missing style') }
	mut mutable_computed := unsafe { &css.ComputedProperties(computed) }
	mutable_computed.set_animated_property(.filter, &dom.StyleValue{css_text:'blur(2px)'}, .no, .no)
	placeholder.apply_animated_style(voidptr(computed), false)
	assert result.paint_style_update_requires_full_refresh
	document.set_needs_repaint_with_invalidation(.paint_commands)
	_ = record_retained_display_list(mut document) or { panic('missing filter paint') }
	assert !result.paint_tree_needs_style_update
	mutable_computed.remove_animated_property(.filter)
	placeholder.apply_animated_style(voidptr(computed), false)
	assert result.paint_style_update_requires_full_refresh
	document.set_needs_repaint_with_invalidation(.paint_commands)
	_ = record_retained_display_list(mut document) or { panic('missing restored paint') }
	assert !result.paint_tree_needs_style_update
}

fn test_sampled_compositor_category_changes_use_the_full_transport_refresh() {
	for keyframes in ['from{opacity:1}to{opacity:0.5}'] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes change{${keyframes}}#target{width:20px;height:20px;background:green;animation:change 1s linear forwards}</style><div id="target"></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 320, 200)
		result := document_layout_result(document) or { panic('missing layout') }
		_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
		paint_children := result.paint_tree.children.data
		layout_handle := document.layout_engine_handle()
		document.update_animations_and_send_events(1000)
		document.update_layout(.html_event_loop_rendering_update)
		_ = record_retained_display_list(mut document) or { panic('missing sampled paint') }
		assert document.layout_engine_handle() == layout_handle
		assert result.paint_tree.children.data != paint_children
	}
}

fn test_compositor_transform_presence_change_uses_the_full_transport_refresh() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:20px;height:20px;background:green}</style><div id="target"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	placeholder := target.as_node().layout_node() or { panic('missing target layout') }
	computed := css.computed_properties_for_element(target) or { panic('missing style') }
	_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
	paint_children := result.paint_tree.children.data
	mut mutable_computed := unsafe { &css.ComputedProperties(computed) }
	mutable_computed.set_animated_property(.transform, &dom.StyleValue{css_text:'translateX(50px)'}, .no, .no)
	placeholder.apply_animated_style(voidptr(computed), true)
	document.set_needs_repaint_with_invalidation(.paint_commands_and_hit_test_list)
	document.set_needs_accumulated_visual_contexts_update(true)
	_ = record_retained_display_list(mut document) or { panic('missing transformed paint') }
	assert result.paint_tree.children.data != paint_children
	assert target.get_bounding_client_rect().x == 50
}

fn test_published_before_after_handles_clear_on_layout_teardown_removal_and_regeneration() {
	mut document := html.parse_document('<!doctype html><style>#target::before{content:"before"}#target::after{content:"after"}</style><div id="parent"><div id="target">middle</div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	parent := document.get_element_by_id('parent') or { panic('missing parent') }
	before := (target.get_pseudo_element_node(int(dom.PseudoElement.before)) or { panic('missing before') }).layout_node_ or { panic('missing before placeholder') }
	_ = target.get_pseudo_element_node(int(dom.PseudoElement.after)) or { panic('missing after') }
	target.set_attribute_value('style', 'display:none')
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	assert target.get_pseudo_element_node(int(dom.PseudoElement.before)) == none
	assert target.get_pseudo_element_node(int(dom.PseudoElement.after)) == none
	target.set_attribute_value('style', 'display:block')
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	regenerated := (target.get_pseudo_element_node(int(dom.PseudoElement.before)) or { panic('missing regenerated before') }).layout_node_ or { panic('missing regenerated placeholder') }
	assert regenerated.layout_handle != before.layout_handle
	_ = target.get_pseudo_element_node(int(dom.PseudoElement.after)) or { panic('missing regenerated after') }
	mut target_node := unsafe { &dom.Node(target.as_node()) }
	target_node.remove(false)
	assert target.get_pseudo_element_node(int(dom.PseudoElement.before)) == none
	assert target.get_pseudo_element_node(int(dom.PseudoElement.after)) == none
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut parent_node := unsafe { &dom.Node(parent.as_node()) }
	parent_node.append_child(target.as_node()) or { panic(err) }
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	reinserted := (target.get_pseudo_element_node(int(dom.PseudoElement.before)) or { panic('missing reinserted before') }).layout_node_ or { panic('missing reinserted placeholder') }
	assert reinserted.layout_handle != regenerated.layout_handle
	_ = target.get_pseudo_element_node(int(dom.PseudoElement.after)) or { panic('missing reinserted after') }
}
