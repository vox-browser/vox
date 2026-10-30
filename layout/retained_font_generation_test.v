module layout

import css
import dom
import html

fn retained_font_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn retained_font_force_other_layout(mut document dom.Document) {
	mut changed := document.get_element_by_id('changed') or { panic('missing changed') }
	changed.set_attribute_value('style', 'height:40px')
	document.update_layout(.debugging)
}

fn retained_font_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_settled_inline_and_independent_layout_survive_an_unchanged_font_generation() {
	for independent in [false, true] {
		style := if independent { 'overflow:hidden;width:180px' } else { 'width:180px' }
		mut document := html.parse_document('<!doctype html><style>html{font-family:SerenityMono;font-size:16px;line-height:20px}</style><div id="changed"></div><section id="stable" style="${style}">Unchanged <strong>nested text</strong> wraps into several lines.</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		root := retained_font_node(document, 'stable')
		key := u64(voidptr(root))
		old := document_layout_result(document) or { panic('missing old layout') }
		mut computer := unsafe { &css.FontComputer(css.css_style_computer_for(document).font_computer()) }
		generation := computer.environment_generation()
		computer.did_load_font('SerenityMono')
		assert computer.environment_generation() > generation
		retained_font_force_other_layout(mut document)
		current := document_layout_result(document) or { panic('missing current layout') }
		if independent {
			before := old.state.block_layouts_[key] or { panic('missing old independent cache') }
			after := current.state.block_layouts_[key] or { panic('missing independent cache') }
			assert voidptr(before) == voidptr(after)
			assert after.font_generation < computer.environment_generation()
		} else {
			before := old.state.inline_layouts_[key] or { panic('missing old inline cache') }
			after := current.state.inline_layouts_[key] or { panic('missing inline cache') }
			assert voidptr(before) == voidptr(after)
			assert after.font_generation < computer.environment_generation()
		}
		retained_font_assert_full_layout(mut document)
	}
}

fn test_newly_available_font_rejects_retained_fallback_geometry() {
	$if macos {
	mut document := html.parse_document('<!doctype html><style>#stable{font-family:LateFace,monospace;font-size:20px;line-height:normal;width:180px}</style><div id="changed"></div><p id="stable">Many words must wrap with the selected face.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_font_node(document, 'stable')
	key := u64(voidptr(root))
	before := document_layout_result(document) or { panic('missing old layout') }
	old := before.state.inline_layouts_[key] or { panic('missing old cache') }
	mut face := css.FontFaceObject.construct_impl('LateFace', css.FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')"), css.FontFaceDescriptors{})
	mut computer := css.css_style_computer_for(document)
	mut fonts := computer.font_face_set_
	generation := computer.font_computer().environment_generation()
	fonts.add(face) or { panic(err) }
	face.load()
	assert face.status() == .loaded
	assert computer.font_computer().environment_generation() > generation
	assert computer.font_computer().font_faces.len > 0
	assert !retained_layout_fonts_are_current(old.inputs)
	retained_font_force_other_layout(mut document)
	after := document_layout_result(document) or { panic('missing new layout') }
	current_root := retained_font_node(document, 'stable')
	current := after.state.inline_layouts_[u64(voidptr(current_root))] or { panic('missing new cache') }
	assert voidptr(current) != voidptr(old)
	retained_font_assert_full_layout(mut document)
	}
}

fn test_pending_font_and_root_metric_contexts_reject_the_font_cache_exception() {
	mut document := html.parse_document('<!doctype html><p id="stable" style="font-family:SerenityMono;font-size:16px;line-height:20px;width:180px">Stable text with several words.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_font_node(document, 'stable')
	result := document_layout_result(document) or { panic('missing layout') }
	cached := result.state.inline_layouts_[u64(voidptr(root))] or { panic('missing cache') }
	assert retained_layout_fonts_are_current(cached.inputs)
	first := cached.inputs[0]
	for root_height in [false, true] {
		changed := if root_height {
			RetainedInlineInput{...first, root_line_height:first.root_line_height + 1}
		} else {
			RetainedInlineInput{...first, root_font_size:first.root_font_size + 1}
		}
		assert !retained_layout_fonts_are_current([changed])
	}
	mut pending := css.FontCascadeList.create()
	pending.add_pending_face(&css.FontFaceObject{family_:'Pending'})
	assert !retained_layout_fonts_are_current([RetainedInlineInput{...first,font_list:pending}])
}
