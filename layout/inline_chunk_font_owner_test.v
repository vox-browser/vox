module layout

import html
import css

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
