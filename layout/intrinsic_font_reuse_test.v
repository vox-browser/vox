module layout

import css
import html
import os

fn intrinsic_epoch_layout_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := intrinsic_epoch_layout_node(child, id) { return found }
	}
	return none
}

fn prepare_intrinsic_epoch_fonts(node &Node) {
	computer := css.css_style_computer_for(node.document()).font_computer()
	_ = node.computed_values().computed_font_list(computer)
	for child in node.children() { prepare_intrinsic_epoch_fonts(child) }
}

fn test_intrinsic_sizes_survive_unrelated_font_completion_without_changing_geometry() {
	mut document := html.parse_document('<!doctype html><style>body{font:16px/20px monospace}#subject{display:inline-grid;grid-template-columns:auto auto;gap:7px}</style><div id="subject"><div>several words here</div><div style="width:31px">x</div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	prepare_intrinsic_epoch_fonts(result.root)
	node := intrinsic_epoch_layout_node(result.root, 'subject')?
	mut box := node.as_box()?
	box.reset_cached_intrinsic_sizes()
	mut state := result.state
	minimum := calculate_min_content_width(mut state, box)
	maximum := calculate_max_content_width(mut state, box)
	mut original := box.cached_intrinsic_sizes()
	original.cache_content_height(true, 123, CSSPixels.new(42))
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedIntrinsicFamily')
	prepare_intrinsic_epoch_fonts(result.root)
	retained := box.cached_intrinsic_sizes()
	if disable_intrinsic_font_reuse {
		assert voidptr(retained) != voidptr(original)
	} else {
		assert voidptr(retained) == voidptr(original)
		assert retained.cached_content_height(true, 123)? == CSSPixels.new(42)
	}
	assert calculate_min_content_width(mut state, box) == minimum
	assert calculate_max_content_width(mut state, box) == maximum
	box.reset_cached_intrinsic_sizes()
	assert calculate_min_content_width(mut state, box) == minimum
	assert calculate_max_content_width(mut state, box) == maximum
}

fn test_intrinsic_sizes_expire_when_a_descendant_cascade_was_already_replaced() {
	mut document := html.parse_document('<!doctype html><div id="subject" style="font:16px monospace"><span style="font-family:serif">words</span></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 200) or { panic('layout failed') }
	prepare_intrinsic_epoch_fonts(result.root)
	node := intrinsic_epoch_layout_node(result.root, 'subject')?
	mut box := node.as_box()?
	original := box.cached_intrinsic_sizes()
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.clear_computed_font_cache('serif')
	prepare_intrinsic_epoch_fonts(result.root)
	assert !intrinsic_fonts_are_unchanged_since(node, original.font_generation_)
	assert voidptr(box.cached_intrinsic_sizes()) != voidptr(original)
}

fn test_intrinsic_sizes_expire_when_an_ancestor_font_supplies_changed_relative_metrics() {
	mut document := html.parse_document('<!doctype html><style>html{font:16px serif}#subject{font-family:monospace;width:10rlh}</style><div id="subject">words</div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 200) or { panic('layout failed') }
	prepare_intrinsic_epoch_fonts(result.root)
	node := intrinsic_epoch_layout_node(result.root, 'subject')?
	mut box := node.as_box()?
	original := box.cached_intrinsic_sizes()
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.clear_computed_font_cache('serif')
	prepare_intrinsic_epoch_fonts(result.root)
	assert !intrinsic_fonts_are_unchanged_since(node, original.font_generation_)
	assert voidptr(box.cached_intrinsic_sizes()) != voidptr(original)
}

fn test_intrinsic_sizes_reject_unknown_descendant_font_inputs() {
	mut document := html.parse_document('<!doctype html><div id="subject"><span id="child">words</span></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 200) or { panic('layout failed') }
	prepare_intrinsic_epoch_fonts(result.root)
	node := intrinsic_epoch_layout_node(result.root, 'subject')?
	child := intrinsic_epoch_layout_node(result.root, 'child')?
	mut box := node.as_box()?
	original := box.cached_intrinsic_sizes()
	mut computed := child.computed_values()
	computed.clear_computed_font_list_cache()
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedIntrinsicFamily')
	assert voidptr(box.cached_intrinsic_sizes()) != voidptr(original)
}

fn test_intrinsic_sizes_reject_containing_blocks_outside_the_parent_chain() {
	mut document := html.parse_document('<!doctype html><div id="outside">outside</div><div id="subject"><span id="child">words</span></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 200) or { panic('layout failed') }
	prepare_intrinsic_epoch_fonts(result.root)
	node := intrinsic_epoch_layout_node(result.root, 'subject')?
	child := intrinsic_epoch_layout_node(result.root, 'child')?
	outside := intrinsic_epoch_layout_node(result.root, 'outside')?
	mut box := node.as_box()?
	original := box.cached_intrinsic_sizes()
	mut hoisted := unsafe { &Node(child) }
	hoisted.containing_block_ = outside.as_box()?
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedIntrinsicFamily')
	assert !intrinsic_fonts_are_unchanged_since(node, original.font_generation_)
	assert voidptr(box.cached_intrinsic_sizes()) != voidptr(original)
}

fn test_intrinsic_sizes_with_unresolved_fonts_retain_original_geometry_until_selected_family_changes() {
	mut document := html.parse_document('<!doctype html><div id="subject" style="display:inline-grid;font:16px/20px PendingIntrinsicLayout,monospace"><div>several words</div></div>')
	defer { document.finalize() }
	mut computer := css.css_style_computer_for(document).font_computer()
	mut set := css.FontFaceSet.create_for_font_computer(computer)
	face := css.FontFaceObject.construct_impl('PendingIntrinsicLayout', css.FontFaceSource.from_string('url("pending.ttf")'), css.FontFaceDescriptors{ unicode_range: 'U+400-4FF' })
	set.add(face) or { panic(err) }
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	prepare_intrinsic_epoch_fonts(result.root)
	node := intrinsic_epoch_layout_node(result.root, 'subject')?
	assert node.computed_values().computed_font_list(computer).pending_faces.len == 1
	mut box := node.as_box()?
	mut state := result.state
	minimum := calculate_min_content_width(mut state, box)
	maximum := calculate_max_content_width(mut state, box)
	original := box.cached_intrinsic_sizes()
	computer.did_load_font('UnrelatedIntrinsicLayout')
	retained := box.cached_intrinsic_sizes()
	if disable_intrinsic_font_reuse || os.getenv('VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE') != '' {
		assert voidptr(retained) != voidptr(original)
	} else {
		assert voidptr(retained) == voidptr(original)
	}
	assert calculate_min_content_width(mut state, box) == minimum
	assert calculate_max_content_width(mut state, box) == maximum
	computer.clear_computed_font_cache('PendingIntrinsicLayout')
	assert voidptr(box.cached_intrinsic_sizes()) != voidptr(retained)
	box.reset_cached_intrinsic_sizes()
	assert calculate_min_content_width(mut state, box) == minimum
	assert calculate_max_content_width(mut state, box) == maximum
}
