module layout

import dom
import html

fn flow_svg_tree_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	return element.as_node().unsafe_layout_node() or { panic('layout absent') }.real_layout_handle()
}

fn flow_svg_tree_document(contents string, display string) &dom.Document {
	return html.parse_document('<!doctype html><style>body{margin:0}#stable{display:${display};width:240px;gap:7px}svg{flex:none}</style><div id="changed"></div><section id="stable"><svg id="icon" width="24" height="24" viewBox="0 0 24 24">${contents}</svg><p>Text beside a closed SVG.</p></section>')
}

fn flow_svg_tree_change_sibling(mut document dom.Document) {
	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_inner_html('<p>Changed preceding sibling</p>') or { panic(err) }
	document.update_layout(.debugging)
}

fn flow_svg_tree_full_oracle(mut document dom.Document) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	after := (document.record_display_list() or { panic('full paint') }).dump()
	if after != before {
		left := before.split_into_lines()
		right := after.split_into_lines()
		mut differences := 0
		for index in 0 .. left.len {
			if index < right.len && left[index] == right[index] { continue }
			eprintln('SVG tree before ${index}: ${left[index][..if left[index].len < 240 { left[index].len } else { 240 }]}')
			if index < right.len { eprintln('SVG tree after ${index}: ${right[index][..if right[index].len < 240 { right[index].len } else { 240 }]}') }
			differences++
			if differences == 3 { break }
		}
	}
	assert after == before
}

fn test_closed_svg_tree_retains_html_svg_and_shape_nodes_before_fresh_geometry() {
	for display in ['block', 'flex', 'grid;grid-template-columns:40px 1fr'] {
		mut document := flow_svg_tree_document('<g transform="translate(1 2)"><path id="shape" d="M0 0H18V12H0Z" fill="red"/><circle cx="6" cy="6" r="3" fill="blue"/></g>', display)
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		for _ in 0 .. 3 {
			before := ['stable', 'icon', 'shape'].map(flow_svg_tree_handle(document, it))
			flow_svg_tree_change_sibling(mut document)
			for index, id in ['stable', 'icon', 'shape'] {
				assert (flow_svg_tree_handle(document, id) == before[index]) == !disable_retained_flow_svg_trees
			}
			assert document.layout_is_up_to_date()
		}
		flow_svg_tree_full_oracle(mut document)
	}
}

fn test_retained_svg_tree_revalidates_attributes_paths_and_constructor_natural_metrics() {
	mut document := flow_svg_tree_document('<path id="shape" d="M0 0H18V12H0Z" fill="red"/>', 'block')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	flow_svg_tree_change_sibling(mut document)
	old := document.record_display_list()?
	scene := retain_display_list_scene(old)
	defer { release_display_list_scene(scene) }
	old_dump := old.dump()
	mut shape := document.get_element_by_id('shape')?
	for d in ['M0 0H9V20H0Z', 'M1 1L22 2L3 20Z'] {
		shape.set_attribute_value('d', d)
		document.update_layout(.debugging)
		flow_svg_tree_full_oracle(mut document)
		assert old.dump() == old_dump
	}
	mut icon := document.get_element_by_id('icon')?
	for width in ['48', '12', '36'] {
		icon.set_attribute_value('width', width)
		flow_svg_tree_change_sibling(mut document)
		assert icon.get_bounding_client_rect().width == f64(width.int())
		box := unsafe { &Box(flow_svg_tree_handle(document, 'icon')) }
		assert box.natural_size_ == negotiate_svg_natural_metrics(icon)
		flow_svg_tree_full_oracle(mut document)
	}
	icon.set_attribute_value('viewBox', '0 0 48 24')
	icon.set_attribute_value('preserveAspectRatio', 'none')
	shape.set_attribute_value('transform', 'translate(3 4) scale(0.5)')
	// As in the existing SVG retention checks, standalone SVG attributes need
	// a geometry opportunity; browser replay supplies one for script edits.
	flow_svg_tree_change_sibling(mut document)
	flow_svg_tree_full_oracle(mut document)
	assert old.dump() == old_dump
}

