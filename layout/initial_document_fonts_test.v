module layout

import css
import html

fn test_initial_font_preparation_selects_visible_text_faces_without_geometry() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><style>
		@font-face{font-family:Unused;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}
		@font-face{font-family:InitialFixture;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}
		@font-face{font-family:InitialBold;src:url(file:///System/Library/Fonts/Supplemental/Times%20New%20Roman.ttf)}
		html{font-family:Unused}p{font-family:InitialFixture}strong{font-family:InitialBold}
	</style><div style="display:none">Hidden text</div><p>Visible <strong>bold</strong> text.</p>')
	defer { document.finalize() }
	prepare_initial_document_fonts(document)
	assert document.layout_root == unsafe { nil }
	assert document.layout_engine_handle() == unsafe { nil }
	assert document.cached_display_list() == none
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	assert faces.len == 3
	assert faces[0].status() == .unloaded
	assert faces[1].status() == .loaded
	assert faces[2].status() == .loaded
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert document.layout_is_up_to_date()
}

fn test_initial_font_preparation_leaves_collapsed_whitespace_unused() {
	$if !macos { return }
	for preserved in [false, true] {
		white_space := if preserved { 'pre' } else { 'normal' }
		mut document := html.parse_document('<!doctype html><style>@font-face{font-family:InitialFixture;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}html{font-family:InitialFixture}p{white-space:${white_space}}</style><p> \n\t </p>')
		defer { document.finalize() }
		prepare_initial_document_fonts(document)
		faces := css.css_style_computer_for(document).font_face_set_.set_entries()
		assert faces.len == 1
		if preserved { assert faces[0].status() == .loaded }
		else { assert faces[0].status() == .unloaded }
		assert document.layout_root == unsafe { nil }
	}
}
