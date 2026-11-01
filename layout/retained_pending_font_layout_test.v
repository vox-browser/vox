module layout

import css
import dom
import html

fn pending_layout_fixture(independent bool) (&dom.Document, &Node, &css.FontFaceObject) {
	style := if independent { 'overflow:hidden;width:180px' } else { 'width:180px' }
	mut document := html.parse_document('<!doctype html><style>html{font:16px/20px monospace}#stable{font-family:PendingLayoutOwner,monospace}</style><div id="changed"></div><section id="stable" style="${style}">Unchanged <span>nested text</span> wraps over several lines.</section>')
	mut computer := css.css_style_computer_for(document).font_computer()
	mut set := css.FontFaceSet.create_for_font_computer(computer)
	face := css.FontFaceObject.construct_impl('PendingLayoutOwner', css.FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')"), css.FontFaceDescriptors{ unicode_range: 'U+400-4FF' })
	set.add(face) or { panic(err) }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_font_node(document, 'stable')
	assert (root.computed_values().cached_computed_font_list() or { panic('missing font') }).pending_faces.len == 1
	return document, root, face
}

fn test_pending_inline_and_independent_layout_survive_an_unrelated_font_completion() {
	for independent in [false, true] {
		mut document, root, _ := pending_layout_fixture(independent)
		defer { document.finalize() }
		key := u64(voidptr(root))
		before := document_layout_result(document) or { panic('missing layout') }
		mut computer := css.css_style_computer_for(document).font_computer()
		computer.did_load_font('UnrelatedPendingLayout')
		retained_font_force_other_layout(mut document)
		after := document_layout_result(document) or { panic('missing current layout') }
		if independent {
			old := before.state.block_layouts_[key] or { panic('missing independent cache') }
			current := after.state.block_layouts_[key] or { panic('missing independent cache after completion') }
			assert voidptr(old) == voidptr(current)
		} else {
			old := before.state.inline_layouts_[key] or { panic('missing inline cache') }
			current := after.state.inline_layouts_[key] or { panic('missing inline cache after completion') }
			assert voidptr(old) == voidptr(current)
		}
		retained_font_assert_full_layout(mut document)
	}
}

fn test_selected_pending_face_completion_and_descriptor_changes_expire_retained_layout() {
	$if macos {
		for independent in [false, true] {
			for completion in [false, true] {
				mut document, root, mut face := pending_layout_fixture(independent)
				defer { document.finalize() }
				result := document_layout_result(document) or { panic('missing layout') }
				inputs := if independent {
					(result.state.block_layouts_[u64(voidptr(root))] or { panic('missing block') }).inputs
				} else {
					(result.state.inline_layouts_[u64(voidptr(root))] or { panic('missing inline') }).inputs
				}
				assert retained_layout_fonts_are_current(inputs)
				if completion {
					face.load()
					assert face.status() == .loaded
				} else {
					face.set_weight('700') or { panic(err) }
				}
				assert !retained_layout_fonts_are_current(inputs)
				retained_font_force_other_layout(mut document)
				retained_font_assert_full_layout(mut document)
			}
		}
	}
}
