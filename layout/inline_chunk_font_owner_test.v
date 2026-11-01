module layout

import html
import css
import dom
import os

fn test_retained_inline_text_replaces_glyph_fonts_after_a_live_font_size_change() {
	mut document :=
		html.parse_document('<!doctype html><div style="width:400px"><p>before <strong id="label">retained text</strong> after</p></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 300)
	mut label := document.get_element_by_id('label')?
	before := label.get_bounding_client_rect().width
	label.set_attribute_value('style', 'font-size:32px')
	document.update_layout(.debugging)
	assert label.get_bounding_client_rect().width > before * 1.8
	current := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == current
}

fn test_retained_inline_text_tracks_font_family_and_inherited_font_changes() {
	mut document :=
		html.parse_document('<!doctype html><div id="owner" style="width:300px;font:16px SerenitySans"><p id="text">A paragraph with <strong>nested bold text</strong> and trailing content.</p></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut owner := document.get_element_by_id('owner')?
	for style in ['width:300px;font:20px SerenityMono', 'width:120px;font:12px SerenitySans'] {
		owner.set_attribute_value('style', style)
		document.update_layout(.debugging)
		current := (document.record_display_list()?).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list()?).dump() == current
	}
}

fn test_retained_text_chunks_survive_font_generations_only_with_unchanged_faces_and_style() {
	mut document := html.parse_document('<!doctype html><p id="text" style="font-family:SerenitySans;font-size:16px;line-height:20px;width:180px">Unchanged words wrap over several lines.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut element := document.get_element_by_id('text')?
	root := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	text := root.first_child()?.as_text_node()?
	before := text.cached_inline_chunks_?
	assert before.len > 0
	mut computer := unsafe { &css.FontComputer(css.css_style_computer_for(document).font_computer()) }
	for family in ['UnrelatedFamily', 'SerenitySans'] {
		computer.did_load_font(family)
		refresh_inline_chunk_font_owner(text)
		after := text.cached_inline_chunks_?
		assert before.data == after.data
		assert text.cached_font_environment_generation_ == computer.environment_generation()
	}
	element.set_attribute_value('style', 'font-family:SerenitySans;font-size:28px;line-height:30px;width:180px')
	document.update_style()
	refresh_inline_chunk_font_owner(text)
	assert text.cached_inline_chunks_ == none
	document.update_layout(.debugging)
	actual := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == actual
}

fn pending_text_owner_fixture() (&dom.Document, &TextNode, &css.FontFaceObject) {
	mut document := html.parse_document('<!doctype html><p id="text" style="font:16px/20px PendingTextOwner,monospace;width:180px">Unchanged words wrap over several lines.</p>')
	mut computer := css.css_style_computer_for(document).font_computer()
	mut set := css.FontFaceSet.create_for_font_computer(computer)
	face := css.FontFaceObject.construct_impl('PendingTextOwner', css.FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')"), css.FontFaceDescriptors{ unicode_range: 'U+400-4FF' })
	set.add(face) or { panic(err) }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	element := document.get_element_by_id('text') or { panic('missing text') }
	root := unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
	text := root.first_child() or { panic('missing child') }.as_text_node() or { panic('missing text node') }
	assert text.cached_inline_font_owner_ or { panic('missing owner') }.pending_faces.len == 1
	return document, text, face
}

fn test_pending_text_chunks_and_shape_owners_survive_only_unrelated_font_changes() {
	document, text, _ := pending_text_owner_fixture()
	defer { document.finalize() }
	chunks := text.cached_inline_chunks_?
	iterator := &InlineLevelIterator{ layout_mode: .intrinsic_sizing }
	_ = iterator.shape_text_for_layout(text, 0, 0, 0, 'Unchanged words', text.font_for_rendering(), .ltr)
	shape := text.cached_intrinsic_text_shapes_.last().glyph_run
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedTextOwner')
	refresh_inline_chunk_font_owner(text)
	if disable_live_pending_text_reuse || os.getenv('VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE') != '' {
		assert text.cached_inline_chunks_ == none
		assert text.cached_intrinsic_text_shapes_.len == 0
	} else {
		assert text.cached_inline_chunks_?.data == chunks.data
		assert voidptr(text.cached_intrinsic_text_shapes_.last().glyph_run) == voidptr(shape)
		assert text.cached_font_environment_generation_ == computer.environment_generation()
	}
	computer.clear_computed_font_cache('PendingTextOwner')
	refresh_inline_chunk_font_owner(text)
	assert text.cached_inline_chunks_ == none
	assert text.cached_intrinsic_text_shapes_.len == 0
}

fn test_pending_text_chunks_expire_after_the_selected_face_loads_or_changes_descriptor() {
	for completion in [false, true] {
		mut document, text, mut face := pending_text_owner_fixture()
		defer { document.finalize() }
		previous := text.cached_inline_chunks_?
		if completion {
			$if macos {
				face.load()
				assert face.status() == .loaded
			} $else { continue }
		} else {
			face.set_unicode_range('U+0-10FFFF') or { panic(err) }
		}
		refresh_inline_chunk_font_owner(text)
		// FontFaceSet.ready may synchronously lay out and populate a new cache.
		if current := text.cached_inline_chunks_ { assert current.data != previous.data }
		document.update_layout(.debugging)
		actual := (document.record_display_list()?).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list()?).dump() == actual
	}
}
