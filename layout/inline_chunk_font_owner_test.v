module layout

import html

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
