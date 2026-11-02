module layout

import dom
import html
import math

fn simple_svg_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn simple_svg_test_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	after := (document.record_display_list() or { panic('missing rebuilt paint') }).dump()
	if after != before {
		left := before.split_into_lines()
		right := after.split_into_lines()
		mut differences := 0
		for index in 0 .. left.len {
			if index < right.len && left[index] == right[index] { continue }
			eprintln('SVG paint difference ${index}: ${left[index][..math.min(left[index].len, 240)]}')
			if index < right.len { eprintln('SVG full layout ${index}: ${right[index][..math.min(right[index].len, 240)]}') }
			differences++
			if differences == 5 { break }
		}
	}
	assert after == before
}

fn simple_svg_test_document(contents string) &dom.Document {
	return html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="display:grid;width:200px;grid-template-columns:40px 1fr;gap:5px"><svg id="icon" width="24" height="24" viewBox="0 0 24 24">${contents}</svg><div>Wrapping text beside a static icon.</div></section>')
}

fn test_static_svg_parent_grid_reuses_geometry_after_movement_and_keeps_old_paint() {
	mut document := simple_svg_test_document('<g transform="translate(1 2)"><path id="path" d="M0 0H18V12H0Z" fill="red"/><circle cx="6" cy="6" r="3" fill="blue"/></g>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := simple_svg_test_node(document, 'stable')
	key := u64(voidptr(root))
	first := document_layout_result(document) or { panic('missing layout') }
	previous := first.state.block_layouts_[key] or { unsafe { &RetainedBlockLayout(nil) } }
	if !disable_retained_simple_svg { assert previous != unsafe { nil } }
	old := document.record_display_list() or { panic('missing paint') }
	scene := retain_display_list_scene(old)
	defer { release_display_list_scene(scene) }
	old_text := old.dump()
	old_y := document.get_element_by_id('icon')?.get_bounding_client_rect().y
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'height:50px')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('missing current layout') }
	if !disable_retained_simple_svg {
		assert voidptr(after.state.block_layouts_[key] or { panic('missing reused grid') }) == voidptr(previous)
	}
	assert old.dump() == old_text
	assert document.get_element_by_id('icon')?.get_bounding_client_rect().y == old_y + 50
	simple_svg_test_full_layout(mut document)
}

fn test_svg_attribute_inputs_reject_path_viewbox_transform_and_namespace_mutations() {
	for name in ['d', 'viewBox', 'transform', 'namespaced'] {
		mut document := simple_svg_test_document('<path id="path" d="M0 0H18V12H0Z" fill="red"/>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		icon := simple_svg_test_node(document, 'icon')
		input := retained_simple_svg_input(icon)
		mut target := document.get_element_by_id(if name == 'viewBox' { 'icon' } else { 'path' })?
		match name {
			'd' { target.set_attribute_value('d', 'M0 0H4V20H0Z') }
			'viewBox' { target.set_attribute_value('viewBox', '0 0 48 48') }
			'transform' { target.set_attribute_value('transform', 'translate(4 5)') }
			else { target.set_attribute_value_ns('test', 'value', 'x', 'urn:svg-retention-test') }
		}
		if saved := input { assert !retained_simple_svg_input_is_current(saved) }
		// Standalone SVG viewBox/transform edits need a geometry opportunity;
		// the browser replay owner normally supplies it. An unrelated mutation
		// also tests that an otherwise reusable grid checks these SVG inputs.
		mut changed := document.get_element_by_id('changed')?
		changed.set_attribute_value('style', 'height:5px')
		document.update_layout(.debugging)
		simple_svg_test_full_layout(mut document)
	}
}

fn test_static_svg_cache_rechecks_css_geometry_and_parent_size() {
	mut document := simple_svg_test_document('<rect id="path" width="50%" height="12" fill="red"/>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut root := document.get_element_by_id('stable')?
	mut path := document.get_element_by_id('path')?
	for style in ['width:30px;stroke:blue;stroke-width:3px', 'width:10px;fill:green'] {
		path.set_attribute_value('style', style)
		document.update_layout(.debugging)
		simple_svg_test_full_layout(mut document)
	}
	root.set_attribute_value('style', 'display:grid;width:100px;grid-template-columns:30px 1fr')
	document.update_layout(.debugging)
	simple_svg_test_full_layout(mut document)
}

fn test_svg_resource_instances_text_animation_and_foreign_content_keep_the_full_path() {
	for contents in ['<use href="#other"/>', '<text>SVG text</text>', '<foreignObject width="10" height="10"><div xmlns="http://www.w3.org/1999/xhtml">HTML</div></foreignObject>',
		'<path d="M0 0H10V10Z"><animate attributeName="opacity" values="0;1" dur="1s"/></path>',
		'<defs><clipPath id="clip"><rect width="4" height="4"/></clipPath></defs><rect width="10" height="10" clip-path="url(#clip)"/>'] {
		mut document := simple_svg_test_document(contents)
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		assert retained_simple_svg_input(simple_svg_test_node(document, 'icon')) == none
		root := simple_svg_test_node(document, 'stable')
		assert u64(voidptr(root)) !in (document_layout_result(document) or { panic('missing layout') }).state.block_layouts_
		simple_svg_test_full_layout(mut document)
	}
}

fn test_svg_input_rejects_inserted_nonlayout_animation_children_and_reordered_shapes() {
	mut document := simple_svg_test_document('<path id="first" d="M0 0H18V12H0Z"/><path id="second" d="M0 0H4V8H0Z"/>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	input := retained_simple_svg_input(simple_svg_test_node(document, 'icon'))
	mut icon := document.get_element_by_id('icon')?
	mut second := document.get_element_by_id('second')?
	icon.as_node().insert_before(second.as_node(), icon.as_node().first_child(), false)
	if saved := input { assert !retained_simple_svg_input_is_current(saved) }
	second_input := retained_simple_svg_input(simple_svg_test_node(document, 'icon'))
	animate := document.create_element_ns(dom.namespace_svg_uri, 'animate')!
	second.as_node().append_child(animate.as_node())!
	if saved := second_input { assert !retained_simple_svg_input_is_current(saved) }
}

fn test_svg_snapshot_bounds_and_css_resource_dependencies_keep_the_full_path() {
	for contents in ['<rect width="10" height="10"/>'.repeat(129), '<path d="' + 'M0 0H10V10Z'.repeat(8192) + '"/>'] {
		mut document := simple_svg_test_document(contents)
		defer { document.finalize() }
		mut values := []RetainedSVGElement{}
		mut budget := RetainedSVGInputBudget{}
		assert !collect_simple_svg_dom_inputs(document.get_element_by_id('icon')?, mut values, mut budget)
	}
	mut document := html.parse_document('<!doctype html><style>#path{fill:url(#outside)}</style><section id="stable" style="display:grid;width:200px"><svg width="24" height="24"><path id="path" d="M0 0H10V10Z"/></svg></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := simple_svg_test_node(document, 'stable')
	assert u64(voidptr(root)) !in (document_layout_result(document) or { panic('missing layout') }).state.block_layouts_
}