fn test_retained_svg_tree_revalidates_child_order_inherited_style_and_restyling() {
	mut document := flow_svg_tree_document('<rect id="first" width="20" height="20"/><circle id="last" cx="10" cy="10" r="8" fill="blue"/>', 'block')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	document.set_needs_full_style_update(true)
	document.update_style()
	flow_svg_tree_change_sibling(mut document)
	// Replacement styles still need the existing complete typed-input proof;
	// equal serialized CSS alone never establishes tree-cache eligibility.
	flow_svg_tree_full_oracle(mut document)
	mut stable := document.get_element_by_id('stable')?
	stable.set_attribute_value('style', 'width:120px;fill:red;color:purple')
	document.update_layout(.debugging)
	flow_svg_tree_full_oracle(mut document)
	mut icon := document.get_element_by_id('icon')?
	mut icon_node := icon.as_node()
	first := document.get_element_by_id('first')?
	icon_node.append_child(first.as_node())!
	document.update_layout(.debugging)
	flow_svg_tree_full_oracle(mut document)
	icon_node.remove_child(first.as_node())!
	document.update_layout(.debugging)
	flow_svg_tree_full_oracle(mut document)
}

fn test_svg_tree_resources_text_animation_and_css_url_paints_keep_full_builder() {
	for content in ['<text x="0" y="20">SVG text</text>',
		'<defs><linearGradient id="paint"><stop stop-color="red"/></linearGradient></defs><rect width="20" height="20" fill="url(#paint)"/>',
		'<use href="#other"/>', '<rect width="20" height="20"><animate attributeName="x" from="0" to="4" dur="1s"/></rect>',
		'<rect width="20" height="20" style="fill:url(#missing)"/>'] {
		mut document := flow_svg_tree_document(content, 'block')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		before := flow_svg_tree_handle(document, 'stable')
		flow_svg_tree_change_sibling(mut document)
		assert flow_svg_tree_handle(document, 'stable') != before
		flow_svg_tree_full_oracle(mut document)
	}
}

fn test_document_owned_svg_tree_keeps_old_paint_across_pool_and_scratch_retirement() {
	mut document := flow_svg_tree_document('<path id="shape" d="M0 0H18V12H0Z" fill="red"/>', 'grid;grid-template-columns:40px 1fr')
	document.enable_native_storage()
	defer { document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	old := document.record_display_list()?
	scene := retain_display_list_scene(old)
	defer { release_display_list_scene(scene) }
	old_dump := old.dump()
	for _ in 0 .. 3 {
		before := flow_svg_tree_handle(document, 'stable')
		flow_svg_tree_change_sibling(mut document)
		assert (flow_svg_tree_handle(document, 'stable') == before) == !disable_retained_flow_svg_trees
		gc_collect()
		assert old.dump() == old_dump
	}
	mut shape := document.get_element_by_id('shape')?
	shape.set_attribute_value('fill', 'green')
	document.update_layout(.debugging)
	flow_svg_tree_full_oracle(mut document)
	assert old.dump() == old_dump
}

fn test_retained_closed_svg_counters_keep_following_generated_content_in_order() {
	mut document := html.parse_document('<!doctype html><style>body{counter-reset:n}.count{counter-increment:n}#out::before{content:counter(n)}</style><div id="changed"></div><section id="stable" class="count"><svg width="24" height="24" class="count"><g class="count"><rect width="20" height="20"/></g></svg></section><div id="out"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	before := flow_svg_tree_handle(document, 'stable')
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p class="count">New counter</p>')!
	document.update_layout(.debugging)
	assert (flow_svg_tree_handle(document, 'stable') == before) == !disable_retained_flow_svg_trees
	recording := document.record_display_list()?
	scene := retain_display_list_scene(recording)
	defer { release_display_list_scene(scene) }
	commands := display_list_commands(recording)
	// Preserve the full counter resolver's scope behavior across the retained
	// SVG descendants; the full-builder oracle checks the generated value too.
	assert commands.any(it.kind == 'draw_text' && it.text.len > 0 && it.text != 'New counter')
	flow_svg_tree_full_oracle(mut document)
}

fn test_retained_svg_source_and_external_use_instances_keep_separate_dom_bindings() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section><svg id="source" width="24" height="24"><path id="shape" d="M0 0H20V20H0Z" fill="red"/></svg><svg width="48" height="48"><use href="#source" x="4" y="5"/></svg></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	for fill in ['red', 'blue', 'green'] {
		mut shape := document.get_element_by_id('shape')?
		shape.set_attribute_value('fill', fill)
		flow_svg_tree_change_sibling(mut document)
		flow_svg_tree_full_oracle(mut document)
		mirror := shape.as_node().unsafe_layout_node()?
		typed := unsafe { &Node(mirror.real_layout_handle()) }
		assert voidptr(typed.dom_node()?) == voidptr(shape.as_node())
	}
}
